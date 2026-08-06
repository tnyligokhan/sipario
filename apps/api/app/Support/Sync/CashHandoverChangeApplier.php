<?php

namespace App\Support\Sync;

use App\Models\CashHandover;
use App\Models\User;
use InvalidArgumentException;

/**
 * Kasa devri push olaylarını uygular (APPEND cash_handovers). ChangeApplier 'cash_handover'
 * entity_type'ını buraya delege eder (OrderChangeApplier simetriği, 500 satır sınırı).
 *
 * Kayıt istemcide hesaplanmış bir MUTABAKAT SNAPSHOT'ıdır: counted/expected/diff olduğu gibi saklanır
 * (amount_kurus gibi istemciye güvenilir, kanıt append-only durur). tenant_id gövdeden alınmaz;
 * from_user_id / to_user_id yazımdan ÖNCE RLS kapsamında doğrulanır — başka bayinin kullanıcısına
 * devir bağlanamaz (kırmızı çizgi #1, savepoint zehirlenmesini önler).
 */
class CashHandoverChangeApplier
{
    /**
     * @param  array<string, mixed>  $event
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    public function apply(string $tenantId, array $event): array
    {
        $op = (string) ($event['op'] ?? '');
        if ($op !== 'handover') {
            throw new InvalidArgumentException("Geçersiz kasa devri op: {$op}");
        }

        /** @var array<string, mixed> $payload */
        $payload = (array) ($event['payload'] ?? []);
        $id = (string) SyncPayload::req($payload, 'id');
        if (CashHandover::query()->find($id) !== null) {
            // AYNI ID YENİDEN GELDİ → 'duplicate' (SESSİZ YAKINSAMA), red DEĞİL.
            //
            // ASIL KAPAK BURASIDIR, `day_closings`te değil. İki cihaz aynı kuryenin aynı gününü
            // kapattığında kapanış sunucuya İKİ AYRI OLAY olarak gider (devir önce, arşiv sonra —
            // AraTahsilatSyncTest bu sırayı yazar) ve her olay kendi savepoint'indedir. Tekilliği
            // yalnız `day_closings`e koymak devri commit edip arşivi reddederdi: ortada SAHİPSİZ
            // bir devir kalır, o da "kapanışa bağlı olmayan devir" tanımı gereği ARA TAHSİLATA
            // terfi eder ve çift sayılan para (`teslimEdilenNakit`) hiç düzelmezdi. Para hatası
            // ekran özetinde değil PARANIN DEFTERİNDE kapanır.
            //
            // Kapanış devrinin id'si de kapanışla aynı çekirdekten TÜRETİLİR, yani aynı id = aynı
            // mantıksal devir.
            //
            // NEDEN RED DEĞİL: `rejected` istemcide KARANTİNAdır; iyi huylu bir tekrar elle
            // incelemeye kalırdı. 'duplicate' → `acked`, kayıp yok (kayıt zaten sunucuda).
            //
            // ⚠️ BEDELİ AÇIK VE KABUL EDİLDİ (lead kararı 2026-08-06): İKİNCİ denemenin SAYILAN
            // tutarı kayda GEÇMEZ — ilk mutabakat kazanır.
            //
            // ARA TAHSİLATLAR ETKİLENMEZ: id'leri türetilmez (rastgele kalır), yani "gün içinde
            // çok kez kasa devri" serbestliği korunur — kısıt yalnız KAPANIŞ devrindedir.
            //
            // ⚠️ BU DAL RLS'E BAĞLIDIR: `id` GLOBAL primary key olduğu için başka bir bayinin
            // kaydı da aynı id'yi taşıyabilir ve onu 'duplicate' saymak B'nin devrini A'nınki
            // yüzünden sessizce yutmak olurdu. `find()` RLS altında koştuğu için başka kiracının
            // satırı görünmez → null → INSERT → 23505 → GÖRÜNÜR red. Gerekçenin tamamı ve zinciri
            // kilitleyen test için bkz. `DayClosingChangeApplier` (aynı dal, aynı bağımlılık).
            return ['status' => 'duplicate', 'entity_id' => $id, 'changes' => []];
        }

        $fromUserId = (string) SyncPayload::req($payload, 'from_user_id');
        if (! User::query()->whereKey($fromUserId)->exists()) {
            throw new InvalidArgumentException('from_user_id bu bayide bulunamadı');
        }

        $toUserId = isset($payload['to_user_id']) ? (string) $payload['to_user_id'] : null;
        if ($toUserId !== null && ! User::query()->whereKey($toUserId)->exists()) {
            throw new InvalidArgumentException('to_user_id bu bayide bulunamadı');
        }

        $handover = new CashHandover;
        $handover->forceFill([
            'id' => $id,
            'tenant_id' => $tenantId,
            'from_user_id' => $fromUserId,
            'to_user_id' => $toUserId,
            'counted_cash_kurus' => (int) SyncPayload::req($payload, 'counted_cash_kurus'),
            'expected_cash_kurus' => (int) SyncPayload::req($payload, 'expected_cash_kurus'),
            'diff_kurus' => (int) SyncPayload::req($payload, 'diff_kurus'),
            'period_start' => SyncPayload::zaman($payload['period_start'] ?? null),
            'occurred_at' => SyncPayload::zaman((string) ($event['occurred_at'] ?? '')),
            'device_id' => $event['device_id'] ?? null,
            'note' => $payload['note'] ?? null,
        ])->save();

        return ['status' => 'applied', 'entity_id' => $id,
            'changes' => [SyncPayload::change('cash_handover', $id, 'upsert', $handover)]];
    }
}
