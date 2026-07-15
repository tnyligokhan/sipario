<?php

namespace App\Support\Sync;

use App\Models\CashHandover;
use App\Models\CouponBalance;
use App\Models\CouponMovement;
use App\Models\Customer;
use App\Models\CustomerAddress;
use App\Models\CustomerPhone;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\OrderEvent;
use App\Models\OrderLine;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

/**
 * Senkron çekirdeği (DECISIONS senkron). İki yüzey: push (tek yazma) ve pull (tek okuma).
 *
 * PUSH: tenant_sync_state satırını FOR UPDATE ile kilitler (seq atama sırası = commit sırası →
 * kayıp-güncelleme sınıfı kapanır, korku #2). Her olay için (tenant_id, client_event_id) idempotency
 * kontrolü; yeni olay ChangeApplier'a verilir, ürettiği her değişikliğe monoton seq atanıp sync_changes'e
 * yazılır. Olay bazında savepoint: bir olay istemci-kaynaklı hatayla reddedilirse yalnız o geri alınır,
 * parti bozulmaz (Postgres'te hatalı statement transaction'ı zehirler; savepoint bunu izole eder).
 *
 * PULL: since=0 tam snapshot (canlı satırlar), since>0 sync_changes'ten seq sıralı delta. Redelivery
 * zararsızdır (istemci upsert idempotent) — snapshot/delta sınırındaki olası tekrar veri kaybettirmez.
 */
class SyncService
{
    /** Bir push isteğinde işlenecek azami olay (DoS + transaction süresi sınırı). */
    public const MAX_EVENTS = 500;

    /** İstemci-kaynaklı (reddedilebilir) SQL durumları: geçersiz uuid, not-null, FK, unique, check. */
    private const CLIENT_DATA_SQLSTATES = ['22P02', '23502', '23503', '23505', '23514'];

    /**
     * @param  list<array<string, mixed>>  $events
     * @return array{results: list<array<string, mixed>>, current_seq: int}
     */
    public function push(User $user, array $events): array
    {
        $tenantId = (string) $user->tenant_id;
        $applier = new ChangeApplier;

        return DB::transaction(function () use ($tenantId, $events, $applier) {
            // Seq sayacını kilitle (satır yoksa oluştur). Kilit outer transaction commit'ine kadar tutulur.
            DB::insert(
                'INSERT INTO tenant_sync_state (tenant_id, last_seq) VALUES (?, 0) ON CONFLICT (tenant_id) DO NOTHING',
                [$tenantId]
            );
            $lastSeq = (int) (DB::table('tenant_sync_state')
                ->where('tenant_id', $tenantId)->lockForUpdate()->value('last_seq') ?? 0);

            $results = [];
            foreach ($events as $event) {
                $clientEventId = (string) ($event['client_event_id'] ?? '');

                $processed = DB::selectOne(
                    'SELECT entity_id, result_seq FROM processed_events WHERE tenant_id = ? AND client_event_id = ?',
                    [$tenantId, $clientEventId]
                );
                if ($processed !== null) {
                    $results[] = [
                        'client_event_id' => $clientEventId,
                        'status' => 'duplicate',
                        'entity_id' => $processed->entity_id,
                        'server_seq' => $processed->result_seq !== null ? (int) $processed->result_seq : null,
                    ];

                    continue;
                }

                try {
                    [$lastSeq, $result] = $this->applyOne($tenantId, $event, $lastSeq, $applier);
                    $results[] = $result;
                } catch (InvalidArgumentException $e) {
                    $results[] = $this->rejected($clientEventId, $e->getMessage());
                } catch (QueryException $e) {
                    if (! in_array((string) $e->getCode(), self::CLIENT_DATA_SQLSTATES, true)) {
                        throw $e; // beklenmedik altyapı hatası → partiyi geri al
                    }
                    $results[] = $this->rejected($clientEventId, 'Kayıt reddedildi (geçersiz veri).');
                }
            }

            DB::update(
                'UPDATE tenant_sync_state SET last_seq = ?, updated_at = now() WHERE tenant_id = ?',
                [$lastSeq, $tenantId]
            );

            return ['results' => $results, 'current_seq' => $lastSeq];
        });
    }

