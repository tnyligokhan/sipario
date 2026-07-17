<?php

namespace App\Support\Sync;

use App\Models\Customer;
use App\Models\Order;
use App\Models\OrderEvent;
use App\Models\OrderLine;
use App\Models\Product;
use App\Models\User;
use Illuminate\Support\Str;
use InvalidArgumentException;

/**
 * Sipariş push olaylarını uygular (olay tabanlı: order_events APPEND + orders.status/total_kurus
 * önbelleğini olaylardan türet). ChangeApplier 'order' entity_type'ını buraya delege eder.
 *
 * Çakışma yok, birleşme var (DECISIONS): olaylar eklenir, önbellek yeniden hesaplanır. tenant_id
 * gövdeden alınmaz; cross-tenant referanslar (customer_id, product_id) yazımdan önce RLS kapsamında
 * doğrulanır (savepoint zehirlenmesini önler).
 */
class OrderChangeApplier
{
    /**
     * @param  array<string, mixed>  $event
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    public function apply(string $tenantId, array $event): array
    {
        $op = (string) ($event['op'] ?? '');
        /** @var array<string, mixed> $payload */
        $payload = (array) ($event['payload'] ?? []);

        return match ($op) {
            'created' => $this->orderCreated($tenantId, $event, $payload),
            'line_added' => $this->orderLineAdded($tenantId, $event, $payload),
            'line_removed' => $this->orderLineRemoved($tenantId, $event, $payload),
            'delivered', 'cancelled', 'payment_set', 'note_set' => $this->orderStatusEvent($tenantId, $op, $event, $payload),
            'assigned', 'unassigned' => $this->orderAssignEvent($tenantId, $op, $event, $payload),
            default => throw new InvalidArgumentException("Geçersiz sipariş op: {$op}"),
        };
    }

    /**
     * @param  array<string, mixed>  $event
     * @param  array<string, mixed>  $payload
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    private function orderCreated(string $tenantId, array $event, array $payload): array
    {
        /** @var array<string, mixed> $o */
        $o = (array) ($payload['order'] ?? throw new InvalidArgumentException('payload.order gerekli'));
        $orderId = (string) SyncPayload::req($o, 'id');
        if (Order::query()->find($orderId) !== null) {
            throw new InvalidArgumentException('Bu sipariş kimliği zaten var');
        }
        $customerId = isset($o['customer_id']) ? (string) $o['customer_id'] : null;
        if ($customerId !== null && ! Customer::query()->whereKey($customerId)->exists()) {
            throw new InvalidArgumentException('customer_id bu bayide bulunamadı');
        }

        $order = new Order;
        $order->forceFill([
            'id' => $orderId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'status' => 'open',
            'total_kurus' => 0,
            'payment_type' => $o['payment_type'] ?? null,
            'note' => $o['note'] ?? null,
            'occurred_at' => (string) ($event['occurred_at'] ?? ''),
            'created_device_id' => $event['device_id'] ?? null,
            'deleted_at' => null,
        ])->save();

        $changes = [];
        /** @var list<array<string, mixed>> $lines */
        $lines = (array) ($payload['lines'] ?? []);
        foreach ($lines as $ln) {
            $line = $this->insertLine($tenantId, $orderId, (array) $ln);
            $changes[] = SyncPayload::change('order_line', $line->id, 'upsert', $line);
        }

        $orderEvent = $this->appendOrderEvent($tenantId, $orderId, 'created', $event, $payload);
        $this->recomputeOrder($order);

        // Sıra önemli: önce sipariş (FK ebeveyni), sonra olay, sonra satırlar.
        array_unshift($changes, SyncPayload::change('order_event', $orderEvent->id, 'upsert', $orderEvent));
        array_unshift($changes, SyncPayload::change('order', $orderId, 'upsert', $order));

        return ['status' => 'applied', 'entity_id' => $orderId, 'changes' => $changes];
    }

    /**
     * @param  array<string, mixed>  $event
     * @param  array<string, mixed>  $payload
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    private function orderLineAdded(string $tenantId, array $event, array $payload): array
    {
        $order = $this->findOrder($payload);
        /** @var array<string, mixed> $ln */
        $ln = (array) ($payload['line'] ?? throw new InvalidArgumentException('payload.line gerekli'));
        $line = $this->insertLine($tenantId, $order->id, $ln);
        $orderEvent = $this->appendOrderEvent($tenantId, $order->id, 'line_added', $event, $payload);
        $this->recomputeOrder($order);

        return ['status' => 'applied', 'entity_id' => $order->id, 'changes' => [
            SyncPayload::change('order', $order->id, 'upsert', $order),
            SyncPayload::change('order_event', $orderEvent->id, 'upsert', $orderEvent),
            SyncPayload::change('order_line', $line->id, 'upsert', $line),
        ]];
    }

    /**
     * @param  array<string, mixed>  $event
     * @param  array<string, mixed>  $payload
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    private function orderLineRemoved(string $tenantId, array $event, array $payload): array
    {
        $order = $this->findOrder($payload);
        $lineId = (string) SyncPayload::req($payload, 'line_id');
        /** @var OrderLine|null $line */
        $line = OrderLine::query()->where('order_id', $order->id)->find($lineId);
        if ($line === null) {
            throw new InvalidArgumentException('Satır bulunamadı');
        }
        $occurredAt = (string) ($event['occurred_at'] ?? '');
        $line->forceFill(['deleted_at' => $occurredAt])->save();
        $orderEvent = $this->appendOrderEvent($tenantId, $order->id, 'line_removed', $event, $payload);
        $this->recomputeOrder($order);

        return ['status' => 'applied', 'entity_id' => $order->id, 'changes' => [
            SyncPayload::change('order', $order->id, 'upsert', $order),
            SyncPayload::change('order_event', $orderEvent->id, 'upsert', $orderEvent),
            SyncPayload::change('order_line', $line->id, 'delete', $line),
        ]];
    }

    /**
     * @param  array<string, mixed>  $event
     * @param  array<string, mixed>  $payload
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    private function orderStatusEvent(string $tenantId, string $op, array $event, array $payload): array
    {
        $order = $this->findOrder($payload);

        if ($op === 'payment_set' || ($op === 'delivered' && isset($payload['payment_type']))) {
            $order->payment_type = (string) SyncPayload::req($payload, 'payment_type');
        }
        if ($op === 'note_set') {
            $order->note = isset($payload['note']) ? (string) $payload['note'] : null;
        }

        $orderEvent = $this->appendOrderEvent($tenantId, $order->id, $op, $event, $payload);
        $this->recomputeOrder($order); // status/total olaylardan türer + $order'ı kaydeder

        return ['status' => 'applied', 'entity_id' => $order->id, 'changes' => [
            SyncPayload::change('order', $order->id, 'upsert', $order),
            SyncPayload::change('order_event', $orderEvent->id, 'upsert', $orderEvent),
        ]];
    }

    /**
     * Sipariş ATAMA olayı (FAZ 4, olay-kaynaklı). assigned: assigned_user_id yazımdan ÖNCE
     * RLS-kapsamlı User::exists() ile doğrulanır (customer/product referans deseni; başka bayinin
     * kullanıcısına atama InvalidArgument + savepoint ile reddedilir, kırmızı çizgi #1). unassigned:
     * doğrulama gerekmez. orders.assigned_user_id ÖNBELLEĞİ recomputeOrder'da en son olaydan türer.
     *
     * @param  array<string, mixed>  $event
     * @param  array<string, mixed>  $payload
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    private function orderAssignEvent(string $tenantId, string $op, array $event, array $payload): array
    {
        $order = $this->findOrder($payload);

        if ($op === 'assigned') {
            $userId = (string) SyncPayload::req($payload, 'assigned_user_id');
            if (! User::query()->whereKey($userId)->exists()) {
                throw new InvalidArgumentException('assigned_user_id bu bayide bulunamadı');
            }
        }

        $orderEvent = $this->appendOrderEvent($tenantId, $order->id, $op, $event, $payload);
        $this->recomputeOrder($order); // assigned_user_id önbelleği olaylardan türer + $order'ı kaydeder

        return ['status' => 'applied', 'entity_id' => $order->id, 'changes' => [
            SyncPayload::change('order', $order->id, 'upsert', $order),
            SyncPayload::change('order_event', $orderEvent->id, 'upsert', $orderEvent),
        ]];
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    private function findOrder(array $payload): Order
    {
        $orderId = (string) SyncPayload::req($payload, 'order_id');
        /** @var Order|null $order */
        $order = Order::query()->find($orderId);

        return $order ?? throw new InvalidArgumentException('Sipariş bulunamadı');
    }

    /**
     * @param  array<string, mixed>  $ln
     */
    private function insertLine(string $tenantId, string $orderId, array $ln): OrderLine
    {
        $qty = (int) SyncPayload::req($ln, 'qty');
        $price = (int) SyncPayload::req($ln, 'unit_price_kurus');

        // Cross-tenant referans poison'unu ÖNLE: product_id verilmişse RLS kapsamında doğrula
        // (customer_id ile simetrik). Ürün silinse/pasiflense de satır bozulmaz — ama BAŞKA bayinin
        // ürününe bağlanamaz. Serbest satırda product_id null'dur, kontrol atlanır.
        $productId = isset($ln['product_id']) ? (string) $ln['product_id'] : null;
        if ($productId !== null && ! Product::query()->whereKey($productId)->exists()) {
            throw new InvalidArgumentException('product_id bu bayide bulunamadı');
        }

        $line = new OrderLine;
        $line->forceFill([
            'id' => (string) ($ln['id'] ?? Str::uuid7()),
            'tenant_id' => $tenantId,
            'order_id' => $orderId,
            'product_id' => $productId,
            'product_name' => (string) SyncPayload::req($ln, 'product_name'),
            'unit_price_kurus' => $price,
            'qty' => $qty,
            'line_total_kurus' => $price * $qty,
            'deleted_at' => null,
        ])->save();

        return $line;
    }

    /**
     * @param  array<string, mixed>  $event
     * @param  array<string, mixed>  $payload
     */
    private function appendOrderEvent(string $tenantId, string $orderId, string $type, array $event, array $payload): OrderEvent
    {
        $orderEvent = new OrderEvent;
        $orderEvent->forceFill([
            'tenant_id' => $tenantId,
            'order_id' => $orderId,
            'event_type' => $type,
            'payload' => $payload,
            'client_event_id' => (string) ($event['client_event_id'] ?? ''),
            'occurred_at' => (string) ($event['occurred_at'] ?? ''),
            'device_id' => $event['device_id'] ?? null,
        ])->save();

        return $orderEvent;
    }

    private function recomputeOrder(Order $order): void
    {
        $hasCancelled = OrderEvent::query()->where('order_id', $order->id)->where('event_type', 'cancelled')->exists();
        $hasDelivered = OrderEvent::query()->where('order_id', $order->id)->where('event_type', 'delivered')->exists();

        $order->status = $hasCancelled ? 'cancelled' : ($hasDelivered ? 'delivered' : 'open');
        $order->total_kurus = (int) OrderLine::query()
            ->where('order_id', $order->id)->whereNull('deleted_at')->sum('line_total_kurus');
        $order->assigned_user_id = $this->deriveAssignedUserId($order->id);
        $order->save();
    }

    /**
     * assigned_user_id önbelleğini olaylardan türet (status deseni): en son assigned/unassigned
     * olayına bak; assigned ise payload'daki kullanıcı, unassigned ise null. Sıra SADECE (occurred_at
     * DESC, id DESC) — id uuid7 benzersiz+zaman-sıralı olduğundan occurred_at saniye hassasiyetinde
     * eşitlense bile TAM determinizm sağlar (eşitlikte Postgres keyfi sıra döndürüyordu — flaky).
     * created_at BİLİNÇLİ DIŞARIDA: sunucuya özel (varış anı), istemcide karşılığı YOK; ortada olsaydı
     * iki cihazın id sırasıyla çelişip sunucu/istemci FARKLI kurye türetirdi (kalıcı ıraksama). İki taraf
     * yalnız ORTAK anahtarı (occurred_at, id) kullanır → istemci _recompute ile BİREBİR simetrik.
     * DECISIONS LWW "device_id ile deterministik ayrım" felsefesiyle aynı çizgi.
     */
    private function deriveAssignedUserId(string $orderId): ?string
    {
        /** @var OrderEvent|null $latest */
        $latest = OrderEvent::query()
            ->where('order_id', $orderId)
            ->whereIn('event_type', ['assigned', 'unassigned'])
            ->orderByDesc('occurred_at')->orderByDesc('id')
            ->first();

        if ($latest === null || $latest->event_type === 'unassigned') {
            return null;
        }

        $payload = $latest->payload ?? [];
        $userId = $payload['assigned_user_id'] ?? null;

        return $userId !== null ? (string) $userId : null;
    }
}
