<?php

namespace App\Livewire\Panel\Forms;

use App\Livewire\Site\Register;
use Livewire\Attributes\Validate;
use Livewire\Form;

/**
 * "Yeni Üye" modalı — panelden ELLE bayi açma (BRIEF md. 3: "gerektiğinde elle açma — siteden
 * kaydolmayan, birebir satışla kazanılan bayiler için").
 *
 * Alanlar siteden kayıt akışının (`App\Livewire\Site\Register`) AYNISIDIR ve bilinçli olarak
 * öyledir: iki yol da sonunda `Provisioning::createTenantWithPatron`a varır, dolayısıyla iki
 * yoldan açılan bayi arasında hiçbir fark olmamalıdır. Farklı alan kümesi, "siteden gelen bayi"
 * ile "elle açılan bayi" diye iki sınıf yaratırdı ve panelin ikinci sınıfı sonradan
 * tamamlaması gerekirdi.
 *
 * ⚠️ KULLANICI ADI BURADA YOK ÇÜNKÜ TÜRETİLİR — 2026-08-31'e kadar sabit 'patron'du, artık
 * yetkilinin adından üretiliyor ("Hasan Aslan" → `hasan.aslan`; `KullaniciAdiUretici`). Operatör
 * ayrıca yazmaz: form zaten yetkilinin adını topluyor ve aynı bilgiyi ikinci kez sormak,
 * ekrandaki adla giriş adının ayrışmasına açık kapı bırakırdı.
 *
 * Üretilen ad kayıttan sonra KURULUM BANDINDA gösterilir (`TenantList::$acilan`) ve hoş geldiniz
 * postasında yazılıdır; ayrıca üye detayının "Firma Bilgileri" kartında kalıcı olarak durur —
 * operatör "kullanıcı adım neydi" diye arayan bayiye her zaman cevap verebilmeli.
 *
 * Parola OPERATÖRDEN alınır, üretilmez: bu hesap telefonda birebir devredilir; ekranda bir kez
 * gösterilen rastgele parolayı operatörün karşı tarafa doğru okuması, kendi yazdığı parolayı
 * söylemesinden zordur. (Sonradan sıfırlama zaten üye detayında var ve o parola ÜRETİLİR —
 * orada karşı tarafta operatör olmayabilir.)
 */
class UyeForm extends Form
{
    /** `tenants.name` varchar(255). */
    #[Validate('required|string|min:3|max:255', as: 'işletme adı', message: 'İşletme adı en az 3 karakter olmalıdır.')]
    public string $isletme = '';

    /**
     * Firma kodu = `tenants.slug`. Biçim kuralı DB CHECK'inin aynısıdır
     * (`tenants_slug_check`: `^[a-z0-9-]{3,80}$`) — formda durmayan bir kod Postgres'te
     * `23514` olur ve operatör anlamsız bir 500 görür.
     *
     * `unique` ÖN KONTROLDÜR, emniyet değil: iki operatör aynı anda aynı kodu yazabilir.
     * Yarışın kaybeden tarafı `Provisioning`ten `DuplicateSlugException` ile döner ve
     * ekranda AYNI cümleyi görür.
     */
    #[Validate('required|string|regex:/^[a-z0-9-]{3,80}$/|unique:pgsql_owner.tenants,slug', as: 'firma kodu')]
    public string $kod = '';

    /** `users.name` varchar(120) — aynı değer `tenants.contact_name`e de yazılır (panel "Yetkili" satırı). */
    #[Validate('required|string|min:2|max:120', as: 'yetkili adı', message: 'Yetkilinin adı ve soyadı gereklidir.')]
    public string $yetkili = '';

    /** `users.email` GLOBAL tekil (varchar 190). */
    #[Validate('required|email|max:190|unique:pgsql_owner.users,email', as: 'e-posta')]
    public string $eposta = '';

    /** `tenants.phone` / `users.phone` varchar(20). İşletmenin numarası; isteğe bağlı. */
    #[Validate('nullable|string|max:20', as: 'telefon')]
    public string $telefon = '';

    /** bcrypt'in kendi tavanı 72 bayttır; üstü SESSİZCE kırpılır — formda durdurulur. */
    #[Validate('required|string|min:8|max:72', as: 'parola', message: 'Parola 8-72 karakter olmalıdır.')]
    public string $parola = '';

    /**
     * Hoş geldiniz e-postası gönderilsin mi. Metin ZATEN firma kodunu ve kullanıcı adını taşıyor
     * (siteden kayıtta da öyle) — birebir satışta operatör bunları telefonda söylüyor olsa bile
     * bayinin yazılı bir kopyası olması, "kodum neydi" aramasını baştan keser.
     *
     * Yine de bir ANAHTAR: elle açılan bayinin e-postası kimi zaman muhasebecinin ya da oğlunun
     * adresi olur; operatör kime posta gittiğini bilerek karar vermeli.
     */
    public bool $posta = true;

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'kod.regex' => 'Firma kodu 3-80 karakter olmalı; yalnız küçük harf, rakam ve tire içerebilir.',
            'kod.unique' => 'Bu firma kodu kullanılıyor, başka bir kod seçin.',
            'eposta.email' => 'Geçerli bir e-posta adresi girin.',
            'eposta.unique' => 'Bu e-posta adresi başka bir hesapta kayıtlı.',
        ];
    }

    /**
     * Doğrulamadan ÖNCE çağrılır: boşluk kırpar, e-postayı ve kodu küçük harfe indirir.
     *
     * NEDEN DOĞRULAMADAN ÖNCE: `unique` kuralı Postgres'te HARFE DUYARLIdır ve e-postalar
     * veritabanında küçük harfle yaşar (`Provisioning` yazarken indirir). "Ali@Firma.com"
     * normalize edilmeden doğrulanırsa kural "boşta" der, sonra INSERT 23505 ile düşerdi —
     * yani ön kontrol tam da yakalaması gereken durumu kaçırırdı.
     */
    public function normalize(): void
    {
        $this->isletme = trim($this->isletme);
        $this->yetkili = trim($this->yetkili);
        $this->telefon = trim($this->telefon);
        $this->eposta = mb_strtolower(trim($this->eposta));
        $this->kod = mb_strtolower(trim($this->kod));
    }

    /** Firma kodu boşsa işletme adından öneri üretir (kayıt ekranının `slugla()`si — tek kaynak). */
    public function kodOner(): void
    {
        if (trim($this->kod) === '' && trim($this->isletme) !== '') {
            $this->kod = Register::slugla($this->isletme);
        }
    }

    /** Boş telefon NULL olarak yazılır: '' bir numara değildir, panelde "—" görünmelidir. */
    public function telefonVeya(): ?string
    {
        return $this->telefon !== '' ? $this->telefon : null;
    }
}
