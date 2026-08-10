<?php

namespace App\Support\Sync;

use App\Models\CallLog;
use App\Models\CashHandover;
use App\Models\Customer;
use App\Models\CustomerAddress;
use App\Models\CustomerPhone;
use App\Models\DayClosing;
use App\Models\ExemptNumber;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\OrderEvent;
use App\Models\OrderLine;
use App\Models\Product;
use App\Models\Tenant;
use App\Models\TenantSetting;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

/**
 * Senkron çekirdeği (DECISIONS senkron). İki yüzey: push (tek yazma) ve pull (tek okuma).
 *
 * PUSH: tenant_sync_state satırını FOR UPDATE ile kilitler (seq atama sırası = commit sırası →
 * kayıp-güncelleme sınıfı kapanır, korku #2). Her olay ÖNCE `EventValidator` ile içerik doğrulamasından
 * geçer (biçimsel olarak bozuk olay hiçbir DB satırına dokunmadan 'rejected' döner — zarf doğrulaması
 * isteğin kendisinde, bkz. SyncPushRequest); ardından (tenant_id, client_event_id) idempotency
 * kontrolü; yeni olay ChangeApplier'a verilir, ürettiği her değişikliğe monoton seq atanıp sync_changes'e
 * yazılır. Olay bazında savepoint: bir olay istemci-kaynaklı hatayla reddedilirse yalnız o geri alınır,
 * parti bozulmaz (Postgres'te hatalı statement transaction'ı zehirler; savepoint bunu izole eder).
 *
 * `results` SÖZLEŞMESİ — gönderilen HER olay için tam bir girdi, GÖNDERİLEN SIRADA:
 * `index` (dizideki konum; bozuk/eksik kimlikte istemcinin tek sağlam eşleme anahtarı),
 * `client_event_id` (geçersiz olsa bile HAM geri yansıtılır), `status` (applied|stale|noop|duplicate|
 * locked|rejected), `entity_id`, `server_seq`, `reason` (makine okunur sebep KODU — yalnız rejected/
 * locked'da dolu; kodların listesi ve metinleri EventValidator::message'ta), `message` (insan metni,
 * KVKK-güvenli). `index`+`reason` 2026-08-05'te EKLENDİ; eski istemci bilmediği alanı yok sayar ve
 * `status == 'rejected'` yolunu bugünkü gibi işler.
 *
 * PULL: since=0 tam snapshot (canlı satırlar), since>0 sync_changes'ten seq sıralı delta. Redelivery
 * zararsızdır (istemci upsert idempotent) — snapshot/delta sınırındaki olası tekrar veri kaybettirmez.
 */
class SyncService
{
    /**
     * Bir push isteğinde işlenecek azami olay (DoS + transaction süresi sınırı).
     *
     * ⚠️ İSTEMCİ SABİTİYLE BAĞLIDIR: `apps/mobile/lib/sync/sync_engine.dart` → `pushPending`ın
     * `batchSize`ı (bugün 400) bu değeri AŞMAMALIDIR. Aşarsa parti zarf doğrulamasına takılır ve
     * HER push kalıcı 422 döner — istemcinin bisect'i kuyruğu kurtarır ama her tur boşa gider.
     * Bu değeri DÜŞÜRMEK de aynı kapıdır: sahadaki eski istemciler eski batchSize ile gönderir.
     *
     * Bağ 2026-08-05'te İKİ ucundan da sağlamlaştırıldı: (1) istemci 500 yerine 400 gönderiyor,
     * yani sözleşme artık tam sınırda değil — 100 olaylık payı var; (2) bağ artık YAZILI DEĞİL,
     * ZORLANIYOR: `SurumCarpikligiTest` mobil kaynaktan `batchSize`ı okuyup bu sabitle
     * karşılaştırır. (Eski yorum "iki sabit ayrı depolarda, birbirini göremiyor" diyordu — oysa
     * aynı monorepo'dalar ve bekçi bunu görebiliyor.)
     */
    public const MAX_EVENTS = 500;

