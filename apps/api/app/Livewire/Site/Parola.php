<?php

namespace App\Livewire\Site;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Locked;
use Livewire\Component;
use Throwable;

/**
 * PAROLA SIFIRLAMA — bağlantı isteme (tasarım: 12-sw-giris.jsx · SifreSayfa, iki aşama).
 *
 * KULLANICI NUMARALANDIRMASI: e-posta kayıtlı olsa da olmasa da AYNI ekran gösterilir. Bu ekranın
 * tek işi "gönderdik" demektir; "böyle bir hesap yok" demek, geçerli e-postaları tek tek doğrulayan
 * bir uca dönüşürdü. Posta gönderimi patlarsa bile ekran değişmez (hata `report()` ile günlüğe
 * düşer) — aksi hâlde hata mesajının VARLIĞI hesabın varlığını sızdırırdı.
 *
 * LARAVEL'İN KENDİ ALTYAPISI KULLANILIR, kendi token şeması UYDURULMAZ: token
 * `Password::getRepository()` (DatabaseTokenRepository) ile üretilir — hash'lenerek saklanır, süresi
 * `config('auth.passwords.users.expire')` ile denetlenir, tek kullanımlıktır.
 *
 * NEDEN `Password::broker()->sendResetLink()` DEĞİL: broker kullanıcıyı `users` provider'ından, yani
 * RLS'li varsayılan bağlantıdan okur. Web isteğinde `app.tenant_id` kurulmadığı için o sorgu HİÇBİR
 * kullanıcıyı bulamaz ve akış sessizce hiçbir şey yapmaz. Kullanıcı bu yüzden owner bağlantısıyla
 * okunur; token üretimi ve bildirim yine framework'ündür.
 *
 * YALNIZ PATRON: web yüzeyi patronundur. Kurye/operatör hesaplarının e-postası zaten sentetiktir
 * (`kullanici@firmakodu.sipario.local`) ve o hesaplar mobilden firma koduyla girer.
 */
#[Layout('components.layouts.site-ciplak', ['baslik' => 'Parola sıfırlama · Sipario'])]
class Parola extends Component
{
    /** Aynı e-posta + IP için dakikadaki azami istek (posta bombardımanı kapısı). */
    private const KIMLIK_TAVANI = 3;

    /** Tek IP'nin dakikadaki azami isteği. */
    private const IP_TAVANI = 15;

    #[Locked]
    public int $asama = 0;

    /** Aşama 1'de ekrana yazılan adres (gönderildiği iddia edilen değil, kullanıcının yazdığı). */
    #[Locked]
    public string $gonderilen = '';

    public string $eposta = '';

    public function gonder(): void
    {
        $this->eposta = Str::lower(trim($this->eposta));

        $this->validate(
            ['eposta' => ['required', 'email']],
            ['eposta.required' => 'Geçerli bir e-posta girin', 'eposta.email' => 'Geçerli bir e-posta girin'],
        );

        // Hız sınırı AŞILDIĞINDA da nötr kalınır: kullanıcıya "biraz bekleyin" demek hesabın
        // varlığını sızdırmaz, ama sınırı sessizce yutup "gönderdik" demek de yalan olurdu.
        foreach ($this->limitler() as [$anahtar, $tavan]) {
            if (RateLimiter::tooManyAttempts($anahtar, $tavan)) {
                $this->addError('eposta', 'Çok fazla istek. '
                    .RateLimiter::availableIn($anahtar).' saniye sonra tekrar deneyin.');

                return;
            }
        }
        foreach ($this->limitler() as [$anahtar]) {
            RateLimiter::hit($anahtar);
        }

        $this->baglantiGonder($this->eposta);

        $this->gonderilen = $this->eposta;
        $this->asama = 1;
    }

    public function adresiDegistir(): void
    {
        $this->asama = 0;
    }

    /** Bağlantının gerçek geçerlilik süresi (dakika) — ekran metni config ile uyuşmak zorunda. */
    public function gecerlilikDakika(): int
    {
        return (int) config('auth.passwords.'.config('auth.defaults.passwords').'.expire', 60);
    }

    public function render(): mixed
    {
        return view('livewire.site.parola');
    }

    /**
     * Hesap varsa bağlantıyı gönderir; yoksa HİÇBİR ŞEY yapmaz ve bunu çağırana da söylemez.
     */
    private function baglantiGonder(string $eposta): void
    {
        try {
            /** @var User|null $patron */
            $patron = User::on('pgsql_owner')
                ->where('email', $eposta)
                ->where('role', UserRole::Patron->value)
                ->where('status', 'active')
                ->first();

            if ($patron === null) {
                return;
            }

            $depo = Password::getRepository();

            // Framework'ün kendi 60 saniyelik throttle'ı: aynı token'ı ard arda üretmez.
            if ($depo->recentlyCreatedToken($patron)) {
                return;
            }

            // Bağlantı ADRESİ: Laravel'in varsayılanı `route('password.reset')`tir, bizde o ad yok
            // (`site.parola.yenile` → /parola/yenile/{token}). E-posta parametresi ŞART: token tek
            // başına hangi hesaba ait olduğunu söylemez, `ParolaYenile` kullanıcıyı adresten bulur.
            ResetPassword::createUrlUsing(fn (User $kullanici, string $token): string => route(
                'site.parola.yenile',
                ['token' => $token, 'email' => $kullanici->getEmailForPasswordReset()],
            ));

            $patron->sendPasswordResetNotification($depo->create($patron));
        } catch (Throwable $e) {
            // Posta/altyapı hatası EKRANA YANSIMAZ (numaralandırma), ama sessizce de kaybolmaz.
            report($e);
        }
    }

    /**
     * @return list<array{0: string, 1: int}>
     */
    private function limitler(): array
    {
        $ip = (string) request()->ip();

        return [
            ['site-parola:kimlik:'.sha1($this->eposta.'|'.$ip), self::KIMLIK_TAVANI],
            ['site-parola:ip:'.sha1($ip), self::IP_TAVANI],
        ];
    }
}
