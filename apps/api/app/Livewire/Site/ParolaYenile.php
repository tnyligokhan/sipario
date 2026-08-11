<?php

namespace App\Livewire\Site;

use App\Enums\UserRole;
use App\Eposta\BayiPostacisi;
use App\Mail\ParolaDegisti;
use App\Models\User;
use Illuminate\Contracts\View\View;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Locked;
use Livewire\Component;

/**
 * PAROLA YENİLEME — e-postadaki token'lı bağlantının açtığı ekran.
 *
 * TASARIMDA BU EKRAN YOK (12-sw-giris.jsx yalnız "bağlantıyı gönderdik"e kadar gidiyor) ama akış
 * onsuz tamamlanmaz: gönderilen bağlantının açacağı bir yer olmalı. Kimlik kabuğunun diliyle
 * yazıldı; yeni metin uydurulmadı, komşu ekranların söz dizimi kullanıldı.
 *
 * Token doğrulaması Laravel'in kendi deposundadır (`Password::getRepository()`): hash karşılaştırma,
 * süre denetimi ve tek kullanımlık silme oradan gelir — kendi şemamız YOK.
 *
 * NÖTRLÜK: geçersiz/süresi dolmuş token ile "böyle bir hesap yok" AYNI cümleyi verir. Kullanıcı
 * bağlantıyı zaten e-postasından açtı; ayrıştırmak yalnız saldırgana bilgi verirdi.
 */
#[Layout('components.layouts.site-ciplak', ['baslik' => 'Yeni parola · Sipario'])]
class ParolaYenile extends Component
{
    /** Bağlantıdan gelen token — istemci DEĞİŞTİREMEZ. */
    #[Locked]
    public string $token = '';

    /** Bağlantıdaki adres — istemci DEĞİŞTİREMEZ (yoksa başka hesabın parolası yenilenirdi). */
    #[Locked]
    public string $eposta = '';

    #[Locked]
    public bool $bitti = false;

    public string $parola = '';

    public string $parolaTekrar = '';

    public function mount(string $token = '', ?string $email = null): void
    {
        $this->token = $token !== '' ? $token : (string) request()->route('token');
        $this->eposta = Str::lower(trim($email ?? (string) request()->query('email', '')));
    }

    public function kaydet(): void
    {
        $this->validate([
            'parola' => ['required', 'string', 'min:8', 'same:parolaTekrar'],
        ], [
            'parola.required' => 'Bir parola belirleyin',
            'parola.min' => 'Parola en az 8 karakter olmalı',
            'parola.same' => 'İki parola aynı değil',
        ]);

        /*
         * Kullanıcı OWNER bağlantısıyla okunur: web isteğinde `app.tenant_id` kurulmadığı için
         * RLS'li varsayılan bağlantı `users`ta sıfır satır görür ve her token "geçersiz" sanılırdı.
         * Yalnız PATRON: web yüzeyi patronundur (kurye/operatör mobilden firma koduyla girer).
         */
        /** @var User|null $patron */
        $patron = User::on('pgsql_owner')
            ->where('email', $this->eposta)
            ->where('role', UserRole::Patron->value)
            ->where('status', 'active')
            ->first();

        $depo = Password::getRepository();

        if ($patron === null || ! $depo->exists($patron, $this->token)) {
            $this->addError('parola', 'Bağlantı geçersiz ya da süresi dolmuş. Yeniden bağlantı isteyin.');

            return;
        }

        // 'hashed' cast'i bcrypt'ler.
        $patron->forceFill(['password' => $this->parola])->save();

        // Token TEK KULLANIMLIK: aynı bağlantı ikinci kez çalışmaz.
        $depo->delete($patron);

        /*
         * GÜVENLİK TEYİDİ (2026-08-12). Bu akış bugüne kadar SESSİZDİ ve sessizliği bir saldırı
         * penceresi bırakıyordu: bayinin posta kutusuna erişen biri sıfırlama bağlantısını
         * kullanır, parolayı değiştirir ve hesabın gerçek sahibi bunu ancak giremediği gün fark
         * ederdi. Bu posta o pencereyi kapatan tek uyarıdır.
         *
         * Postanın İÇİNDE tıklanacak bağlantı YOKTUR — "siz değilseniz tıklayın" kalıbı kimlik
         * avının birebir taklit ettiği kalıptır; bayiyi ona alıştırmak yarın sahtesini tıklamasını
         * kolaylaştırır. Tek çağrı, zaten güvendiği kanaldan yanıt vermesi.
         */
        BayiPostacisi::postala($patron->email, $patron->name, new ParolaDegisti(
            yetkili: (string) $patron->name,
            zaman: now()->translatedFormat('j F Y, H:i'),
        ));

        $this->reset('parola', 'parolaTekrar');
        $this->bitti = true;
    }

    public function render(): View
    {
        return view('livewire.site.parola-yenile');
    }
}