    /**
     * İstemci-kaynaklı (reddedilebilir) SQL durumları: geçersiz uuid, not-null, FK, unique, check,
     * kolona sığmayan metin, aralık dışı sayı.
     *
     * BU LİSTE BİR BEYAZ LİSTEDİR ve dışında kalan her SQLSTATE partiyi 500'e düşürür. 500 istemci
     * için GEÇİCİ hatadır — sonsuza dek yeniden denenir. Yani listede olmayan her istemci-kaynaklı
     * hata bir ZEHİRLİ HAPtır: kuyruk asla boşalmaz, senkron kalıcı ölür ve tek "çözüm" uygulama
     * verisini silmek olur — ki bu bekleyen sipariş/tahsilatı yok eder (kırmızı çizgi #3).
     *
     * `22001` (string_data_right_truncation) ve `22003` (numeric_value_out_of_range) 2026-08-05'te
     * EKLENDİ. İkisi de tartışmasız istemci verisidir — altyapı arızası bu kodları üretemez; anlamı
     * "gönderdiğin değer bu kolona sığmıyor"dur. Eskiden 500 veriyorlardı, yani uzun bir müşteri adı
     * ya da taşan bir sayı bütün senkronu kilitliyordu. Bu depoda ikisi de daha önce ısırdı: panelde
     * 10 haneli telefon `customers.code` (int4) taşırıp 500 vermişti (DECISIONS 2026-08-01) ve barkod
     * `max:64` vs `varchar(32)` uyuşmazlığı tüm partiyi düşürmüştü. Panelde yapısal kapak var
     * (form `max:`leri `information_schema` ile karşılaştırılıyor); MOBİL yazma yolunda yok — bu
     * yüzden reddin sunucuda güvenli biçimde karşılanması gerekiyor.
     *
     * `22007`/`22008` (geçersiz tarih biçimi / taşma) 2026-08-06'da EKLENDİ: `EventValidator` damgayı
     * `Carbon::parse` ile doğrular, Postgres daha katıdır ve ARADA kalan değerler vardır (ölçüldü:
     * `'next monday'`, `'+1 day'` → 22007; `'1754467200'` → 22008). Böyle bir damga doğrulamadan
     * geçip `sync_changes` INSERT'ünde patlıyor ve listede olmadığı için TÜM partiyi 500'e
     * düşürüyordu. Asıl kapı `applyOne`daki `SyncPayload::zaman()`tir; bu İKİNCİ katmandır.
     *
     * Yeni bir kısıt/kolon tipi eklerken sor: bu kod istemcinin GÖNDERDİĞİ veriden doğabilir mi?
     * Cevap evetse buraya girmeli, yoksa bir sonraki zehirli hap odur.
     */
    private const CLIENT_DATA_SQLSTATES = [
        '22001', '22003', '22007', '22008', '22P02', '23502', '23503', '23505', '23514',
    ];

