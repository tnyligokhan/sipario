<?php

namespace App\Support;

use App\Abonelik\KotaDoluException;
use App\Abonelik\KuryeKotasi;
use App\Abonelik\PlanDeposu;
use App\Enums\TenantStatus;
use App\Enums\UserRole;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Support\Facades\DB;

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
     * Yeni bir bayi + patron kullanıcı oluşturur (30 gün deneme).
     *
     * [$patronUsername] mobil girişin kimliğidir (tasarım `s-giris.jsx`: firma kodu + kullanıcı
     * adı). Verilmezse 'patron' kullanılır — kullanıcı adı TENANT İÇİNDE tekil olduğu için
     * her bayide aynı varsayılan meşrudur ve kurulum sonrası akılda kalıcıdır.
     *
     * @return array{tenant: Tenant, patron: User}
     */
    public static function createTenantWithPatron(
        string $tenantName,
        string $patronEmail,
        string $patronPassword,
        string $patronName = 'Patron',
        string $patronUsername = 'patron',
    ): array {
        return self::asOwner(function () use ($tenantName, $patronEmail, $patronPassword, $patronName, $patronUsername) {
            // Deneme süresi ve kotalar PLANDAN okunur (App\Abonelik\PlanDeposu): panelden
            // "Deneme süresi 45 gün" denince yeni bayiler O GÜN 45 gün almalı, bir deploy sonra
            // değil. Plan satırı yoksa config yedeği devreye girer (30 gün / 50 hak / 3 kurye).
            $plan = new PlanDeposu('pgsql_owner');

            // valid_until = trial_ends_at (FAZ 5a): tek enforcement çıpası; trial_ends_at yalnız
            // "deneme miydi" bilgisi. Ödeme onayında valid_until dönem kadar uzar (5b).
            $trialEnds = now()->addDays($plan->denemeGun());
            $tenant = Tenant::create([
                'name' => $tenantName,
                // Firma kodu ZORUNLU (giriş ekranının ilk alanı). Addan türetilir; çakışırsa
                // sayaç eklenir — kurulumda insan müdahalesi gerekmeden benzersizleşir.
                'slug' => self::benzersizKod($tenantName),
                'status' => TenantStatus::Trial->value,
                'trial_ends_at' => $trialEnds,
                'valid_until' => $trialEnds,
                'route_credits_monthly' => $plan->rotaKontoruAylik(),
                'courier_limit' => $plan->kuryeLimiti(),
            ]);

            $patron = User::create([
                'tenant_id' => $tenant->id,
                'name' => $patronName,
                'email' => mb_strtolower($patronEmail),
                'username' => mb_strtolower($patronUsername),
                'password' => $patronPassword, // 'hashed' cast'i bcrypt'ler
                'role' => UserRole::Patron->value,
                'status' => 'active',
            ]);

            // Senkron seq sayacının başlangıç satırı (owner bağlamında; RLS'i superuser atlar).
            // push() zaten ON CONFLICT DO NOTHING ile self-heal yapar; burada üretim için baştan kurulur.
            DB::table('tenant_sync_state')->insertOrIgnore(['tenant_id' => $tenant->id, 'last_seq' => 0]);

            return ['tenant' => $tenant, 'patron' => $patron];
        });
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
        $tenantId = $tenant instanceof Tenant ? $tenant->id : $tenant;

        return self::asOwner(function () use ($tenantId, $name, $username, $password, $phone) {
            $bayi = Tenant::query()->findOrFail($tenantId);

            (new KuryeKotasi('pgsql_owner'))->kontrolEt($bayi);

            return User::create([
                'tenant_id' => $bayi->id,
                'name' => $name,
                // E-posta tenant-üstü TEKİLdir; kurye hesabı mobilde firma kodu + kullanıcı adıyla
                // girer, e-posta yalnız teknik bir zorunluluktur.
                'email' => mb_strtolower($username).'@'.$bayi->slug.'.sipario.local',
                'username' => mb_strtolower($username),
                'password' => $password, // 'hashed' cast'i bcrypt'ler
                'role' => UserRole::Kurye->value,
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
