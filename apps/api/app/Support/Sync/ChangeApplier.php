<?php

namespace App\Support\Sync;

use App\Models\Customer;
use App\Models\CustomerAddress;
use App\Models\CustomerPhone;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\Product;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;
use InvalidArgumentException;

/**
 * Bir push olayını iş verisine uygular ve senkron günlüğüne (sync_changes) yazılacak "değişiklik
 * betimleyicilerini" döner. SyncService bu betimleyicilere seq atar. Bu sınıf seq/idempotency
 * bilmez — yalnız DOMAIN mutasyonu ve çakışma çözümüdür (LWW / append).
 *
 * Çakışma kuralları (DECISIONS senkron):
 *  - Varlık alanları (müşteri/telefon/adres/ürün): SON YAZAN KAZANIR. occurred_at daha yeni olan
 *    uygulanır; eşitlikte device_id ile deterministik ayrım. Eski olay 'stale' döner (uygulanmaz).
 *  - Defter/sipariş olayları: APPEND — çakışma yok, birleşme var. order_events/ledger_entries eklenir.
 *
 * Sipariş olayları OrderChangeApplier'a delege edilir (500 satır sınırı). İstemci-kaynaklı
 * geçersizlikler (bilinmeyen tip, cross-tenant referans, eksik alan) InvalidArgument fırlatır;
 * SyncService bunu olay bazında savepoint ile geri alıp 'rejected' işaretler (parti bozulmaz).
 *
 * tenant_id GÖVDEDEN ALINMAZ; her yazımda oturumdaki $tenantId kullanılır (RLS WITH CHECK de zorlar).
 */
class ChangeApplier
{
    /** LWW ile yönetilen basit varlıklar (upsert/delete). */
    private const SIMPLE_ENTITIES = ['customer', 'customer_phone', 'customer_address', 'product'];

    /**
     * @param  array<string, mixed>  $event
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    public function apply(string $tenantId, array $event): array
    {
        $type = (string) ($event['entity_type'] ?? '');

        if (in_array($type, self::SIMPLE_ENTITIES, true)) {
            return $this->applySimpleEntity($tenantId, $type, $event);
        }

        return match ($type) {
            'order' => (new OrderChangeApplier)->apply($tenantId, $event),
            'ledger' => $this->applyLedger($tenantId, $event),
            default => throw new InvalidArgumentException("Bilinmeyen entity_type: {$type}"),
        };
    }

    // ----------------------------------------------------------------------------------
    // Basit varlıklar — LWW upsert / delete (tombstone)
    // ----------------------------------------------------------------------------------

    /**
     * @param  array<string, mixed>  $event
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    private function applySimpleEntity(string $tenantId, string $type, array $event): array
    {
        $op = (string) ($event['op'] ?? '');
        /** @var array<string, mixed> $payload */
        $payload = (array) ($event['payload'] ?? []);
        $occurredAt = (string) ($event['occurred_at'] ?? '');
        $deviceId = $event['device_id'] ?? null;

        $id = (string) ($payload['id'] ?? throw new InvalidArgumentException('payload.id gerekli'));
        $class = $this->simpleModelClass($type);
        /** @var Model|null $existing */
        $existing = $class::query()->find($id);

        if ($op === 'delete') {
            if ($existing === null) {
                return ['status' => 'noop', 'entity_id' => $id, 'changes' => []];
            }
            if (! $this->lwwWins($existing, $occurredAt, $deviceId)) {
                return ['status' => 'stale', 'entity_id' => $id, 'changes' => []];
            }
            $existing->forceFill([
                'deleted_at' => $occurredAt,
                'updated_occurred_at' => $occurredAt,
                'updated_device_id' => $deviceId,
            ])->save();

            return ['status' => 'applied', 'entity_id' => $id,
                'changes' => [SyncPayload::change($type, $id, 'delete', $existing)]];
        }

        if ($op !== 'upsert') {
            throw new InvalidArgumentException("{$type} için geçersiz op: {$op}");
        }

        $this->validateEntityRefs($type, $payload);
        $cols = $this->simpleColumns($type, $payload);

        if ($existing !== null && ! $this->lwwWins($existing, $occurredAt, $deviceId)) {
            return ['status' => 'stale', 'entity_id' => $id, 'changes' => []];
        }

        /** @var Model $model */
        $model = $existing ?? new $class;
        if ($existing === null) {
            $model->forceFill(['id' => $id, 'tenant_id' => $tenantId]);
        }
        $model->forceFill($cols + [
            'updated_occurred_at' => $occurredAt,
            'updated_device_id' => $deviceId,
            'deleted_at' => null, // upsert bir tombstone'u dirilttir
        ])->save();

