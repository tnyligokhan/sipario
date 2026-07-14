<?php

namespace Tests\Feature\Api\Concerns;

use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;

/**
 * Senkron testleri için olay üreteçleri + push/pull yardımcıları. TenantIsolationTest ve SyncTest
 * ortak kullanır. Her olay istemci üretimli UUIDv7 kimlik + client_event_id taşır (offline-first).
 */
trait BuildsSyncEvents
{
    /**
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function customerUpsert(array $payload = [], array $meta = []): array
    {
        return $this->event('customer', 'upsert', array_merge([
            'id' => (string) Str::uuid7(),
            'name' => 'Test Müşteri',
            'note' => null,
        ], $payload), $meta);
    }

    /**
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function customerDelete(string $id, array $meta = []): array
    {
        return $this->event('customer', 'delete', ['id' => $id], $meta);
    }

    /**
     * @param  list<array<string, mixed>>  $lines
     * @param  array<string, mixed>  $orderFields
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function orderCreated(array $lines, array $orderFields = [], array $meta = []): array
    {
        return $this->event('order', 'created', [
            'order' => array_merge(['id' => (string) Str::uuid7()], $orderFields),
            'lines' => $lines,
        ], $meta);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function orderEvent(string $op, array $payload, array $meta = []): array
    {
        return $this->event('order', $op, $payload, $meta);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function ledgerEntry(array $payload = [], array $meta = []): array
    {
        return $this->event('ledger', 'entry', array_merge([
            'id' => (string) Str::uuid7(),
            'entry_type' => 'debit',
            'amount_kurus' => 9000,
        ], $payload), $meta);
    }

    /**
     * Kupon hareketi (Faz 3): op = grant|use|correction, qty_delta İMZALI. customer_id ZORUNLU.
     *
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function couponMovement(string $op, array $payload = [], array $meta = []): array
    {
        return $this->event('coupon', $op, array_merge([
            'id' => (string) Str::uuid7(),
            'qty_delta' => $op === 'use' ? -1 : 1,
        ], $payload), $meta);
    }

    /**
     * @param  array<string, mixed>  $line
     * @return array<string, mixed>
     */
    protected function line(array $line = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid7(),
            'product_id' => null,
            'product_name' => '19L Damacana',
            'unit_price_kurus' => 4500,
            'qty' => 2,
        ], $line);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function event(string $entityType, string $op, array $payload, array $meta = []): array
    {
        return [
            'client_event_id' => $meta['client_event_id'] ?? (string) Str::uuid7(),
            'entity_type' => $entityType,
            'op' => $op,
            'occurred_at' => $meta['occurred_at'] ?? now()->toIso8601String(),
            'device_id' => array_key_exists('device_id', $meta) ? $meta['device_id'] : (string) Str::uuid7(),
            'payload' => $payload,
        ];
    }

    /**
     * @param  list<array<string, mixed>>  $events
     */
    protected function pushEvents(string $token, array $events): TestResponse
    {
        return $this->asToken($token)->postJson('/api/v1/sync/push', ['events' => $events]);
    }

    protected function pullSince(string $token, int $since = 0, int $limit = 500): TestResponse
    {
        return $this->asToken($token)->getJson("/api/v1/sync/pull?since={$since}&limit={$limit}");
    }
}
