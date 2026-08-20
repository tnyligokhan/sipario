<?php

namespace App\Support;

use App\Abonelik\KotaDoluException;
use App\Abonelik\KuryeKotasi;
use App\Abonelik\PlanDeposu;
use App\Enums\TenantStatus;
use App\Enums\UserRole;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

/**
 * Bayi provizyonu (hesap açma). Bu işlemler RLS'i MEŞRU olarak atlar: yeni bir tenant satırı
 * eklemek yumurta-tavuk sorunudur (tenants WITH CHECK, app.tenant_id = eklenen id ister) ve
 * hesap açma zaten kiracı-üstü bir eylemdir. Bu yüzden owner (pgsql_owner) bağlantısı kullanılır.
 *
 * Testlerdeki iki-tenant seed helper'ı da bu deseni kullanabilir: provizyon owner ile, ASIL
 * test istekleri app rolü token'larıyla (RLS'e tabi).
 */
class Provisioning
{
    /**
     * Provizyon işini owner bağlantısında koşar (varsayılan bağlantıyı geçici olarak değiştirir).
     *
     * @template T
     *
     * @param  callable():T  $callback
     * @return T
     */
    public static function asOwner(callable $callback): mixed
    {
        $previous = DB::getDefaultConnection();
        DB::setDefaultConnection('pgsql_owner');

        try {
            return $callback();
        } finally {
            DB::setDefaultConnection($previous);
        }
    }

    /**
     * Yeni bir bayi + patron kullanıcı oluşturur (deneme süresi plandan).
     *
     * [$patronUsername] mobil girişin kimliğidir (tasarım `s-giris.jsx`: firma kodu + kullanıcı
     * adı). Verilmezse 'patron' kullanılır — kullanıcı adı TENANT İÇİNDE tekil olduğu için
     * her bayide aynı varsayılan meşrudur ve kurulum sonrası akılda kalıcıdır.
     *
     * [$slug] KULLANICININ SEÇTİĞİ firma kodu. Verilmezse eski davranış sürer (addan türetilir +
     * çakışırsa sayaç). Verilirse AYNI TRANSACTION içinde benzersizliği doğrulanır ve çakışmada
     * `DuplicateSlugException` atılır. Bunun öncesinde kayıt ekranı kodu tenant YARATILDIKTAN
     * SONRA ikinci bir UPDATE ile uyguluyordu: bayi bir an yanlış kodla yaşıyordu ve çakışma ham
     * 23505 olarak çıkıp yutuluyordu (kullanıcıya vermediğimiz bir kodu göstermemek için).
     *
     * [$patronName] yetkilinin ADIdır: hem `users.name`e hem `tenants.contact_name`e yazılır —
     * panelin "Yetkili" satırı ve firma araması (tasarım `07-Uyeler.jsx`: "Firma, yetkili veya il
     * ara") bu kolonu okur. Verilmezse `users.name`de 'Patron' varsayılanı korunur ve
     * `contact_name` NULL kalır; "Patron" kelimesini yetkili adı diye yazmak, panelde 40 bayinin
     * yetkilisinin aynı görünmesi demekti.
     *
     * [$phone] hem `tenants.phone`a hem `users.phone`a yazılır: ilki işletmenin numarası (panel
     * arar), ikincisi patronun kendi numarası. Kayıt ekranında ikisi de aynı alandan gelir.
     *
     * @return array{tenant: Tenant, patron: User}
     *
     * @throws DuplicateSlugException istenen firma kodu başka bir bayide
     * @throws InvalidArgumentException istenen firma kodu biçime uymuyor (arayüz zaten doğrular)
     */
    public static function createTenantWithPatron(
        string $tenantName,
        string $patronEmail,
        string $patronPassword,
        ?string $patronName = null,
        string $patronUsername = 'patron',
        ?string $slug = null,
        ?string $phone = null,
    ): array {
        $istenenKod = self::kodDogrula($slug);

        return self::asOwner(function () use ($tenantName, $patronEmail, $patronPassword, $patronName, $patronUsername, $istenenKod, $phone) {
            // TEK TRANSACTION: kod kontrolü + tenant + patron + senkron sayacı. Öncesinde bunlar
            // ayrı yazımlardı ve araya düşen bir hata yarım bir bayi bırakabiliyordu.
            return DB::transaction(function () use ($tenantName, $patronEmail, $patronPassword, $patronName, $patronUsername, $istenenKod, $phone) {
                // Deneme süresi ve kotalar PLANDAN okunur (App\Abonelik\PlanDeposu): panelden
                // "Deneme süresi 45 gün" denince yeni bayiler O GÜN 45 gün almalı, bir deploy sonra
                // değil. Plan satırı yoksa config yedeği devreye girer (30 gün / 50 hak / 3 kurye).
                $plan = new PlanDeposu('pgsql_owner');

                // Firma kodu ZORUNLU (giriş ekranının ilk alanı). İstenen kod varsa ÖNCE burada
                // kontrol edilir — kullanıcıya anlaşılır bir hata vermek için. Ama bu kontrol
                // yarışa karşı YETMEZ: iki eşzamanlı kayıt de "boş" görebilir. Gerçek emniyet
                // `tenants.slug` benzersiz indeksidir; aşağıdaki catch onu da aynı istisnaya çevirir.
                if ($istenenKod !== null && Tenant::query()->where('slug', $istenenKod)->exists()) {
                    throw new DuplicateSlugException('Bu firma kodu kullanılıyor, başka bir kod seçin.');
                }

                // valid_until = trial_ends_at (FAZ 5a): tek enforcement çıpası; trial_ends_at yalnız
                // "deneme miydi" bilgisi. Ödeme onayında valid_until dönem kadar uzar (5b).
                $trialEnds = now()->addDays($plan->denemeGun());

                try {
                    $tenant = Tenant::create([
                        'name' => $tenantName,
                        // İstenen kod yoksa addan türetilir; çakışırsa sayaç eklenir — kurulumda
                        // insan müdahalesi gerekmeden benzersizleşir.
                        'slug' => $istenenKod ?? self::benzersizKod($tenantName),
                        'status' => TenantStatus::Trial->value,
                        'trial_ends_at' => $trialEnds,
                        'valid_until' => $trialEnds,
                        'route_credits_monthly' => $plan->rotaKontoruAylik(),
                        'courier_limit' => $plan->kuryeLimiti(),
                        'contact_name' => $patronName,
                        'phone' => $phone,
                    ]);
                } catch (QueryException $e) {
                    // 23505 = unique_violation. Yarışın kaybeden tarafı buraya düşer; kullanıcıya
                    // ham SQL hatası değil, ön kontroldekiyle AYNI cümle gösterilir.
                    if ((string) $e->getCode() === '23505' && $istenenKod !== null) {
                        throw new DuplicateSlugException('Bu firma kodu kullanılıyor, başka bir kod seçin.');
                    }
                    throw $e;
                }

                $patron = User::create([
                    'tenant_id' => $tenant->id,
                    'name' => $patronName ?? 'Patron',
                    'email' => mb_strtolower($patronEmail),
                    'username' => mb_strtolower($patronUsername),
                    'password' => $patronPassword, // 'hashed' cast'i bcrypt'ler
                    'role' => UserRole::Patron->value,
                    'status' => 'active',
                    'phone' => $phone,
                ]);

                // Senkron seq sayacının başlangıç satırı (owner bağlamında; RLS'i superuser atlar).
                // push() zaten ON CONFLICT DO NOTHING ile self-heal yapar; burada üretim için baştan kurulur.
                DB::table('tenant_sync_state')->insertOrIgnore(['tenant_id' => $tenant->id, 'last_seq' => 0]);

                return ['tenant' => $tenant, 'patron' => $patron];
            });
        });
    }

