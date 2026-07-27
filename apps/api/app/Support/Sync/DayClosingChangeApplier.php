<?php

namespace App\Support\Sync;

use App\Models\CashHandover;
use App\Models\DayClosing;
use App\Models\User;
use InvalidArgumentException;

/**
 * Gün sonu kapanış push olaylarını uygular (APPEND day_closings). ChangeApplier 'day_closing'
 * entity_type'ını buraya delege eder (CashHandoverChangeApplier simetriği).
 *
 * Kayıt istemcide hesaplanmış bir ARŞİV SNAPSHOT'ıdır: özet tutarlar olduğu gibi saklanır
 * (cash_handovers ile aynı güven modeli — DECISIONS Faz 4 "counted/expected/diff verbatim").
 * Kapatıldığı andaki gerçek dondurulur; sonradan gelen geç senkron arşivi DEĞİŞTİRMEZ.
 *
 * tenant_id gövdeden alınmaz. user_id (kurye) ve cash_handover_id yazımdan ÖNCE RLS kapsamında
 * doğrulanır — başka bayinin kuryesine/devrine kapanış bağlanamaz (kırmızı çizgi #1).
 */
class DayClosingChangeApplier
{
    /**
     * @param  array<string, mixed>  $event
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    public function apply(string $tenantId, array $event): array
    {
        $op = (string) ($event['op'] ?? '');
        if ($op !== 'closing') {
            throw new InvalidArgumentException("Geçersiz gün sonu op: {$op}");
        }

        /** @var array<string, mixed> $payload */
        $payload = (array) ($event['payload'] ?? []);
        $id = (string) SyncPayload::req($payload, 'id');
        if (DayClosing::query()->find($id) !== null) {
            throw new InvalidArgumentException('Bu kapanış kaydı zaten var');
        }

        $scope = (string) SyncPayload::req($payload, 'scope');
        if (! in_array($scope, ['day', 'courier'], true)) {
            throw new InvalidArgumentException("Geçersiz scope: {$scope}");
        }

        // scope ile user_id tutarlılığı: DB CHECK'i (migration 604) zaten zorlar; burada ÖNDEN
        // reddederek transaction zehirlenmesini önlüyoruz (savepoint yerine kapıda dur).
        $userId = isset($payload['user_id']) ? (string) $payload['user_id'] : null;
        if ($scope === 'courier' && $userId === null) {
            throw new InvalidArgumentException('courier kapanışında user_id gerekli');
        }
        if ($scope === 'day' && $userId !== null) {
            throw new InvalidArgumentException('gün kapanışında user_id olamaz');
        }
        if ($userId !== null && ! User::query()->whereKey($userId)->exists()) {
            throw new InvalidArgumentException('user_id bu bayide bulunamadı');
        }

        $handoverId = isset($payload['cash_handover_id']) ? (string) $payload['cash_handover_id'] : null;
        if ($handoverId !== null && ! CashHandover::query()->whereKey($handoverId)->exists()) {
            throw new InvalidArgumentException('cash_handover_id bu bayide bulunamadı');
        }

        $closing = new DayClosing;
        $closing->forceFill([
            'id' => $id,
            'tenant_id' => $tenantId,
            'scope' => $scope,
            'user_id' => $userId,
            'period_start' => $payload['period_start'] ?? null,
            'delivery_count' => (int) ($payload['delivery_count'] ?? 0),
            'total_collected_kurus' => (int) ($payload['total_collected_kurus'] ?? 0),
            'cash_nakit_kurus' => (int) ($payload['cash_nakit_kurus'] ?? 0),
            'cash_kart_kurus' => (int) ($payload['cash_kart_kurus'] ?? 0),
            'cash_havale_kurus' => (int) ($payload['cash_havale_kurus'] ?? 0),
            'open_credit_kurus' => (int) ($payload['open_credit_kurus'] ?? 0),
            'expected_cash_kurus' => (int) ($payload['expected_cash_kurus'] ?? 0),
            'counted_cash_kurus' => isset($payload['counted_cash_kurus'])
                ? (int) $payload['counted_cash_kurus'] : null,
            'diff_kurus' => (int) ($payload['diff_kurus'] ?? 0),
            'cash_handover_id' => $handoverId,
            'note' => $payload['note'] ?? null,
            'occurred_at' => (string) ($event['occurred_at'] ?? ''),
            'device_id' => $event['device_id'] ?? null,
        ])->save();

        return ['status' => 'applied', 'entity_id' => $id,
            'changes' => [SyncPayload::change('day_closing', $id, 'upsert', $closing)]];
    }
}
