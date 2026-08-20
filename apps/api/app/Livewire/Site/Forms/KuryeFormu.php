<?php

namespace App\Livewire\Site\Forms;

use App\Enums\UserRole;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Illuminate\Validation\Rule;
use Livewire\Form;

/**
 * "Personel hesabı aç" formu (kurye ya da tezgâh) — bayinin web hesap panelindeki Ekip bölümü.
 * Sınıf adı `KuryeFormu` kaldı: 2026-08-20'ye kadar açılabilen tek tür kuryeydi ve adı
 * değiştirmek Livewire bileşen/görünüm bağlarını gereksizce kırardı.
 *
 * NEDEN AYRI BİR YAZMA YOLU DEĞİL: kullanıcı yaratmak senkron varlığı yazmak DEĞİLDİR.
 * `ProfileChangeApplier` kimlik yüzeyini bilerek dışarıda tutar (ad/telefon/aktiflik yazar;
 * rol/e-posta/parola YAZMAZ) — offline kuyruğa kullanıcı yaratmayı açmak yetki yükseltme
 * vektörüdür. Bu yüzden hesap açma `Provisioning::createCourier`tan geçer: kiracı-ÜSTÜ bir
 * provizyon eylemidir, owner bağlamı ister ve KOTA KAPISI (`KuryeKotasi`) oranın içindedir.
 * Yeni hesap telefona `sync_changes` ile değil, her senkron yanıtındaki `team` bloğuyla iner
 * (SyncService::teamPayload — liste toptan tazelenir, LWW'ye hiç girmez).
 *
 * TEKİLLİK KAPISI BURADADIR ÇÜNKÜ KISIT VERİTABANINDA. `users.username` bayi içinde,
 * `users.email` ise GLOBAL tekildir. İkisi de yakalanmazsa kullanıcı 23505'i 500 olarak görür;
 * oysa bu bir form hatasıdır ve alanın adıyla söylenmelidir. Sorgular `pgsql_owner` ile
 * bağlantı-nitelikli koşar: RLS'li varsayılan bağlantıda kiracı bağlamı kurulu değilse
 * tekillik sorgusu SIFIR satır görür ve kapı sessizce açılırdı — kotanın da tekilliğin de
 * en tehlikeli arıza biçimi budur (KuryeKotasi'nin belge başlığındaki aynı ders).
 */
class KuryeFormu extends Form
{
    public string $ad = '';

    public string $kullaniciAdi = '';

    public string $parola = '';

    public string $telefon = '';

    /**
     * Açılacak hesabın ROLÜ (2026-08-20 kullanıcı isteği: "kurye haricinde farklı roller de
     * olması gerekiyor — kasiyer/tezgâh").
     *
     * VARSAYILAN KURYE: bugüne kadar açılabilen tek hesap türü oydu ve su bayisinde ihtiyacın
     * çoğu hâlâ odur; varsayılanı değiştirmek, formu hızlıca dolduran patrona yanlış rol
     * açtırırdı.
     *
     * PATRON BURADA YOK ve olamaz — kapı ayrıca `Provisioning::createStaff` içinde de durur
     * (form bir istemci beyanıdır; tek kapı yetmez).
     */
    public string $rol = 'kurye';

    /**
     * Doğrular ve personel hesabını açar. KOTA KAPISI ÇAĞIRANDA değil `Provisioning::createStaff`
     * içindedir; buraya gelmeden önce Ekip bileşeni kotayı ayrıca sorar (kullanıcıya form
     * doldurtmadan söyleyebilmek için) — ikisi aynı `KuryeKotasi` sınıfına sorar, iki ayrı kural
     * değildir.
     */
    public function olustur(Tenant $bayi): User
    {
        $this->kullaniciAdi = mb_strtolower(trim($this->kullaniciAdi));
        $this->ad = trim($this->ad);

        $this->validate($this->kurallar($bayi), $this->mesajlar());

        return Provisioning::createStaff(
            $bayi,
            $this->ad,
            $this->kullaniciAdi,
            $this->parola,
            UserRole::from($this->rol),
            trim($this->telefon) === '' ? null : trim($this->telefon),
        );
    }

    public function temizle(): void
    {
        $this->ad = '';
        $this->kullaniciAdi = '';
        $this->parola = '';
        $this->telefon = '';
        $this->rol = 'kurye';
    }

    /**
     * @return array<string, mixed>
     */
    private function kurallar(Tenant $bayi): array
    {
        return [
            'ad' => ['required', 'string', 'min:2', 'max:120'],
            // Kural DB kısıtının aynısı (migration 000701: ^[a-z0-9._-]{3,60}$) ve mobil
            // `UpdateCredentialsRequest` ile birebir aynı — kuryenin giriş adı hangi yüzeyden
            // girilirse girilsin aynı kurala uymalı, yoksa web'den açılan hesabın adı mobilden
            // düzeltilemez olurdu.
            'kullaniciAdi' => ['required', 'string', 'regex:/^[a-z0-9._-]{3,60}$/',
                Rule::unique('pgsql_owner.users', 'username')->where('tenant_id', $bayi->id),
                // GLOBAL e-posta tekilliği. `createCourier` adresi
                // `<kullanici>@<firma-kodu>.sipario.local` diye TÜRETİR ve `users_email_unique`
                // bayi-üstüdür. `Rule::unique` BURADA KULLANILAMAZ: o, alanın KENDİ değerini
                // sorgular; bizim aradığımız ise ondan türetilen BAŞKA bir değerdir. Hata
                // kullanıcı adı alanına bağlanır çünkü çarpışmanın tek girdisi odur — bayiye
                // "e-posta çakıştı" demek anlamsız olurdu, o alan ekranda hiç yok.
                function (string $attribute, mixed $deger, callable $fail) use ($bayi): void {
                    $eposta = mb_strtolower(trim((string) $deger)).'@'.$bayi->slug.'.sipario.local';
                    if (User::on('pgsql_owner')->where('email', $eposta)->exists()) {
                        $fail('Bu kullanıcı adı bu bayide zaten kullanılıyor (pasif bir hesap da tutuyor olabilir)');
                    }
                },
            ],
            // Alt sınır 4: LoginRequest ve UpdateCredentialsRequest ile AYNI sayı. Daha uzunu,
            // patronun kuryesine veremeyeceği bir parola üretirdi (BRIEF: parolalar kısadır).
            'parola' => ['required', 'string', 'min:4', 'max:72'],
            'telefon' => ['nullable', 'string', 'max:20'],
            // AK LİSTE, kara liste değil: `UserRole` yarın büyüdüğünde yeni bir rol buradan
            // KENDİLİĞİNDEN açılmamalı. `patron` listede yok — hesap sahipliği devredilemez.
            'rol' => ['required', Rule::in([UserRole::Kurye->value, UserRole::Operator->value])],
        ];
    }

    /**
     * @return array<string, string>
     */
    private function mesajlar(): array
    {
        return [
            'ad.required' => 'Personelin adını girin',
            'ad.min' => 'En az 2 karakter',
            'kullaniciAdi.required' => 'Giriş için bir kullanıcı adı belirleyin',
            'kullaniciAdi.regex' => 'Kullanıcı adı 3-60 karakter olmalı; küçük harf, rakam, nokta, tire ve alt çizgi kullanılabilir',
            'kullaniciAdi.unique' => 'Bu kullanıcı adı bu bayide zaten kullanılıyor (pasif bir hesap da tutuyor olabilir)',
            'parola.required' => 'Personelin gireceği parolayı belirleyin',
            'parola.min' => 'Parola en az 4 karakter olmalı',
        ];
    }
}