    /**
     * İstenen firma kodunu doğrular (tasarım kuralı ^[a-z0-9-]{3,80}$, `benzersizKod`un ürettiği
     * biçimin aynısı). Normalize ETMEZ, yalnız kabul eder ya da reddeder: kullanıcının yazdığından
     * BAŞKA bir kodu sessizce uygulamak, ekranda gösterilen kod ile veritabanındakinin ayrışması
     * demekti — bayiye vermediğimiz bir kodu göstermek en kötü yalandır.
     *
     * Biçim hatası `InvalidArgumentException`tır (kullanıcı hatası değil ÇAĞIRAN hatası): kayıt
     * ekranı kodu zaten doğruluyor, buraya bozuk bir değer geliyorsa doğrulama atlanmış demektir.
     */
    private static function kodDogrula(?string $slug): ?string
    {
        if ($slug === null || trim($slug) === '') {
            return null;
        }

        $kod = mb_strtolower(trim($slug));
        if (preg_match('/^[a-z0-9-]{3,80}$/', $kod) !== 1) {
            throw new InvalidArgumentException('Firma kodu 3-80 karakter olmalı ve yalnız küçük harf, rakam ve tire içermelidir.');
        }

        return $kod;
    }

    /**
     * KURYE HESABI AÇMANIN TEK MEŞRU YOLU — kota kapısından (App\Abonelik\KuryeKotasi) geçer.
     *
     * NEDEN BURADA: kurye açmak da tenant açmak gibi kiracı-ÜSTÜ bir provizyon eylemidir ve owner
     * bağlamı ister (panel rolünün `users`ta UPDATE/INSERT'i yoktur; RLS altındaki bir bağlantıda
     * ise kota sayımı oturum bağlamına bağlı kalırdı). Kapının servis içinde değil BURADA çağrılması
     * bilinçli: kotayı hesabı YARATAN yolun kendisi zorlamazsa, yarın açılacak ikinci bir yol kapıyı
     * atlayabilir ve bunu kimse fark etmez.
     *
     * Kota doluysa KotaDoluException fırlar ve KULLANICI YARATILMAZ (kontrol, INSERT'ten önce).
     *
     * BAYAT NESNE TUZAĞI (duman testinde yakalandı): çağıran elindeki `Tenant` nesnesini geçer, ama o
     * nesne bir ek paket tanımlamasından ÖNCE okunmuş olabilir ve `courier_limit` alanı eski kalır.
     * Kota o zaman DB'deki gerçeğe değil çağıranın hafızasına göre kararlaşır — hem yeni hakkını
     * kullanamayan bayi hem de tersi mümkün. Bu yüzden bayi ne verilirse verilsin BURADA, owner
     * bağlamında, id'siyle yeniden okunur; kapı her zaman güncel satırı görür.
     *
     * @throws KotaDoluException
     */
    public static function createCourier(
        Tenant|string $tenant,
        string $name,
        string $username,
        string $password,
        ?string $phone = null,
    ): User {
        return self::createStaff($tenant, $name, $username, $password, UserRole::Kurye, $phone);
    }