    /**
     * Olay listesi BİLEREK `list<mixed>`tir: zarf doğrulaması elemanların biçimini GARANTİ ETMEZ
     * (etseydi tek bozuk eleman tüm partiyi 422 yapardı — düzeltilen arıza tam buydu).
     *
     * @param  list<mixed>  $events
     * @return array{results: list<array<string, mixed>>, current_seq: int, subscription: array<string, mixed>, team: list<array<string, mixed>>}
     */
    public function push(User $user, array $events): array
    {
        $tenantId = (string) $user->tenant_id;
        $applier = new ChangeApplier($user);
        $now = now();

        return DB::transaction(function () use ($tenantId, $events, $applier, $now) {
            // Abonelik kilidi (FAZ 5a): TEK yazma yüzeyinde uygulanır (okuma/pull ASLA kilitlenmez).
            // Kilitliyse locked_at çıpasını lazy kur; kilit kararı server saatine göre kesin (grace YALNIZ
            // istemcide). RLS altında oturumdaki tenant okunur/güncellenir.
            $tenant = Tenant::query()->findOrFail($tenantId);
            [$locked, $lockedAt] = $this->resolveLock($tenant, $now);

            // Seq sayacını kilitle (satır yoksa oluştur). Kilit outer transaction commit'ine kadar tutulur.
            DB::insert(
                'INSERT INTO tenant_sync_state (tenant_id, last_seq) VALUES (?, 0) ON CONFLICT (tenant_id) DO NOTHING',
                [$tenantId]
            );
            $lastSeq = (int) (DB::table('tenant_sync_state')
                ->where('tenant_id', $tenantId)->lockForUpdate()->value('last_seq') ?? 0);

            $results = [];
            $index = -1;
            foreach ($events as $raw) {
                $index++;
                $clientEventId = EventValidator::clientEventId($raw);

                // OLAY İÇERİĞİ DOĞRULAMASI — her şeyden ÖNCE ve DB'ye dokunmadan. Sırası kritik:
                // geçersiz client_event_id ile aşağıdaki processed_events sorgusu 22P02 verirdi ve o
                // hata savepoint DIŞINDA olduğu için TÜM transaction'ı zehirlerdi (500 + kuyruk kilidi).
                if (! is_array($raw)) {
                    $results[] = $this->rejected($index, $clientEventId, 'invalid_event', null);

                    continue;
                }
                /** @var array<string, mixed> $event */
                $event = $raw;

                $reason = EventValidator::reason($event);
                if ($reason !== null) {
                    $results[] = $this->rejected($index, $clientEventId, $reason, $event);

                    continue;
                }

                $processed = DB::selectOne(
                    'SELECT entity_id, result_seq FROM processed_events WHERE tenant_id = ? AND client_event_id = ?',
                    [$tenantId, $clientEventId]
                );
                if ($processed !== null) {
                    $results[] = [
                        'index' => $index,
                        'client_event_id' => $clientEventId,
                        'status' => 'duplicate',
                        'entity_id' => $processed->entity_id,
                        'server_seq' => $processed->result_seq !== null ? (int) $processed->result_seq : null,
                        'reason' => null,
                    ];

                    continue;
                }

                // Kilitliyken: occurred_at <= locked_at olan olay KABUL (offline birikmiş yazım akar,
                // veri kaybı yok — BRIEF kırmızı çizgi #5); occurred_at > locked_at ise `locked` reddedilir.
                // 'locked' reddi processed_events'e YAZILMAZ (rejected'tan farklı: geçici; abonelik
                // yenilenince AYNI olay retry'da uygulanabilir) ve seq'i ilerletmez.
                if ($locked && $lockedAt !== null && $this->lockedOut($event, $lockedAt)) {
                    $results[] = $this->locked($index, $clientEventId);

                    continue;
                }

                try {
                    [$lastSeq, $result] = $this->applyOne($tenantId, $event, $lastSeq, $applier, $index);
                    $results[] = $result;
                } catch (InvalidArgumentException $e) {
                    $results[] = $this->rejected($index, $clientEventId, 'domain_rejected', $event, $e->getMessage());
                } catch (QueryException $e) {
                    if (! in_array((string) $e->getCode(), self::CLIENT_DATA_SQLSTATES, true)) {
                        throw $e; // beklenmedik altyapı hatası → partiyi geri al
                    }
                    $results[] = $this->rejected($index, $clientEventId, 'invalid_data', $event);
                }
            }

            SyncRejectionLog::batch($results);

            DB::update(
                'UPDATE tenant_sync_state SET last_seq = ?, updated_at = now() WHERE tenant_id = ?',
                [$lastSeq, $tenantId]
            );

            return [
                'results' => $results,
                'current_seq' => $lastSeq,
                'subscription' => $this->subscriptionPayload($tenant, $now),
                'team' => $this->teamPayload(),
            ];
        });
    }

