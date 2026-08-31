<?php

namespace App\Livewire\Site;

use App\Abonelik\PlanDeposu;
use App\Eposta\BayiPostacisi;
use App\Mail\Hosgeldiniz;
use App\Models\Tenant;
use App\Models\User;
use App\Payment\ConsentRequiredException;
use App\Payment\DuplicateEmailException;
use App\Payment\SubscriptionService;
use App\Support\DuplicateSlugException;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Locked;
use Livewire\Component;

/**
 * İŞLETME AÇMA — 3 adım + başarı ekranı (tasarım: 12-sw-giris.jsx · KayitSayfa).
 *   ① işletme adı + e-posta  ② ad soyad + parola  ③ firma kodu + özet + KVKK onayı
 *
 * KORUNAN GÜVENLİK DAVRANIŞLARI (SubscriptionService::register):
 *  - KVKK onayı ZORUNLU (ConsentRequiredException).
 *  - E-posta GLOBAL tekil ve çakışmada NÖTR mesaj (DuplicateEmailException: "Bu e-posta ile devam
 *    edilemiyor."). Mesaj "bu e-posta kayıtlı" diye AÇILMAZ — kullanıcı numaralandırması olurdu.
 *  - Tenant + patron yaratma owner bağlantısıyla (Provisioning), RLS-üstü meşru provizyon.
 *
 * FİRMA KODU: tasarım adı `slugla()` ile öneriye çevirir, kullanıcı düzenleyebilir. Benzersizlik
 * SUNUCUDA doğrulanır (`tenants.slug` global tekil) ve çakışma anlaşılır biçimde söylenir — bu
 * bir kimlik değil bir ADREStir, numaralandırma kaygısı yoktur; aksine "bu kod alınmış" demek
 * kullanıcının tek ihtiyacı olan bilgidir. Doğrulamadaki kontrol yarışa karşı yetmez; kaybeden
 * taraf `DuplicateSlugException` ile AYNI cümleyi görür.
 *
 * Firma kodu, yetkilinin adı ve telefon `register()` imzasındadır — hepsi TEK transaction'da
 * yazılır. Bir vardiya boyunca bunlar kayıt SONRASI ayrı UPDATE'lerle düzeltiliyordu; araya düşen
 * bir hata yarım bir bayi bırakabiliyordu.
 */
#[Layout('components.layouts.site-ciplak', ['baslik' => 'İşletmenizi açın · Sipario'])]
class Register extends Component
{
    /** Adım göstergesi; 3 = başarı ekranı. Sunucu tarafında tutulur, istemci atlayamaz. */
    #[Locked]
    public int $adim = 0;

    /** Başarı ekranında gösterilen GERÇEK firma kodu (DB'de oluşan slug). */
    #[Locked]
    public string $olusanKod = '';

    /**
     * Başarı ekranında gösterilen GERÇEK kullanıcı adı (DB'de oluşan `users.username`).
     *
     * NEDEN EKRANDA (2026-08-31): mobil giriş FİRMA KODU + KULLANICI ADI + parola ister; bu ekran
     * bugüne kadar üçünden yalnız birini gösteriyordu. Kullanıcı adı sabit 'patron' olduğu sürece
     * eksiklik gizliydi — artık girilen bilgilerden türetiliyor, dolayısıyla bayinin onu ilk kez
     * BURADA görmesi zorunlu. `#[Locked]`: istemci başarı ekranındaki adı değiştiremesin, ekran
     * DB'de ne yazdığını söylesin.
     */
    #[Locked]
    public string $olusanKullanici = '';

    public string $isletme = '';

    public string $eposta = '';

    public string $ad = '';

    public string $parola = '';

    public string $kod = '';

    public bool $kvkk = false;

    /** Adım → o adımda doğrulanacak alanlar (tasarımın `adimAlan` dizisi). */
    private const ADIM_ALAN = [
        0 => ['isletme', 'eposta'],
        1 => ['ad', 'parola'],
        2 => ['kod'],
    ];

    public function ileri(): void
    {
        $this->validate(
            array_intersect_key($this->kurallar(), array_flip(self::ADIM_ALAN[$this->adim] ?? [])),
            $this->mesajlar(),
        );

        if ($this->adim === 0) {
            // Kod boşsa işletme adından öneri üret (tasarımın `slugla()`si).
            if (trim($this->kod) === '') {
                $this->kod = self::slugla($this->isletme);
            }
            $this->adim = 1;

            return;
        }

        if ($this->adim === 1) {
            $this->adim = 2;

            return;
        }

        $this->isletmeyiAc();
    }