    /**
     * Tek olayı savepoint içinde uygular; ürettiği değişikliklere seq atayıp günlüğe yazar.
     * Hata olursa savepoint geri alınır (seq ilerlemez), exception dışarı fırlar.
     *
     * @param  array<string, mixed>  $event
     * @return array{0: int, 1: array<string, mixed>}
     */
    private function applyOne(string $tenantId, array $event, int $lastSeq, ChangeApplier $applier): array
    {
        return DB::transaction(function () use ($tenantId, $event, $lastSeq, $applier) {
            $applied = $applier->apply($tenantId, $event);

            $occurredAt = $event['occurred_at'] ?? null;
            $deviceId = $event['device_id'] ?? null;
            $seqForEvent = null;

            foreach ($applied['changes'] as $change) {
                $lastSeq++;
                DB::insert(
                    'INSERT INTO sync_changes
                        (tenant_id, seq, entity_type, entity_id, op, payload, occurred_at, device_id)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                    [
                        $tenantId, $lastSeq, $change['entity_type'], $change['entity_id'], $change['op'],
                        json_encode($change['payload'], JSON_UNESCAPED_UNICODE), $occurredAt, $deviceId,
                    ]
                );
                $seqForEvent ??= $lastSeq;
            }

            // Idempotency defteri: applied/stale/noop hepsinde yazılır → retry çift-uygulamaz.
            DB::insert(
                'INSERT INTO processed_events (tenant_id, client_event_id, entity_type, entity_id, result_seq)
                 VALUES (?, ?, ?, ?, ?)',
                [
                    $tenantId, (string) ($event['client_event_id'] ?? ''),
                    (string) ($event['entity_type'] ?? ''), $applied['entity_id'], $seqForEvent,
                ]
            );

            return [$lastSeq, [
                'client_event_id' => (string) ($event['client_event_id'] ?? ''),
                'status' => $applied['status'],
                'entity_id' => $applied['entity_id'],
                'server_seq' => $seqForEvent,
            ]];
        });
    }

    /**
     * @return array{mode: string, cursor: int, has_more: bool, current_seq: int, changes?: list<array<string, mixed>>, entities?: array<string, mixed>}
     */
    public function pull(User $user, int $since, int $limit): array
    {
        $tenantId = (string) $user->tenant_id;
        $currentSeq = (int) (DB::table('tenant_sync_state')
            ->where('tenant_id', $tenantId)->value('last_seq') ?? 0);

        if ($since <= 0) {
            return $this->snapshot($currentSeq);
        }

        $rows = DB::select(
            'SELECT seq, entity_type, entity_id, op, payload, occurred_at
             FROM sync_changes WHERE tenant_id = ? AND seq > ? ORDER BY seq ASC LIMIT ?',
            [$tenantId, $since, $limit]
        );

        $changes = array_map(fn ($r) => [
            'seq' => (int) $r->seq,
            'entity_type' => $r->entity_type,
            'entity_id' => $r->entity_id,
            'op' => $r->op,
            'payload' => $r->payload !== null ? json_decode((string) $r->payload, true) : null,
            'occurred_at' => $r->occurred_at,
        ], $rows);

        $nextCursor = $changes !== [] ? (int) end($changes)['seq'] : $since;

        return [
            'mode' => 'delta',
            'cursor' => $nextCursor,
            'has_more' => count($changes) === $limit,
            'current_seq' => $currentSeq,
            'changes' => $changes,
        ];
    }

    /**
     * İlk kurulum: canlı satırların tam durumu (tombstone'lar hariç; append tabloları tam).
     * RLS her sorguyu oturumdaki tenant'a kısıtlar. cursor=currentSeq → sonraki çağrı delta.
     *
     * @return array{mode: string, cursor: int, has_more: bool, current_seq: int, entities: array<string, mixed>}
     */
    private function snapshot(int $currentSeq): array
    {
        return [
            'mode' => 'snapshot',
            'cursor' => $currentSeq,
            'has_more' => false,
            'current_seq' => $currentSeq,
            'entities' => [
                'customer' => Customer::query()->whereNull('deleted_at')->get()->toArray(),
                'customer_phone' => CustomerPhone::query()->whereNull('deleted_at')->get()->toArray(),
                'customer_address' => CustomerAddress::query()->whereNull('deleted_at')->get()->toArray(),
                'product' => Product::query()->whereNull('deleted_at')->get()->toArray(),
                'order' => Order::query()->whereNull('deleted_at')->get()->toArray(),
                'order_line' => OrderLine::query()->whereNull('deleted_at')->get()->toArray(),
                'order_event' => OrderEvent::query()->get()->toArray(),
                'ledger_entry' => LedgerEntry::query()->get()->toArray(),
                'coupon_movement' => CouponMovement::query()->get()->toArray(),
                'coupon_balance' => CouponBalance::query()->get()->toArray(),
                'cash_handover' => CashHandover::query()->get()->toArray(),
            ],
        ];
    }

    /**
     * @return array{client_event_id: string, status: string, entity_id: null, server_seq: null, message: string}
     */
    private function rejected(string $clientEventId, string $message): array
    {
        return [
            'client_event_id' => $clientEventId,
            'status' => 'rejected',
            'entity_id' => null,
            'server_seq' => null,
            'message' => $message,
        ];
    }
}
