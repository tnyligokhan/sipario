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
            'sort_set' => $this->orderSortEvent($tenantId, $event, $payload),
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
            'occurred_at' => SyncPayload::zaman((string) ($event['occurred_at'] ?? '')),
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
        $occurredAt = (string) SyncPayload::zaman((string) ($event['occurred_at'] ?? ''));
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
     * Sipariş ELLE SIRALAMA olayı (tasarım: s-siparisler "Elle sırala / sürükle-bırak" rota sırası).
     * assigned_user_id deseninin birebir ikizi: orders.sort_index bir ÖNBELLEKtir, kaynağı en son
     * `sort_set` olayıdır — böylece iki cihaz aynı olay kümesinden AYNI sırayı türetir. Sıralama
     * para değildir; çakışmada son yazan kazanır (olay sırası (occurred_at, id) ile deterministik).
     *
     * @param  array<string, mixed>  $event
     * @param  array<string, mixed>  $payload
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    private function orderSortEvent(string $tenantId, array $event, array $payload): array
    {
        $order = $this->findOrder($payload);
        SyncPayload::req($payload, 'sort_index'); // yoksa istemci-kaynaklı geçersizlik

        $orderEvent = $this->appendOrderEvent($tenantId, $order->id, 'sort_set', $event, $payload);
        $this->recomputeOrder($order); // sort_index önbelleği olaylardan türer + $order'ı kaydeder

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
            // Birim satırda saklanır (unit_price/product_name deseni: siparişin çekildiği andaki gerçek).
            'unit' => $ln['unit'] ?? null,
            // Satır notu (kullanıcı isteği 2026-08-11): "buzlu olsun", "ayrı poşete". `unit` ile
            // AYNI desen — satırın kendi gerçeği satırda durur. `orders.note`tan ayrıdır.
            'note' => self::satirNotu($ln['note'] ?? null),
            // SEÇİLEN SEÇENEKLER (kullanıcı isteği 2026-08-18) — "soğansız, ekstra peynirli".
            //
            // Notun YANINDA durur, yerine değil: not metni ekranların okuduğu hâl, bu alan
            // makinenin okuduğu hâl. İkisi aynı gerçeğin iki okuyucusuna bakar ve istemci ikisini
            // birlikte yazar (`LineInput.satirNotu`). Yalnız biri saklansaydı ya eski istemciler
            // seçimi hiç göremezdi (yalnız yapılandırılmış hâl) ya da "aynı seçimle tekrarla"
            // gibi işler metin ayrıştırmak zorunda kalırdı (yalnız not).
            //
            // ⚠️ FİYAT BURADAN TÜRETİLMEZ: `unit_price_kurus` istemcide ekstralarla birlikte
            // hesaplanıp gönderilir ve satır toplamı ondan çıkar. Sunucunun ekstraları yeniden
            // toplaması, aynı formülün ikinci bir kopyası olurdu ve ikisi bir gün ayrışırdı.
            'options' => UrunSecenekleri::secim($ln['options'] ?? null),
            // "Serbest satır" AÇIK bayrakla işaretlenir; product_id IS NULL'a bel bağlamak kırılgan
            // olurdu (silinmiş ürünün satırı da null olabilir) — tasarım bu ikisini ayrı gösteriyor.
            'is_custom' => (bool) ($ln['is_custom'] ?? false),
            'qty' => $qty,
            'line_total_kurus' => $price * $qty,
            'deleted_at' => null,
        ])->save();

        return $line;
    }

    /**
     * Satır notu kapısı — 500 karakter, KIRPMA YOK (`iban`/`reminder_template` deseniyle aynı çizgi).
     *
     * NEDEN UYGULAYICIDA: kolon `varchar(500)`dür ve sınıra dayanan bir yazım 22001 üretir. 22001
     * `CLIENT_DATA_SQLSTATES` beyaz listesinde olduğu için parti bugün ölmez ama olayı 'invalid_data'
     * ile reddeder — yani bayi "kayıt reddedildi (geçersiz veri)" görür ve NEDENİNİ öğrenemez.
     * Buradan fırlayan istisna savepoint ile yalnız BU olayı 'rejected' işaretler ve nedeni
     * ('domain_rejected' + metin) taşır; partinin geri kalanı yazılır.
     *
     * KIRPMA REDDİN YERİNE GEÇEMEZ: yarım kalmış bir not kuryeye YANLIŞ talimat verir ("buzlu
     * olmasın" → "buzlu ol"). Sessiz "en iyi çaba" bu alanda kabul edilemez.
     *
     * Boş/yalnız-boşluk metin `null`dur: "not yok" tek bir hâl olmalı, yoksa istemcideki "not var
     * mı" kapısı iki dala ayrılır.
     */
    private static function satirNotu(mixed $ham): ?string
    {
        if ($ham === null) {
            return null;
        }
        // SKALER OLMAYAN DEĞER ÖNDEN REDDEDİLİR: `(string) $nesne` __toString'i olmayan bir nesnede
        // ÖLÜMCÜL Error atar ve Error bir Exception DEĞİLDİR — SyncService'in InvalidArgument/
        // QueryException kapanları onu yakalayamaz, parti 500'e düşer ve kuyruk kilitlenir
        // (zehirli hap). Dizi ise sessizce "Array" metnine dönerdi, ki bu daha da kötü: bayi
        // notunun yerinde "Array" yazdığını ancak kurye kapıda okuduğunda öğrenir.
        if (! is_scalar($ham)) {
            throw new InvalidArgumentException('satır notu metin olmalı');
        }
        $s = trim((string) $ham);
        if ($s === '') {
            return null;
        }
        if (mb_strlen($s) > 500) {
            throw new InvalidArgumentException('satır notu 500 karakterden uzun olamaz');
        }

        return $s;
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
            'occurred_at' => SyncPayload::zaman((string) ($event['occurred_at'] ?? '')),
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
        $order->sort_index = $this->deriveSortIndex($order->id);
        $order->save();
    }

    /**
     * sort_index önbelleğini olaylardan türet (assigned_user_id deseni; aynı (occurred_at DESC,
     * id DESC) ORTAK anahtarı → istemci/sunucu simetrisi, ıraksama yok).
     */
    private function deriveSortIndex(string $orderId): ?int
    {
        /** @var OrderEvent|null $latest */
        $latest = OrderEvent::query()
            ->where('order_id', $orderId)
            ->where('event_type', 'sort_set')
            ->orderByDesc('occurred_at')->orderByDesc('id')
            ->first();

        if ($latest === null) {
            return null;
        }

        $value = ($latest->payload ?? [])['sort_index'] ?? null;

        return $value !== null ? (int) $value : null;
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