        return ['status' => 'applied', 'entity_id' => $id,
            'changes' => [SyncPayload::change($type, $id, 'upsert', $model)]];
    }

    /** @return class-string<Model> */
    private function simpleModelClass(string $type): string
    {
        return match ($type) {
            'customer' => Customer::class,
            'customer_phone' => CustomerPhone::class,
            'customer_address' => CustomerAddress::class,
            'product' => Product::class,
            default => throw new InvalidArgumentException("Bilinmeyen varlık: {$type}"),
        };
    }

    /**
     * İstemciden yazılabilir iş kolonları. NOT: customers.balance_kurus BURADA YOK — o defterden
     * türeyen önbellektir (DECISIONS), istemci ezemez; ledger olayında sunucu tazeler.
     *
     * @param  array<string, mixed>  $p
     * @return array<string, mixed>
     */
    private function simpleColumns(string $type, array $p): array
    {
        return match ($type) {
            'customer' => [
                'name' => SyncPayload::req($p, 'name'),
                'note' => $p['note'] ?? null,
            ],
            'customer_phone' => [
                'customer_id' => SyncPayload::req($p, 'customer_id'),
                'phone_e164' => SyncPayload::req($p, 'phone_e164'),
                'phone_last10' => (string) ($p['phone_last10'] ?? self::last10((string) $p['phone_e164'])),
                'label' => $p['label'] ?? null,
                'is_primary' => (bool) ($p['is_primary'] ?? false),
            ],
            'customer_address' => [
                'customer_id' => SyncPayload::req($p, 'customer_id'),
                'label' => $p['label'] ?? null,
                'address_text' => SyncPayload::req($p, 'address_text'),
                'lat' => isset($p['lat']) ? (float) $p['lat'] : null,
                'lng' => isset($p['lng']) ? (float) $p['lng'] : null,
                'is_primary' => (bool) ($p['is_primary'] ?? false),
            ],
            'product' => [
                'name' => SyncPayload::req($p, 'name'),
                'unit_price_kurus' => (int) SyncPayload::req($p, 'unit_price_kurus'),
                'unit' => (string) ($p['unit'] ?? 'adet'),
                'is_active' => (bool) ($p['is_active'] ?? true),
            ],
            default => throw new InvalidArgumentException("Bilinmeyen varlık: {$type}"),
        };
    }

    /**
     * Cross-tenant referans poison'unu ÖNLE: telefon/adres customer_id'sini yazımdan ÖNCE RLS
     * kapsamında doğrula (yoksa FK ihlali transaction'ı zehirlerdi; savepoint yerine önden reddet).
     *
     * @param  array<string, mixed>  $payload
     */
    private function validateEntityRefs(string $type, array $payload): void
    {
        if (in_array($type, ['customer_phone', 'customer_address'], true)) {
            $cid = (string) SyncPayload::req($payload, 'customer_id');
            if (! Customer::query()->whereKey($cid)->exists()) {
                throw new InvalidArgumentException('customer_id bu bayide bulunamadı');
            }
        }
    }

    // ----------------------------------------------------------------------------------
    // Defter — append-only (FAZ 2: minimal kabul; iş akışları FAZ 3)
    // ----------------------------------------------------------------------------------

    /**
     * @param  array<string, mixed>  $event
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    private function applyLedger(string $tenantId, array $event): array
    {
        /** @var array<string, mixed> $payload */
        $payload = (array) ($event['payload'] ?? []);
        $id = (string) SyncPayload::req($payload, 'id');
        if (LedgerEntry::query()->find($id) !== null) {
            throw new InvalidArgumentException('Bu defter kaydı zaten var');
        }
        $customerId = isset($payload['customer_id']) ? (string) $payload['customer_id'] : null;
        if ($customerId !== null && ! Customer::query()->whereKey($customerId)->exists()) {
            throw new InvalidArgumentException('customer_id bu bayide bulunamadı');
        }

        // related_order_id de RLS kapsamında doğrulanır (customer_id ile simetrik) — başka bayinin
        // siparişine defter kaydı bağlanamaz. Verilmemişse (null) kontrol atlanır.
        $relatedOrderId = isset($payload['related_order_id']) ? (string) $payload['related_order_id'] : null;
        if ($relatedOrderId !== null && ! Order::query()->whereKey($relatedOrderId)->exists()) {
            throw new InvalidArgumentException('related_order_id bu bayide bulunamadı');
        }

        $entry = new LedgerEntry;
        $entry->forceFill([
            'id' => $id,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'entry_type' => (string) SyncPayload::req($payload, 'entry_type'),
            'amount_kurus' => (int) SyncPayload::req($payload, 'amount_kurus'),
            'related_order_id' => $relatedOrderId,
            'note' => $payload['note'] ?? null,
            'occurred_at' => (string) ($event['occurred_at'] ?? ''),
            'device_id' => $event['device_id'] ?? null,
            'client_event_id' => (string) ($event['client_event_id'] ?? ''),
        ])->save();

        $changes = [SyncPayload::change('ledger_entry', $id, 'upsert', $entry)];

        // Bakiye önbelleğini DEFTERDEN yeniden kur (DECISIONS: önbellek bozulursa defterden kurulur).
        if ($customerId !== null) {
            /** @var Customer $customer */
            $customer = Customer::query()->findOrFail($customerId);
            $customer->balance_kurus = (int) LedgerEntry::query()
                ->where('customer_id', $customerId)->sum('amount_kurus');
            $customer->save();
            $changes[] = SyncPayload::change('customer', $customerId, 'upsert', $customer);
        }

        return ['status' => 'applied', 'entity_id' => $id, 'changes' => $changes];
    }

    // ----------------------------------------------------------------------------------
    // Ortak yardımcılar
    // ----------------------------------------------------------------------------------

    /**
     * Son yazan kazanır: gelen occurred_at daha yeni mi? Eşitse device_id ile deterministik ayrım.
     */
    private function lwwWins(Model $existing, string $occurredAt, ?string $deviceId): bool
    {
        $incoming = Carbon::parse($occurredAt);
        /** @var Carbon $current */
        $current = $existing->getAttribute('updated_occurred_at');

        if (! $incoming->equalTo($current)) {
            return $incoming->greaterThan($current);
        }

        return (string) $deviceId > (string) $existing->getAttribute('updated_device_id');
    }

    /** Son 10 hane (arayan tanıma eşleşme anahtarı) — istemci göndermezse türet. */
    private static function last10(string $raw): string
    {
        $digits = preg_replace('/\D/', '', $raw) ?? '';

        return strlen($digits) >= 10 ? substr($digits, -10) : $digits;
    }
}