    public function geri(): void
    {
        if ($this->adim > 0 && $this->adim < 3) {
            $this->adim--;
        }
    }

    /** Firma kodu alanı her yazımda tasarımdaki gibi süzülür: yalnız küçük harf + rakam. */
    public function updatedKod(string $deger): void
    {
        $this->kod = mb_substr((string) preg_replace('/[^a-z0-9]/', '', mb_strtolower($deger)), 0, 18);
    }

    #[Computed]
    public function denemeGun(): int
    {
        return (new PlanDeposu('pgsql_owner'))->denemeGun();
    }

    public function render(): mixed
    {
        return view('livewire.site.register');
    }

    /**
     * Türkçe adı firma koduna çevirir — tasarımın `slugla()` işlevinin birebir karşılığı
     * (tire YOK, yalnız [a-z0-9], en çok 18 karakter).
     */
    public static function slugla(string $ad): string
    {
        $tr = ['ç' => 'c', 'ğ' => 'g', 'ı' => 'i', 'İ' => 'i', 'ö' => 'o', 'ş' => 's', 'ü' => 'u',
            'Ç' => 'c', 'Ğ' => 'g', 'Ö' => 'o', 'Ş' => 's', 'Ü' => 'u'];

        return mb_substr(
            (string) preg_replace('/[^a-z0-9]/', '', mb_strtolower(strtr(trim($ad), $tr), 'UTF-8')),
            0, 18
        );
    }

    private function isletmeyiAc(): void
    {
        // SON ADIMDA TÜM ALANLAR yeniden doğrulanır. `ileri()` yalnız bulunulan adımı doğrular;
        // bu son kontrol olmasaydı akışı adım adım yürütmeyen bir istemci (ya da yarın eklenecek
        // bir kısayol) boş işletme adıyla kayıt açabilirdi. Adım göstergesi bir ARAYÜZ durumudur,
        // güvenlik sınırı değildir.
        $this->validate($this->kurallar(), $this->mesajlar());

        // KVKK kapısı SERVİSTE de var; burada erken kontrol yalnız hatayı doğru alanın altına
        // yazmak için. Servisten geçmeden hiçbir kayıt oluşmaz.
        if (! $this->kvkk) {
            $this->addError('kvkk', 'Devam etmek için sözleşmeleri onaylayın');

            return;
        }

        /*
         * TEK ÇAĞRI, TEK TRANSACTION. Firma kodu, yetkilinin adı ve telefon artık `register()`
         * imzasında; eskiden kayıt SONRASI ayrı UPDATE'lerle düzeltiliyorlardı ve araya düşen bir
         * hata yarım bir bayi bırakabiliyordu. Kod çakışması da artık sessizce yutulup üretilen
         * koda düşmüyor — `DuplicateSlugException` ile AÇIKÇA söyleniyor (firma kodu tasarım
         * gereği zaten herkese açık bir kimliktir, gizlenecek bir şey yok).
         */
        try {
            $sonuc = app(SubscriptionService::class)->register(
                name: $this->isletme,
                email: $this->eposta,
                password: $this->parola,
                phone: null,
                kvkkConsent: $this->kvkk,
                slug: $this->kod,
                patronAdi: trim($this->ad) !== '' ? Str::limit(trim($this->ad), 120, '') : null,
            );
        } catch (ConsentRequiredException $e) {
            $this->addError('kvkk', $e->getMessage());

            return;
        } catch (DuplicateEmailException $e) {
            // NÖTR: "bu e-posta kayıtlı" DEĞİL. Kullanıcı adım 1'e döner ve adresi düzeltir.
            $this->adim = 0;
            $this->addError('eposta', $e->getMessage());

            return;
        } catch (DuplicateSlugException $e) {
            // Doğrulamadaki "alınmış mı" kontrolü ile INSERT arasındaki YARIŞIN kaybeden tarafı.
            $this->addError('kod', $e->getMessage());

            return;
        }

        /** @var Tenant $tenant */
        $tenant = $sonuc['tenant'];
        /** @var User $patron */
        $patron = $sonuc['patron'];

        // Ekranda GERÇEK kod gösterilir (DB'de oluşan slug) — bayiye vermediğimiz bir kodu
        // göstermek en kötü yalan olurdu.
        $this->olusanKod = $tenant->slug;
        $this->olusanKullanici = (string) $patron->username;

        /*
         * HOŞ GELDİNİZ POSTASI (2026-08-12). Bu akış bugüne kadar HİÇ posta göndermiyordu ve
         * bıraktığı boşluk doğrudan BRIEF'in üçüncü korkusuna değiyordu ("kurulum→ilk tanıma
         * 10 dakikanın altında kalmalı"): mobil giriş FİRMA KODU + KULLANICI ADI ister, e-posta
         * kabul etmez. Bayi bu başarı ekranını kapattığı an kodu başka hiçbir yerden öğrenemezdi.
         *
         * Kayıt akışını DÜŞÜRMEZ: `postala()` istisnayı yutup raporlar. Bir SMTP arızası
         * yüzünden yeni açılmış bir bayiyi geri almak, çözdüğünden çok sorun yaratırdı — hesap
         * zaten transaction içinde yazıldı ve ekranda kod görünüyor.
         */
        BayiPostacisi::postala($patron->email, $patron->name, new Hosgeldiniz(
            isletme: $tenant->name,
            yetkili: $patron->name,
            firmaKodu: $tenant->slug,
            kullaniciAdi: $patron->username,
            denemeBitisi: $tenant->trial_ends_at?->translatedFormat('j F Y') ?? '',
            denemeGun: $this->denemeGun(),
            hesapUrl: route('site.hesap'),
        ));

        session()->regenerate();
        Auth::guard('web')->login($patron);
        session([
            'subscription_tenant_id' => $tenant->id,
            'subscription_email' => $patron->email,
        ]);

        $this->adim = 3;

        /*
         * ── DÖNÜŞÜM ÖLÇÜMÜ (2026-08-19) ────────────────────────────────────────────────
         * `sign_up`, GA4'ün ÖNERİLEN olay adlarından biridir ve raporlarda özel yer alır;
         * bu yüzden Türkçeleştirilmedi (config/analitik.php'de gerekçesi yazılı).
         *
         * NEDEN SUNUCUDAN YAYILIYOR: kayıt üç adımlı bir Livewire sihirbazı; tarayıcı
         * tarafında "kayıt gerçekten tamamlandı" anını yakalayabilecek bir tıklama YOK
         * (son adımdaki düğme tıklandığında doğrulama hâlâ düşebilir). Olayı buradan
         * yaymak, yalnız tenant GERÇEKTEN yaratıldıysa sayılmasını garanti eder.
         *
         * KİŞİSEL VERİ TAŞINMAZ: e-posta, işletme adı ve firma kodu YOK — yalnız deneme
         * gün sayısı. Ölçüm aracına kişisel veri göndermek hem KVKK aydınlatma metnimizle
         * (m.3 tablosu: "adınız, e-postanız ölçüm sistemine gönderilmez") hem Google'ın
         * kendi şartlarıyla çelişirdi.
         *
         * Rıza yoksa tarayıcı tarafındaki `siparioOlay()` bunu sessizce düşürür — sunucu
         * rızayı bilmek zorunda değil, kapı tek yerde (public/js/olcum.js).
         */
        $this->dispatch('sipario-olcum', ad: 'sign_up', veri: [
            'yontem' => 'web',
            'deneme_gun' => $this->denemeGun(),
        ]);
    }

