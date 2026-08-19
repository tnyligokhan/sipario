<?php

namespace App\Livewire\Site;

use App\Abonelik\PlanDeposu;
use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * sipario.com.tr GİRİŞ (tasarım: 12-sw-giris.jsx · GirisSayfa). Bayinin PATRONU abonelik, fatura ve
 * işletme bilgilerini yönetmek için buradan girer.
 *
 * KİMİN İÇİN: yalnız `patron`. Kurye ve tezgâh (operator) hesapları web'e HİÇ girmez — onlar mobil
 * uygulamadan firma koduyla girer (ekranın alt yazısı bunu birebir söyler). Rol kontrolü NÖTR hata
 * verir: "bu hesap patron değil" demek, geçerli bir e-postayı doğrulamak olurdu.
 *
 * SÜRESİ DOLMUŞ BAYİ GİREBİLİR (API login'den bilinçli FARK): bu bir FATURALAMA sitesidir ve süresi
 * dolan bayi tam da ÖDEME YAPMAK için giriş yapar. Yalnız kullanıcının kendisi `active` olmalı.
 *
 * KABA KUVVET SINIRI BİLEŞENİN İÇİNDE, ROUTE'TA DEĞİL (5c-3 dersi): Livewire eylemi `giris`e değil
 * `/livewire/update`e gider ve `ThrottleRequests` Livewire'ın kalıcı middleware listesinde yoktur —
 * route'a `throttle:` yazmak yalnız sayfanın ilk GET'ini korurdu.
 *
 * Doğrulama deseni API login ile aynı: `sipario_login_lookup` (SECURITY DEFINER, RLS-üstü
 * deterministik tek satır) + `Hash::check` HER ZAMAN (satır yoksa sabit dummy hash'e karşı) →
 * yanıt süresi e-postanın varlığını sızdırmaz.
 */
#[Layout('components.layouts.site-ciplak', ['baslik' => 'Giriş · Sipario'])]
class Login extends Component
{
    /**
     * Zamanlama yan-kanalı önlemi: e-posta bulunamadığında da bu SABİT bcrypt hash'ine karşı check
     * koşulur (AuthController ile aynı değer; cost=12 üretim BCRYPT_ROUNDS ile eşleşir).
     */
    private const DUMMY_PASSWORD_HASH = '$2y$12$SIPdK92BiNANCVLYxTNjPOWYDzM9szOpCdGt9bIA3l82vGXOBI0rS';

    /** Aynı e-posta + IP için dakikadaki azami başarısız deneme. */
    private const KIMLIK_TAVANI = 5;

    /** Tek IP'nin dakikadaki azami başarısız denemesi (hesap numaralandırma). */
    private const IP_TAVANI = 20;

    public string $email = '';

    public string $password = '';

    public function authenticate(): mixed
    {
        // E-POSTA HER ŞEYDEN ÖNCE NORMALİZE EDİLİR. 2026-08-04'te panelde tam bu yüzden arıza
        // vardı: tarayıcının büyüttüğü ilk harf ("Mehmet@…") DOĞRU PAROLAYLA "hatalı" veriyordu.
        // Postgres'te `=` harf duyarlıdır ve `sipario_login_lookup` içeride `lower(p_email)` ile
        // karşılaştırsa da `email` doğrulama kuralı baştaki/sondaki boşluğu reddeder — yani
        // kopyala-yapıştırla kaçan tek boşluk kullanıcıyı sorguya bile ulaştırmazdı. Ekran
        // (numaralandırmayı önlemek için) bilerek nötr konuştuğundan bu hata teşhis edilemezdi.
        // Alana geri yazılır ki doğrulama, hız sınırı anahtarı ve sorgu AYNI değeri görsün.
        $this->email = Str::lower(trim($this->email));

        $this->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ], [
            'email.required' => 'E-posta adresinizi girin',
            'email.email' => 'Geçerli bir e-posta girin',
            'password.required' => 'Parolanızı girin',
        ]);

        foreach ($this->limitler() as [$anahtar, $tavan]) {
            if (RateLimiter::tooManyAttempts($anahtar, $tavan)) {
                $this->addError('email', 'Çok fazla başarısız deneme. '
                    .RateLimiter::availableIn($anahtar).' saniye sonra tekrar deneyin.');

                return null;
            }
        }

        $row = DB::selectOne('SELECT * FROM sipario_login_lookup(?)', [$this->email]);

        // Hash::check HER ZAMAN koşar. Kısa-devre YOK: önce doğrula, sonra karar ver.
        $parolaGecerli = Hash::check($this->password, $row->password ?? self::DUMMY_PASSWORD_HASH);

        // Tek NÖTR hata: e-posta yok / parola yanlış / hesap pasif / rol patron değil — dördü de
        // aynı cümleyi verir. Ayrıştırmak, geçerli e-postaları ve patron hesaplarını numaralandırırdı.
        if ($row === null || ! $parolaGecerli || $row->status !== 'active'
            || $row->role !== UserRole::Patron->value) {
            foreach ($this->limitler() as [$anahtar]) {
                RateLimiter::hit($anahtar); // yalnız BAŞARISIZ denemeler sayılır
            }

            $this->addError('email', 'E-posta veya parola hatalı.');

            return null;
        }

        foreach ($this->limitler() as [$anahtar]) {
            RateLimiter::clear($anahtar);
        }

        /*
         * Kullanıcı OWNER bağlantısıyla okunur: web isteklerinde `app.tenant_id` kurulmadığı için
         * RLS'li varsayılan bağlantı `users`ta sıfır satır görür (politika NULLIF(...)::uuid).
         * Bu, oturum kurulumunun sessizce başarısız olacağı yerdir.
         */
        $patron = User::on('pgsql_owner')->findOrFail($row->id);

        session()->regenerate();
        Auth::guard('web')->login($patron);

        /*
         * Oturuma bayi bağlamı da konur. İki sebep:
         *  1. `Subscribe` (ödeme akışı) Faz 5b'den beri bu anahtarı okuyor — kırmadan taşıyoruz.
         *  2. `auth:web`in kullanıcıyı RLS altında yükleyebilmesi için `app.tenant_id`in istekten
         *     ÖNCE kurulması gerekir ve bunu yapacak middleware'in okuyabileceği tek yer oturumdur
         *     (bkz. rapor: ResolveTenantContext'e web oturumu düşüşü eklenmeli).
         */
        session([
            'subscription_tenant_id' => $row->tenant_id,
            'subscription_email' => $row->email,
        ]);

        $patron->forceFill(['last_login_at' => now()])->save();

        /*
         * ── DÖNÜŞÜM ÖLÇÜMÜ (2026-08-19) ────────────────────────────────────────────────
         * Livewire'ın `dispatch`i BURADA KULLANILAMAZ: metot bir yönlendirmeyle bitiyor ve
         * yönlendirme, bu istekte yayılan tarayıcı olaylarını beraberinde götürür — olay
         * hiçbir zaman ateşlenmezdi ve bunu fark etmek zor olurdu (sessizce eksik veri).
         *
         * Bunun yerine tek kullanımlık bir oturum bayrağı bırakılıyor; hedef sayfa (hesap
         * paneli) onu görüp bir işaret basıyor, `public/js/olcum.js` işareti görüp olayı
         * ateşliyor. `flash` olduğu için bir sonraki istekte kendiliğinden siliniyor —
         * yani her sayfa yenilemesinde tekrar sayılmıyor.
         */
        session()->flash('olcum_giris', true);

        return redirect()->route('site.hesap');
    }

    /**
     * "14 gün ücretsiz" TASARIMDA SABİTTİ; gerçek süre plandan gelir (OKU-BENI kararı: 30 gün).
     * Sabit yazmak, panelden deneme süresi değiştiğinde sitenin sunucuyla yalan söylemesi demekti.
     */
    #[Computed]
    public function denemeGun(): int
    {
        return (new PlanDeposu('pgsql_owner'))->denemeGun();
    }

    public function render(): mixed
    {
        return view('livewire.site.login');
    }

    /**
     * Hız sınırı anahtarları ve tavanları: [anahtar, tavan]. Anahtarlar sha1'lenir — e-posta
     * doğrudan önbellek anahtarına girerse uzun/garip girdi anahtarı bozabilirdi.
     *
     * @return list<array{0: string, 1: int}>
     */
    private function limitler(): array
    {
        $ip = (string) request()->ip();

        return [
            ['site-giris:kimlik:'.sha1(Str::lower(trim($this->email)).'|'.$ip), self::KIMLIK_TAVANI],
            ['site-giris:ip:'.sha1($ip), self::IP_TAVANI],
        ];
    }
}
