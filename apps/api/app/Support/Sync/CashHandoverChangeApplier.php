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
            throw new InvalidArgumentException('Bu kasa devri kaydı zaten var');
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
            'period_start' => $payload['period_start'] ?? null,
            'occurred_at' => (string) ($event['occurred_at'] ?? ''),
            'device_id' => $event['device_id'] ?? null,
            'note' => $payload['note'] ?? null,
        ])->save();

        return ['status' => 'applied', 'entity_id' => $id,
            'changes' => [SyncPayload::change('cash_handover', $id, 'upsert', $handover)]];
    }
}