    /**
     * Tek olayı savepoint içinde uygular; ürettiği değişikliklere seq atayıp günlüğe yazar.
     * Hata olursa savepoint geri alınır (seq ilerlemez), exception dışarı fırlar.
     *
     * @param  array<string, mixed>  $event
     * @return array{0: int, 1: array<string, mixed>}
     */
    private function applyOne(string $tenantId, array $event, int $lastSeq, ChangeApplier $applier, int $index): array
    {
        return DB::transaction(function () use ($tenantId, $event, $lastSeq, $applier, $index) {
            $applied = $applier->apply($tenantId, $event);

            // HAM SQL yolu (Eloquent cast'i yok): varlık tablosu Carbon'la, bu kolon Postgres'le
            // çözülüyordu — iki ayrıştırıcı, aradaki fark zehirli hap kapısı (bkz. yukarıda 22007).
            $occurredAt = SyncPayload::zaman($event['occurred_at'] ?? null);
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

            // Idempotency defteri: applied/stale/noop/duplicate hepsinde yazılır → retry
            // çift-uygulamaz. ('duplicate' uygulayıcıdan da gelebilir: aynı id yeniden
            // gönderildiğinde append tabloları — day_closings / cash_handovers — kaydı ikinci kez
            // yazmak yerine sessizce yakınsar; bkz. DayClosingChangeApplier.)
            DB::insert(
                'INSERT INTO processed_events (tenant_id, client_event_id, entity_type, entity_id, result_seq)
                 VALUES (?, ?, ?, ?, ?)',
                [
                    $tenantId, (string) ($event['client_event_id'] ?? ''),
                    (string) ($event['entity_type'] ?? ''), $applied['entity_id'], $seqForEvent,
                ]
            );

            return [$lastSeq, [
                'index' => $index,
                'client_event_id' => (string) ($event['client_event_id'] ?? ''),
                'status' => $applied['status'],
                'entity_id' => $applied['entity_id'],
                'server_seq' => $seqForEvent,
                'reason' => null,
            ]];
        });
    }

