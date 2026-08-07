<?php

namespace App\Abonelik;

use App\Models\TenantNote;
use Illuminate\Database\Eloquent\Collection;

/**
 * Panelden bayiye not ekle/listele (tasarım `07-Uyeler.jsx` firma detayı: "Telefonla arandı,
 * haftaya ödeyecek.").
 *
 * APPEND-ONLY: düzenleme/silme yoktur (bkz. migration 005005).
 *
 * DENETİM GÜNLÜĞÜNE NOT METNİ YAZILMAZ — yalnız "not eklendi" eylemi. Metin serbesttir ve içinde
 * kişisel veri geçebilir; panel_audit'in KVKK-nötr sözleşmesi (kırmızı çizgi #4) buna kapalıdır.
 */
class TenantNotServisi extends AbonelikServisi
{
    public function ekle(string $tenantId, string $body, ?string $adminId = null): TenantNote
    {
        $metin = trim($body);
        if ($metin === '') {
            throw new GecersizTutarException('Not boş olamaz.');
        }

        /** @var TenantNote $not */
        $not = TenantNote::on($this->connection)->create([
            'tenant_id' => $tenantId,
            'admin_user_id' => $adminId,
            'body' => $metin,
        ]);

        $this->denetle($adminId, $tenantId, 'tenant_note');

        return $not;
    }

    /**
     * @return Collection<int, TenantNote>
     */
    public function liste(string $tenantId, int $limit = 100): Collection
    {
        return TenantNote::on($this->connection)
            ->where('tenant_id', $tenantId)
            ->orderByDesc('created_at')
            ->limit($limit)
            ->get();
    }
}