    /**
     * PERSONEL hesabı açar — kurye ya da TEZGÂH (2026-08-20).
     *
     * `createCourier` bu metoda delege eder ve adıyla kalır: 2026-08-20'den önce açılabilen tek
     * hesap türü kuryeydi ve panel/seeder o adı çağırıyor. Yeni yüzeyler buraya gelir.
     *
     * PATRON BURADAN AÇILAMAZ ve bu bir kısıt değil KAPI: patron hesabı bayinin SAHİBİDİR,
     * abonelik ve fatura ona bağlıdır; ikinci bir sahip yaratmak, hesabı kimin devrettiğini
     * cevaplanamaz hâle getirir. Bayinin panelinden ikinci patron açma isteği gelirse bu ayrı
     * bir karar olarak verilir.
     *
     * KOTA HER İKİ ROLE DE UYGULANIR (`KuryeKotasi`): tezgâh hesabı bedava olsaydı, atama hedefi
     * olabilen (yani fiilen teslimat yapabilen) sınırsız hesap açılabilirdi ve "3 kurye hesabı"
     * sözü anlamını yitirirdi.
     */
    public static function createStaff(
        Tenant|string $tenant,
        string $name,
        string $username,
        string $password,
        UserRole $role = UserRole::Kurye,
        ?string $phone = null,
    ): User {
        if ($role === UserRole::Patron) {
            throw new InvalidArgumentException('Patron hesabı bu yoldan açılamaz');
        }

        $tenantId = $tenant instanceof Tenant ? $tenant->id : $tenant;

        return self::asOwner(function () use ($tenantId, $name, $username, $password, $role, $phone) {
            $bayi = Tenant::query()->findOrFail($tenantId);

            (new KuryeKotasi('pgsql_owner'))->kontrolEt($bayi);

            return User::create([
                'tenant_id' => $bayi->id,
                'name' => $name,
                // E-posta tenant-üstü TEKİLdir; personel hesabı mobilde firma kodu + kullanıcı
                // adıyla girer, e-posta yalnız teknik bir zorunluluktur.
                'email' => mb_strtolower($username).'@'.$bayi->slug.'.sipario.local',
                'username' => mb_strtolower($username),
                'password' => $password, // 'hashed' cast'i bcrypt'ler
                'role' => $role->value,
                'status' => 'active',
                'phone' => $phone,
            ]);
        });
    }

    /**
     * İşletme adından firma kodu türetir (tasarım kuralı ^[a-z0-9-]{3,80}$), kullanılmışsa
     * sonuna sayaç ekler. Türkçe harfler ASCII karşılığına iner.
     * OWNER bağlamında çağrılmalıdır (tenants RLS altındadır).
     */
    public static function benzersizKod(string $ad): string
    {
        $tr = ['ı' => 'i', 'İ' => 'i', 'ş' => 's', 'Ş' => 's', 'ğ' => 'g', 'Ğ' => 'g',
            'ü' => 'u', 'Ü' => 'u', 'ö' => 'o', 'Ö' => 'o', 'ç' => 'c', 'Ç' => 'c'];
        $taban = trim((string) preg_replace('/[^a-z0-9]+/', '-', mb_strtolower(strtr($ad, $tr), 'UTF-8')), '-');
        if (strlen($taban) < 3) {
            $taban = str_pad($taban === '' ? 'bayi' : $taban, 3, 'x');
        }
        $taban = substr($taban, 0, 76);

        $aday = $taban;
        $n = 1;
        while (Tenant::query()->where('slug', $aday)->exists()) {
            $aday = $taban.'-'.++$n;
        }

        return $aday;
    }
}