    /**
     * @return array{mode: string, cursor: int, has_more: bool, current_seq: int, subscription: array<string, mixed>, team: list<array<string, mixed>>, changes?: list<array<string, mixed>>, entities?: array<string, mixed>}
     */
    public function pull(User $user, int $since, int $limit): array
    {
        $tenantId = (string) $user->tenant_id;
        $now = now();
        // Okuma ASLA kilitlenmez (kırmızı çizgi #5); pull yalnız abonelik durumunu YAYINLAR (istemci
        // önbellekler + ileri-sadece saatle grace hesaplar). Salt-okuma: locked_at LAZY yazımı YOK (o push'a özgü).
        $tenant = Tenant::query()->findOrFail($tenantId);
        $subscription = $this->subscriptionPayload($tenant, $now);

        $currentSeq = (int) (DB::table('tenant_sync_state')
            ->where('tenant_id', $tenantId)->value('last_seq') ?? 0);

        if ($since <= 0) {
            return $this->snapshot($currentSeq) + ['subscription' => $subscription, 'team' => $this->teamPayload()];
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
            'subscription' => $subscription,
            'team' => $this->teamPayload(),
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
                'cash_handover' => CashHandover::query()->get()->toArray(),
                // Tasarım boşluğu varlıkları: profil (tek satır), muaf numaralar ve çağrı günlüğü
                // tombstone'suz çekilir; kapanış arşivi append tablosudur (tam çekilir).
                'tenant_settings' => TenantSetting::query()->get()->toArray(),
                'exempt_number' => ExemptNumber::query()->whereNull('deleted_at')->get()->toArray(),
                'call_log' => CallLog::query()->whereNull('deleted_at')->get()->toArray(),
                'day_closing' => DayClosing::query()->get()->toArray(),
            ],
        ];
    }

    /**
     * Reddedilen olayın sonucu + sunucu günlüğü (KVKK sözleşmesi SyncRejectionLog'da).
     *
     * `reason` MAKİNE OKUNUR sebep kodudur (istemci karantina/günlük için okur), `message` insan
     * metnidir. İkisi de mevcut sözleşmeye EKTİR: eski istemci bilmediği alanı yok sayar.
     *
     * @param  array<string, mixed>|null  $event
     * @return array{index: int, client_event_id: string, status: string, entity_id: null, server_seq: null, reason: string, message: string}
     */
    private function rejected(int $index, string $clientEventId, string $reason, ?array $event, ?string $message = null): array
    {
        SyncRejectionLog::event($clientEventId, $event['entity_type'] ?? null, $event['op'] ?? null, $reason);

        return [
            'index' => $index,
            'client_event_id' => $clientEventId,
            'status' => 'rejected',
            'entity_id' => null,
            'server_seq' => null,
            'reason' => $reason,
            'message' => $message ?? EventValidator::message($reason),
        ];
    }

    /**
     * Kilit durumu (FAZ 5a). Kilit koşulu: status ∈ {locked, suspended} VEYA valid_until < now.
     * valid_until NULL → KİLİTLİ DEĞİL (factory/test tenant'ları ve sınırsız durumlar bozulmaz).
     * Kilitliyse ve locked_at NULL ise LAZY set: locked_at = valid_until (süre dolumu çıpası); valid_until
     * de yoksa (panel-lock, çıpasız) now — bekleyen sınırı en kötü ihtimalle şimdiye çeker.
     *
     * @return array{0: bool, 1: Carbon|null}
     */
    private function resolveLock(Tenant $tenant, Carbon $now): array
    {
        $expired = $tenant->valid_until !== null && $tenant->valid_until->lessThan($now);
        // 'cancelled' (bayi bıraktı) locked/suspended ile AYNI kefede: yeni yazım kapalı, bekleyen
        // offline kayıtlar yine akar, veri silinmez (BRIEF kırmızı çizgi #5). Enum'a durum eklerken
        // bu listeyi güncellememek, iptal etmiş bir bayinin valid_until'ı ileride kaldığı sürece
        // yazmaya devam etmesi demekti — hiçbir yerde patlamayan, yalnız yanlış olan bir arıza.
        $statusLocked = $tenant->status->writesLocked();

        if (! $statusLocked && ! $expired) {
            return [false, null];
        }

        $lockedAt = $tenant->locked_at;
        if ($lockedAt === null) {
            $lockedAt = $tenant->valid_until ?? $now;
            $tenant->forceFill(['locked_at' => $lockedAt])->save();
        }

        return [true, $lockedAt];
    }

    /**
     * Kilit-sonrası yeni yazım mı? occurred_at > locked_at → EVET (reddedilir). occurred_at <= locked_at
     * → HAYIR (bekleyen offline yazım, kabul edilir). occurred_at yoksa yeni sayılır (kilitli).
     *
     * @param  array<string, mixed>  $event
     */
    private function lockedOut(array $event, Carbon $lockedAt): bool
    {
        $occurredAt = (string) ($event['occurred_at'] ?? '');
        if ($occurredAt === '') {
            return true;
        }

        return Carbon::parse($occurredAt)->greaterThan($lockedAt);
    }

    /**
     * 'locked' sonucu: 'rejected'tan FARKLI (geçici; abonelik yenilenince retry uygulanabilir).
     * processed_events'e YAZILMAZ, seq'i ilerletmez. Mesaj nötr (PII yok, KVKK).
     *
     * @return array{index: int, client_event_id: string, status: string, entity_id: null, server_seq: null, reason: string, message: string}
     */
    private function locked(int $index, string $clientEventId): array
    {
        return [
            'index' => $index,
            'client_event_id' => $clientEventId,
            'status' => 'locked',
            'entity_id' => null,
            'server_seq' => null,
            // 'locked' bir REDDETME DEĞİLDİR (geçici); sebep alanı yalnız sonuç şeklini tekdüze
            // tutmak ve istemcinin ayrımı kod üzerinden yapabilmesi için doldurulur.
            'reason' => 'subscription_locked',
            'message' => 'Aboneliğiniz sona erdi. Yeni kayıt kilitli.',
        ];
    }

    /**
     * Abonelik durumu yayını (DECISIONS: tek doğru kaynak sunucu). İstemci önbellekler + ileri-sadece
     * saatle grace hesaplar. server_time = kilit kararında kullanılan $now (tutarlı kaynak).
     *
     * @return array{status: string, valid_until: string|null, locked_at: string|null, modules: array<string, mixed>, tenant_code: string, route_credits: int, route_credits_monthly: int, courier_limit: int, server_time: string}
     */
    private function subscriptionPayload(Tenant $tenant, Carbon $now): array
    {
        return [
            'status' => $tenant->status->value,
            'valid_until' => $tenant->valid_until?->utc()->toIso8601String(),
            'locked_at' => $tenant->locked_at?->utc()->toIso8601String(),
            // Opsiyonel modül bayrakları (FAZ 5c-2): istemci UI'yı çizerken kullanır (mobil UI sonraki iş).
            'modules' => $tenant->modules,
            // SUNUCU SAHİPLİ, istemcinin YAZAMAYACAĞI alanlar aynı kanaldan iner (modules deseni):
            // tenant_code = tasarımdaki "Firma Kodu" (tenants.slug, değiştirilemez);
            // route_credits = "Oto Sırala (rota) · N hak" KALAN sayaç, route_credits_monthly = aylık kota
            // (çekmecedeki ilerleme çubuğu bu ikisinin oranı).
            'tenant_code' => $tenant->slug,
            'route_credits' => $tenant->route_credits,
            'route_credits_monthly' => $tenant->route_credits_monthly,
            // courier_limit = açılabilecek kurye hesabı kotası (2026-08-04, ek paketlerle birlikte
            // sunucuda ZORLANIR hâle geldi — App\Abonelik\KuryeKotasi). route_credits_monthly ile
            // birebir aynı kanal ve aynı gerekçe: sunucu-sahipli, istemcinin YAZAMAYACAĞI bir kota
            // tam durum olarak her senkronda iner. Mobilde kurye açma ucu bugün YOK; alan, kotayı
            // gösterecek ekran (ya da web istemcisi) geldiğinde hazır olsun diye şimdi yayınlanıyor —
            // sunucudaki doğru değer istemciye ULAŞMIYORSA yoktur (migration 802'nin dersi).
            // Fiyat/paket/dönem BİLİNÇLİ OLARAK YAYINLANMAZ: mağaza kuralı (BRIEF, pazarlıksız).
            'courier_limit' => $tenant->courier_limit,
            'server_time' => $now->utc()->toIso8601String(),
        ];
    }

    /**
     * Ekip listesi yayını (K1 — 4b Dilim 4). Bayinin kullanıcıları; mobil `team` bloğuyla iner ve
     * yerel önbelleğe toptan yazılır (users ASLA istemciden push edilmez → sync_changes'e düşmez;
     * snapshot/delta yerine her senkronda tazelenen hafif liste). Bu bloğa BİLEREK yalnız atama +
     * ad-çözümü için gereken alanlar konur.
     *
     * PII ASGARİ (kırmızı çizgi #4): SELECT açıkça sayılır — email/parola/last_login_at ASLA
     * seçilmez ($hidden'a güvenmeyiz, kolon listesi garantidir). users tablosu Faz 1'den beri
     * ENABLE+FORCE RLS → sorgu oturumdaki tenant'a kısıtlı, cross-tenant sızma DB seviyesinde
     * imkânsız (SyncTeamTest bunu sürekli kanıtlar). disabled kullanıcı da DÖNER: eski atamalarda
     * adı gösterilmeli; UI atama hedefi olarak yalnız active sunar.
     *
     * `phone` BİLİNÇLİ EKLENDİ (tasarım: Kuryeler ekranı telefonu gösterir ve düzenler). PII-asgari
     * kuralının amacı MÜŞTERİ verisini ve kimlik bilgisini kısmaktı; kurye telefonu bayinin KENDİ
     * personel iletişim bilgisidir, patron girer ve kuryeyi aramak için gerekir.
     *
     * `username` de BİLİNÇLİ EKLENDİ (kullanıcı isteği 2026-08-04: kuryenin giriş bilgileri
     * uygulamadan düzenlenebilsin). Kullanıcı adı bir SIR DEĞİLDİR — patron onu kuryeye zaten
     * kendisi söyler ve unuttuğunda soracağı yer burasıdır. Kimlik yüzeyinin gizli yarısı
     * (e-posta, parola hash'i) payload DIŞINDA kalmaya devam eder; parola hiçbir yönde,
     * hiçbir biçimde okunmaz — yalnız YAZILIR (TeamController::credentials).
     *
     * 13 KİŞİYE ÖZEL KURYE YETKİSİ 2026-08-10'da EKLENDİ (migration 004008) çünkü HER CİHAZ KENDİ
     * YETKİSİNİ BU BLOKTAN ÖĞRENİR: yetkiler artık kullanıcı bazlıdır ve `users` senkron delta
     * günlüğünde hiç yer almaz (snapshot/delta yolu users bilmez) — telefona ulaşmalarının TEK
     * kanalı burasıdır. `bool|null` üç durumludur: null = "bayi varsayılanını devral", yani istemci
     * etkin yetkiyi `team[ben].courier_x ?? tenant_settings.courier_x` ile çözer. Sunucu bu
     * birleştirmeyi YAPMAZ — birleşik değer, "devralıyor" ile "kişiye özel açık" ayrımını yok eder
     * ve yetki ekranı tam o ayrımı gösterir. Yayınlamamak ise migration 802'nin dersine düşerdi:
     * "sunucuda doğru duran ama inmeyen alan YOKTUR."
     *
     * BU BİR PII SIZMASI DEĞİLDİR: yetkiler bayinin KENDİ yapılandırmasıdır (müşteri verisi ya da
     * kimlik bilgisi değil) ve liste zaten aynı bayinin kendi ekibini taşır.
     *
     * @return list<array{id: string, name: string, role: string, status: string, phone: string|null, username: string, courier_can_customers: bool|null, courier_can_orders: bool|null, courier_can_collect: bool|null, courier_can_discount: bool|null, courier_can_day_end: bool|null, courier_can_see_all_orders: bool|null, courier_can_view_history: bool|null, courier_can_expense: bool|null, courier_phone_mask: bool|null, courier_can_customer_ledger: bool|null, courier_can_debt_reminder: bool|null, courier_can_toggle_stock: bool|null, courier_can_call_log: bool|null}>
     */
    private function teamPayload(): array
    {
        // Kolon listesi AÇIKÇA sayılır (PII asgari): yetki kolonları listeye `User`ın tek doğru
        // kaynağından eklenir, elle ikinci kez yazılmaz.
        $kolonlar = array_merge(
            ['id', 'name', 'role', 'status', 'phone', 'username'],
            User::kuryeIzinKolonlari(),
        );

        return User::query()
            ->orderBy('name')
            ->get($kolonlar)
            ->map(function (User $u): array {
                $izinler = [];
                foreach (User::kuryeIzinKolonlari() as $kolon) {
                    // Cast'ten geçmiş değer: bool ya da null (NULL "devral" demektir, false DEĞİL).
                    $izinler[$kolon] = $u->getAttribute($kolon);
                }

                return [
                    'id' => (string) $u->id,
                    'name' => (string) $u->name,
                    'role' => $u->role->value,
                    'status' => (string) $u->status,
                    'phone' => $u->phone,
                    'username' => (string) $u->username,
                ] + $izinler;
            })
            ->all();
    }
}
