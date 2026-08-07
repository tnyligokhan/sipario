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
     * Kasa devri (Faz 4): op = handover. from_user_id ZORUNLU. counted/expected/diff kuruş.
     *
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function cashHandover(array $payload = [], array $meta = []): array
    {
        return $this->event('cash_handover', 'handover', array_merge([
            'id' => (string) Str::uuid7(),
            'counted_cash_kurus' => 0,
            'expected_cash_kurus' => 0,
            'diff_kurus' => 0,
        ], $payload), $meta);
    }

    /**
     * İşletme profili (tasarım boşluğu): payload'da id YOKTUR — anahtar oturumdaki tenant'tır
     * (migration 601: PK = tenant_id). Çevrimdışı iki cihaz aynı satırda LWW ile buluşur.
     *
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function tenantSettingsUpsert(array $payload = [], array $meta = []): array
    {
        return $this->event('tenant_settings', 'upsert', array_merge([
            'business_name' => 'Test Su Bayii',
        ], $payload), $meta);
    }

    /**
     * Muaf telefon (arayan tanıma kartı gösterilmez). LWW + tombstone varlığı.
     *
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function exemptNumberUpsert(array $payload = [], array $meta = []): array
    {
        return $this->event('exempt_number', 'upsert', array_merge([
            'id' => (string) Str::uuid7(),
            'phone_e164' => '+905321112233',
            'label' => 'Kurye',
        ], $payload), $meta);
    }

    /**
     * Çağrı günlüğü satırı. direction: incoming|missed|outgoing.
     *
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function callLogUpsert(array $payload = [], array $meta = []): array
    {
        return $this->event('call_log', 'upsert', array_merge([
            'id' => (string) Str::uuid7(),
            'phone_e164' => '+905324152290',
            'direction' => 'incoming',
        ], $payload), $meta);
    }

    /**
     * Gün sonu kapanış arşivi (op = closing, APPEND). scope=day → user_id YOK;
     * scope=courier → user_id ZORUNLU.
     *
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function dayClosing(array $payload = [], array $meta = []): array
    {
        return $this->event('day_closing', 'closing', array_merge([
            'id' => (string) Str::uuid7(),
            'scope' => 'day',
        ], $payload), $meta);
    }

    /**
     * Kullanıcı profili düzenleme (ad/telefon/aktiflik). Kullanıcı OLUŞTURULAMAZ.
     *
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    protected function userProfileUpsert(array $payload, array $meta = []): array
    {
        return $this->event('user_profile', 'upsert', $payload, $meta);
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
