<?php

namespace App\Support\Sync;

use App\Models\CouponBalance;
use App\Models\CouponMovement;
use App\Models\Customer;
use App\Models\Order;
use App\Models\Product;
use Illuminate\Database\Eloquent\Builder;
use InvalidArgumentException;

/**
 * Kupon push olaylarını uygular (APPEND coupon_movements + coupon_balances önbelleği türet).
 * ChangeApplier 'coupon' entity_type'ını buraya delege eder (OrderChangeApplier simetriği, 500 satır).
 *
 * Kupon PARA değil ADETtir (DECISIONS Faz 3): qty_delta İMZALI. op = movement_type (grant|use|
 * correction). NEGATİF BAKİYE KABUL — hiçbir qty kontrolü yok, use daima uygulanır (teslim edilmiş
 * mal gerçektir); düzeltme yalnız ters hareketle (correction). tenant_id gövdeden alınmaz; tüm
 * cross-tenant referanslar (customer/product/order/reverses) yazımdan önce RLS kapsamında doğrulanır.
 */
class CouponChangeApplier
{
    /**
     * @param  array<string, mixed>  $event
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    public function apply(string $tenantId, array $event): array
    {
        $op = (string) ($event['op'] ?? '');
        if (! in_array($op, ['grant', 'use', 'correction'], true)) {
            throw new InvalidArgumentException("Geçersiz kupon op: {$op}");
        }

        /** @var array<string, mixed> $payload */
        $payload = (array) ($event['payload'] ?? []);
        $id = (string) SyncPayload::req($payload, 'id');
        if (CouponMovement::query()->find($id) !== null) {
            throw new InvalidArgumentException('Bu kupon hareketi zaten var');
        }

        $customerId = (string) SyncPayload::req($payload, 'customer_id'); // kupon müşteriye ait (NOT NULL)
        if (! Customer::query()->whereKey($customerId)->exists()) {
            throw new InvalidArgumentException('customer_id bu bayide bulunamadı');
        }

        $productId = isset($payload['product_id']) ? (string) $payload['product_id'] : null;
        if ($productId !== null && ! Product::query()->whereKey($productId)->exists()) {
            throw new InvalidArgumentException('product_id bu bayide bulunamadı');
        }

        $relatedOrderId = isset($payload['related_order_id']) ? (string) $payload['related_order_id'] : null;
        if ($relatedOrderId !== null && ! Order::query()->whereKey($relatedOrderId)->exists()) {
            throw new InvalidArgumentException('related_order_id bu bayide bulunamadı');
        }

        $reversesMovementId = isset($payload['reverses_movement_id']) ? (string) $payload['reverses_movement_id'] : null;
        if ($reversesMovementId !== null && ! CouponMovement::query()->whereKey($reversesMovementId)->exists()) {
            throw new InvalidArgumentException('reverses_movement_id bu bayide bulunamadı');
        }

        $qtyDelta = (int) SyncPayload::req($payload, 'qty_delta');
        $this->validateSign($op, $qtyDelta);

        $movement = new CouponMovement;
        $movement->forceFill([
            'id' => $id,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'product_id' => $productId,
            'movement_type' => $op,
            'qty_delta' => $qtyDelta,
            'related_order_id' => $relatedOrderId,
            'note' => $payload['note'] ?? null,
            'reverses_movement_id' => $reversesMovementId,
            'occurred_at' => (string) ($event['occurred_at'] ?? ''),
            'device_id' => $event['device_id'] ?? null,
            'client_event_id' => (string) ($event['client_event_id'] ?? ''),
        ])->save();

        $changes = [SyncPayload::change('coupon_movement', $id, 'upsert', $movement)];

        // Bakiye önbelleğini HAREKELERDEN yeniden kur (NEGATİF KABUL). customers.balance_kurus ikizi.
        $balance = $this->recomputeBalance($tenantId, $customerId, $productId);
        $changes[] = SyncPayload::change('coupon_balance', (string) $balance->id, 'upsert', $balance);

        return ['status' => 'applied', 'entity_id' => $id, 'changes' => $changes];
    }

    /**
     * İşaret hareket tipiyle tutarlı olmalı: grant ≥ 0 (adet ekler), use ≤ 0 (adet düşer),
     * correction serbest (ters/telafi imzalı). Bakiyenin eksiye düşmesi ayrı — o REDDEDİLMEZ.
     */
    private function validateSign(string $op, int $qtyDelta): void
    {
        $ok = match ($op) {
            'grant' => $qtyDelta >= 0,
            'use' => $qtyDelta <= 0,
            'correction' => true,
            default => false,
        };
        if (! $ok) {
            throw new InvalidArgumentException("{$op} için qty_delta işareti geçersiz");
        }
    }

    /**
     * (customer_id, product_id) için balance_qty = SUM(qty_delta); önbelleği upsert eder. product_id
     * NULL (genel kupon) NULL-güvenli eşleşir. Satır yoksa yeni uuid id ile kurulur (kararlı kalır).
     */
    private function recomputeBalance(string $tenantId, string $customerId, ?string $productId): CouponBalance
    {
        $sum = (int) $this->scopeCustomerProduct(CouponMovement::query(), $customerId, $productId)
            ->sum('qty_delta');

        /** @var CouponBalance|null $balance */
        $balance = $this->scopeCustomerProduct(CouponBalance::query(), $customerId, $productId)->first();

        if ($balance === null) {
            $balance = new CouponBalance;
            $balance->forceFill([
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'product_id' => $productId,
            ]);
        }
        $balance->balance_qty = $sum;
        $balance->save();

        return $balance;
    }

    /**
     * (customer_id, product_id) filtresi — product_id NULL için whereNull (SQL'de `= NULL` hep false).
     *
     * @param  Builder<CouponMovement>|Builder<CouponBalance>  $query
     * @return Builder<CouponMovement>|Builder<CouponBalance>
     */
    private function scopeCustomerProduct(Builder $query, string $customerId, ?string $productId): Builder
    {
        return $query->where('customer_id', $customerId)
            ->when(
                $productId === null,
                fn (Builder $q) => $q->whereNull('product_id'),
                fn (Builder $q) => $q->where('product_id', $productId),
            );
    }
}
