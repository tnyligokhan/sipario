<?php

namespace App\Abonelik;

use App\Enums\UserRole;
use App\Models\Tenant;
use App\Models\User;

/**
 * KURYE HESABI KOTA KAPISI. "3 kurye hesabı" bugüne kadar yalnız fiyat sayfasındaki bir CÜMLEydi;
 * hiçbir yerde zorlanmıyordu. Ek kurye paketi satacaksak kotanın SUNUCUDA gerçek olması gerekir —
 * yoksa paket, karşılığı olmayan bir şey satmak olur.
 *
 * SAYIM KURALI: yalnız `role='kurye'` VE `status='active'` kullanıcılar sayılır. Pasifleştirilmiş
 * kurye kotadan DÜŞMEZ — işten çıkan kuryenin hesabı geçmiş atamalarda adıyla görünmeye devam eder
 * (silinmez), ama bayinin hakkını işgal etmesi için bir sebep yok. Patron/operator hiç sayılmaz.
 *
 * BAĞLANTI: varsayılan `pgsql_owner`. Sayım `users` üzerinde yapılır ve kapı hem panelden hem de
 * provizyondan (RLS oturumu KURULMAMIŞ olabilir) çağrılır; RLS altındaki bir bağlantıda oturum
 * bağlamı yoksa sayım SIFIR döner ve kapı sessizce açılırdı — kotanın en tehlikeli arıza biçimi
 * budur. Bu yüzden sorgu tenant_id ile AÇIKÇA filtrelenir ve bağlam bağımsız koşar.
 */
class KuryeKotasi extends AbonelikServisi
{
    /**
     * Yeni bir kurye hesabı açılabilir mi? Açılamazsa KotaDoluException.
     * Kurye yaratan HER yol buradan geçmek zorundadır (Provisioning::createCourier tek meşru yol).
     */
    public function kontrolEt(Tenant $tenant): void
    {
        $limit = $tenant->courier_limit;
        $kullanilan = $this->aktifKuryeSayisi($tenant->id);

        if ($kullanilan >= $limit) {
            throw new KotaDoluException($limit, $kullanilan);
        }
    }

    /** Tenant nesnesi elde değilken (panel/seeder/provizyon) — id ile aynı kapı. */
    public function bayiKontrolEt(string $tenantId): void
    {
        $this->kontrolEt(Tenant::on($this->connection)->findOrFail($tenantId));
    }

    /**
     * Kota kullanımı — tasarımın hesap panelindeki "2 / 3" göstergesi.
     *
     * @return array{limit: int, kullanilan: int, kalan: int}
     */
    public function kullanim(Tenant $tenant): array
    {
        $kullanilan = $this->aktifKuryeSayisi($tenant->id);

        return [
            'limit' => $tenant->courier_limit,
            'kullanilan' => $kullanilan,
            'kalan' => max(0, $tenant->courier_limit - $kullanilan),
        ];
    }

    private function aktifKuryeSayisi(string $tenantId): int
    {
        return User::on($this->connection)
            ->where('tenant_id', $tenantId)
            ->where('role', UserRole::Kurye->value)
            ->where('status', 'active')
            ->count();
    }
}