    /**
     * @return array<string, list<string>>
     */
    private function kurallar(): array
    {
        return [
            'isletme' => ['required', 'string', 'min:3', 'max:255'],
            'eposta' => ['required', 'email', 'max:190'],
            'ad' => ['required', 'string', 'max:120'],
            'parola' => ['required', 'string', 'min:8'],
            // Benzersizlik SUNUCUDA: owner bağlantısı, çünkü `tenants` RLS altındadır ve web
            // isteğinde kiracı bağlamı yoktur — varsayılan bağlantı sıfır satır görüp her kodu
            // "boşta" sanardı.
            'kod' => ['required', 'string', 'regex:/^[a-z0-9]{3,18}$/', 'unique:pgsql_owner.tenants,slug'],
        ];
    }

    /**
     * Tasarımın doğrulama metinleri — birebir.
     *
     * @return array<string, string>
     */
    private function mesajlar(): array
    {
        return [
            'isletme.required' => 'İşletme adını girin',
            'isletme.min' => 'En az 3 karakter',
            'eposta.required' => 'E-posta adresinizi girin',
            'eposta.email' => 'Geçerli bir e-posta girin',
            'ad.required' => 'Adınızı ve soyadınızı girin',
            'parola.required' => 'Bir parola belirleyin',
            'parola.min' => 'Parola en az 8 karakter olmalı',
            'kod.required' => 'Firma kodu boş olamaz',
            'kod.regex' => 'Sadece küçük harf ve rakam, en az 3 karakter',
            'kod.unique' => 'Bu firma kodu alınmış, başka bir kod deneyin',
        ];
    }
}
