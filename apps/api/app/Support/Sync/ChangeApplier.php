<?php

namespace App\Support\Sync;

use App\Models\CallLog;
use App\Models\Customer;
use App\Models\CustomerAddress;
use App\Models\CustomerPhone;
use App\Models\ExemptNumber;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
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
    /**
     * @param  User  $aktor  Push'u YAPAN oturum kullanıcısı. Uygulayıcıların çoğu buna bakmaz
     *                       (senkron varlıkları rol tanımaz); `user_profile` yolu bakar — kişiye
     *                       özel kurye yetkisi yazımı patron/operatör ister ve aktör olay
     *                       gövdesinden OKUNAMAZ, gövde istemcinin beyanıdır (2026-08-10).
     */
    public function __construct(private readonly User $aktor) {}

    /**
     * LWW ile yönetilen basit varlıklar (upsert/delete). exempt_number ve call_log tasarım
     * boşluğundan gelir (muaf numaralar / çağrı günlüğü): ikisi de düzenlenebilir varlıktır,
     * para/hareket kaydı DEĞİL — bu yüzden append değil aynı LWW + tombstone yolundan geçerler.
     */
    private const SIMPLE_ENTITIES = [
        'customer', 'customer_phone', 'customer_address', 'product', 'exempt_number', 'call_log',
    ];

    /**
     * Payload'da KARŞILIĞI OLMAYAN, başka bir alandan/olay zarfından hesaplanan kolonlar. Sürüm
     * çarpıklığı filtresi (SyncPayload::gonderilenler) bunları düşürmez — düşürseydi numara
     * güncellenirken `phone_last10` eski değerde donar, arayan tanıma yanlış müşteriyi açardı.
     *
     * @var array<string, list<string>>
     */
    private const TUREYEN_KOLONLAR = [
        'customer_phone' => ['phone_last10'],
        'exempt_number' => ['phone_last10'],
        'call_log' => ['phone_last10', 'occurred_at', 'device_id'],
    ];

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
            'cash_handover' => (new CashHandoverChangeApplier)->apply($tenantId, $event),
            'tenant_settings', 'user_profile' => (new ProfileChangeApplier($this->aktor))->apply($tenantId, $event),
            'day_closing' => (new DayClosingChangeApplier)->apply($tenantId, $event),
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
        // UTC'ye normalize: aşağıdaki `updated_occurred_at` ve `deleted_at` yazımlarının hepsi
        // buradan türer (bkz. SyncPayload::zaman — offset'li damga 3 saat kayıyordu).
        $occurredAt = (string) SyncPayload::zaman((string) ($event['occurred_at'] ?? ''));
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

            $changes = [SyncPayload::change($type, $id, 'delete', $existing)];
            if ($type === 'customer') {
                $changes = array_merge($changes, $this->cascadeCustomerDelete($id, $occurredAt, $deviceId));
            }

            return ['status' => 'applied', 'entity_id' => $id, 'changes' => $changes];
        }

        if ($op !== 'upsert') {
            throw new InvalidArgumentException("{$type} için geçersiz op: {$op}");
        }

        $this->validateEntityRefs($type, $payload);
        $cols = $this->simpleColumns($type, $payload, $event);

        if ($existing !== null && ! $this->lwwWins($existing, $occurredAt, $deviceId)) {
            return ['status' => 'stale', 'entity_id' => $id, 'changes' => []];
        }

        // SÜRÜM ÇARPIKLIĞI: mevcut satırda, payload'da HİÇ GEÇMEYEN kolonlar korunur (bkz.
        // SyncPayload::gonderilenler). YENİ satırda filtre YOK — korunacak bir değer yoktur ve
        // NOT NULL kolonların varsayılanı yazılmalıdır.
        if ($existing !== null) {
            $cols = SyncPayload::gonderilenler($cols, $payload, self::TUREYEN_KOLONLAR[$type] ?? []);
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

    /**
     * Müşteri silindiğinde telefon ve adres satırlarını da tombstone'la.
     *
     * NEDEN GEREKLİ: arayan tanıma `customer_phones` üzerinden çalışır ve müşteri satırına
     * BAKMAZ (1 sn bütçesi, tek-satır okuma). Telefonlar canlı kalsaydı silinen müşteri gelen
     * aramada kartıyla çıkmaya devam ederdi — özelliğin kullanıcı için ANLAMI budur ve silme
     * onu karşılamazdı. Ayrıca `snapshot` telefonu müşterisiz gönderir, yeni kurulan cihazda
     * öksüz satır kalırdı.
     *
     * Değişiklikler AYNI olayın change listesine eklenir: tek seq bloğu, tek transaction —
     * iki cihaz aynı sonuca varır. LWW damgası müşterininkiyle aynı occurred_at/device_id'dir
     * (silme tek bir karardır, parçalarının damgası ayrışmamalı).
     *
     * ZATEN SİLİNMİŞ satırlar atlanır: yoksa her tekrar silme gereksiz değişiklik üretirdi.
     * Silme GERİ ALINMAZ (upsert bir tombstone'u diriltir ama telefonları diriltmez) — silme
     * onaylı ve tek yönlü bir eylemdir, "geri al" bir ÜRÜN kararıdır, sessiz bir yan etki değil.
     *
     * @return list<array<string, mixed>>
     */
    private function cascadeCustomerDelete(string $customerId, string $occurredAt, ?string $deviceId): array
    {
        $changes = [];

        foreach ([['customer_phone', CustomerPhone::class], ['customer_address', CustomerAddress::class]] as [$tip, $sinif]) {
            $rows = $sinif::query()
                ->where('customer_id', $customerId)
                ->whereNull('deleted_at')
                ->get();

            foreach ($rows as $row) {
                $row->forceFill([
                    'deleted_at' => $occurredAt,
                    'updated_occurred_at' => $occurredAt,
                    'updated_device_id' => $deviceId,
                ])->save();
                $changes[] = SyncPayload::change($tip, (string) $row->getKey(), 'delete', $row);
            }
        }

        return $changes;
    }

    /** @return class-string<Model> */
    private function simpleModelClass(string $type): string
    {
        return match ($type) {
            'customer' => Customer::class,
            'customer_phone' => CustomerPhone::class,
            'customer_address' => CustomerAddress::class,
            'product' => Product::class,
            'exempt_number' => ExemptNumber::class,
            'call_log' => CallLog::class,
            default => throw new InvalidArgumentException("Bilinmeyen varlık: {$type}"),
        };
    }

    /**
     * İstemciden yazılabilir iş kolonları. NOT: customers.balance_kurus BURADA YOK — o defterden
     * türeyen önbellektir (DECISIONS), istemci ezemez; ledger olayında sunucu tazeler.
     *
     * @param  array<string, mixed>  $p
     * @param  array<string, mixed>  $event
     * @return array<string, mixed>
     */
    private function simpleColumns(string $type, array $p, array $event): array
    {
        return match ($type) {
            'customer' => [
                'name' => SyncPayload::req($p, 'name'),
                'note' => $p['note'] ?? null,
                // KARA LİSTE: ayrı bir op DEĞİL, müşterinin bir ALANI. Gerekçe: kara listeye
                // alma/çıkarma tam da LWW'nin çözdüğü şeydir (iki cihaz farklı yönde karar
                // verirse son karar kazanır) — ayrı op yazmak aynı çakışma çözümünü ikinci kez
                // kurmak olurdu.
                //
                // İSTEMCİ SÖZLEŞMESİ (2026-08-05'te DÜZELTİLDİ): anahtar payload'da VARSA yazılır
                // — null göndermek kara listeden ÇIKARMAK demektir ve bu ifade edilebilir kalır.
                // Anahtar HİÇ YOKSA mevcut değer korunur (SyncPayload::gonderilenler).
                //
                // Eski davranış "alan yoksa null yaz"dı ve gerekçesi "null hem bilmiyorum hem
                // çıkar olurdu" idi; ayrımı anahtarın VARLIĞINA bağlamak o ikilemi çözer. Eski
                // hâliyle, `blacklisted_at`i bilmeyen bir build (2026-08-01 öncesi) müşterinin
                // adını düzeltince kara listeyi sessizce kaldırıyordu.
                'blacklisted_at' => SyncPayload::zaman($p['blacklisted_at'] ?? null),
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
                'region' => $p['region'] ?? null, // tasarım: "Bölge" (Kepez/Muratpaşa/Lara)
                'lat' => isset($p['lat']) ? (float) $p['lat'] : null,
                'lng' => isset($p['lng']) ? (float) $p['lng'] : null,
                'is_primary' => (bool) ($p['is_primary'] ?? false),
            ],
            'product' => [
                'name' => SyncPayload::req($p, 'name'),
                'unit_price_kurus' => (int) SyncPayload::req($p, 'unit_price_kurus'),
                'unit' => (string) ($p['unit'] ?? 'adet'),
                // barcode tekilliği DB'de ZORLANMAZ (migration 605): çevrimdışı iki cihazın aynı
                // barkodu girmesi olayı reddedip veri kaybettirirdi; UI uyarır, DB kabul eder.
                'barcode' => $p['barcode'] ?? null,
                'image_url' => $p['image_url'] ?? null,
                'is_active' => (bool) ($p['is_active'] ?? true),
            ],
            'exempt_number' => [
                'phone_e164' => SyncPayload::req($p, 'phone_e164'),
                'phone_last10' => (string) ($p['phone_last10'] ?? self::last10((string) $p['phone_e164'])),
                'label' => $p['label'] ?? null,
            ],
            'call_log' => [
                'customer_id' => $p['customer_id'] ?? null,
                'phone_e164' => SyncPayload::req($p, 'phone_e164'),
                'phone_last10' => (string) ($p['phone_last10'] ?? self::last10((string) $p['phone_e164'])),
                'direction' => self::direction($p),
                'outcome' => $p['outcome'] ?? null,
                'related_order_id' => $p['related_order_id'] ?? null,
                // Çağrının GERÇEKLEŞTİĞİ an; LWW'nin updated_occurred_at'inden ayrıdır (sonuç sonradan
                // yazılınca LWW damgası ilerler ama çağrı saati sabit kalmalı).
                'occurred_at' => SyncPayload::zaman((string) ($p['occurred_at'] ?? $event['occurred_at'] ?? '')),
                'device_id' => $event['device_id'] ?? null,
            ],
            default => throw new InvalidArgumentException("Bilinmeyen varlık: {$type}"),
        };
    }

    /**
     * Çağrı yönü beyaz listesi — CHECK ihlalinin transaction'ı zehirlemesini önle (önden reddet).
     *
     * @param  array<string, mixed>  $p
     */
    private static function direction(array $p): string
    {
        $direction = (string) SyncPayload::req($p, 'direction');
        if (! in_array($direction, ['incoming', 'missed', 'outgoing'], true)) {
            throw new InvalidArgumentException("Geçersiz direction: {$direction}");
        }

        return $direction;
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

        // call_log referansları OPSİYONELDİR (kayıtsız numara → customer_id null, sipariş doğmadıysa
        // related_order_id null) ama verilmişlerse AYNI simetriyle doğrulanır (kırmızı çizgi #1).
        if ($type === 'call_log') {
            $cid = isset($payload['customer_id']) ? (string) $payload['customer_id'] : null;
            if ($cid !== null && ! Customer::query()->whereKey($cid)->exists()) {
                throw new InvalidArgumentException('customer_id bu bayide bulunamadı');
            }
            $oid = isset($payload['related_order_id']) ? (string) $payload['related_order_id'] : null;
            if ($oid !== null && ! Order::query()->whereKey($oid)->exists()) {
                throw new InvalidArgumentException('related_order_id bu bayide bulunamadı');
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

        $entryType = (string) SyncPayload::req($payload, 'entry_type');
        $amount = (int) SyncPayload::req($payload, 'amount_kurus');
        $paymentType = isset($payload['payment_type']) ? (string) $payload['payment_type'] : null;
        $this->validateLedgerEntry($entryType, $amount, $paymentType);

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

        // reverses_entry_id: ters kayıt yalnız AYNI bayinin bir defter satırını düzeltebilir.
        // Satırın KENDİSİ çekiliyor (`exists()` değil): aşağıdaki atıf kapısı ters çevrilen kaydın
        // `collected_by_user_id`sini karşılaştırmak zorunda. Sorgu RLS altında koştuğu için
        // bulunamama hem "yok" hem "başka bayinin" hâlini kapsar.
        $reversesEntryId = isset($payload['reverses_entry_id']) ? (string) $payload['reverses_entry_id'] : null;
        $reversed = $reversesEntryId === null ? null : LedgerEntry::query()->find($reversesEntryId);
        if ($reversesEntryId !== null && $reversed === null) {
            throw new InvalidArgumentException('reverses_entry_id bu bayide bulunamadı');
        }

        // collected_by_user_id (FAZ 4): tahsilatı KİM aldı — kasa devri mutabakatının dayanağı.
        // customer/product referans deseniyle simetrik: yazımdan önce RLS-kapsamlı doğrula (başka
        // bayinin kullanıcısına nakit atfedilemez, kırmızı çizgi #1). Verilmemişse (null) atlanır.
        $collectedByUserId = isset($payload['collected_by_user_id']) ? (string) $payload['collected_by_user_id'] : null;
        if ($collectedByUserId !== null && ! User::query()->whereKey($collectedByUserId)->exists()) {
            throw new InvalidArgumentException('collected_by_user_id bu bayide bulunamadı');
        }

        // KASAYA DOKUNAN DÜZELTME, TERS ÇEVİRDİĞİ KAYDIN NAKİT ATFINI TAŞIMALI (inceleme #⑥).
        // Atıf düzeltmeyi YAZAN kişiye kayarsa gün beklenen negatife düşer ve kurye hiç var olmamış
        // paradan "EKSİK" sorumlu tutulur — ikisi de append-only DONAR (senaryo: DuzeltmeAtfiTest).
        //
        // SUNUCU ATFI YENİDEN YAZMAZ, ÇELİŞKİYİ REDDEDER (lead kararı 2026-08-06): atıf da bir
        // İSTEMCİ BEYANIDIR ve sunucu para kaydını yeniden hesaplamaz (DECISIONS Faz 4). Sunucunun
        // işi beyanı düzeltmek değil, kendi içinde çelişeni reddetmektir.
        //
        // KAPSAM DAR: `payment_type` yoksa kayıt kasaya dokunmaz (kapı meşru bakiye düzeltmelerini
        // reddederdi); `reverses_entry_id` yoksa karşılaştıracak kaynak yoktur. NULL atıf da bir
        // beyandır. DB kısıtına TAŞINAMAZ: kural başka bir satıra bakar, CHECK bunu yapamaz.
        if ($entryType === 'correction' && $paymentType !== null && $reversed !== null
            && $collectedByUserId !== $reversed->collected_by_user_id) {
            throw new InvalidArgumentException(
                'kasaya dokunan düzeltme, ters çevirdiği kaydın nakit atfını taşımalı'
            );
        }

        $entry = new LedgerEntry;
        $entry->forceFill([
            'id' => $id,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'entry_type' => $entryType,
            'amount_kurus' => $amount,
            'payment_type' => $paymentType,
            'collected_by_user_id' => $collectedByUserId,
            'related_order_id' => $relatedOrderId,
            'reverses_entry_id' => $reversesEntryId,
            'note' => $payload['note'] ?? null,
            'occurred_at' => SyncPayload::zaman((string) ($event['occurred_at'] ?? '')),
            'device_id' => $event['device_id'] ?? null,
            'client_event_id' => (string) ($event['client_event_id'] ?? ''),
        ])->save();

        $changes = [SyncPayload::change('ledger_entry', $id, 'upsert', $entry)];

        // Bakiye önbelleğini DEFTERDEN yeniden kur (DECISIONS: önbellek bozulursa defterden kurulur).
        // Tüm entry_type'lar borç-deltası taşır (debit+, payment/credit/discount−); filtresiz SUM
        // net borcu verir — iskonto da bakiyeyi bu yoldan kapatır, ayrıcalıklı bir dalı yoktur.
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

    /**
     * İşaret tiple tutarlı olmalı (DECISIONS Faz 3 çift-satır): debit ≥ 0 (borç artışı),
     * payment/credit/discount ≤ 0 (borç azalışı), correction serbest (ters kayıt imzalı olabilir).
     *
     * payment_type payment VE correction'da olabilir (debit/credit/discount'ta YASAK): kasa =
     * "payment_type taşıyan kayıt = kasaya dokundu" invariant'ı (DECISIONS Faz 3). Yanlış tahsilatı
     * ters çeviren correction, ters çevirdiği payment'ın tipini taşıyarak kasayı da düzeltir
     * (bakiye + kasa birlikte).
     *
     * discount = KAPIDA KIRILAN tutar (2026-07-30). Borcu payment gibi düşürür ama kasaya HİÇ
     * girmez; payment_type yasağı bunun teminatıdır ve aşağıdaki mevcut kural onu zaten kapsar —
     * yeni tip kasa sorgularına kendiliğinden sızamaz.
     */
    private function validateLedgerEntry(string $entryType, int $amount, ?string $paymentType): void
    {
        $signOk = match ($entryType) {
            'debit' => $amount >= 0,
            'payment', 'credit', 'discount' => $amount <= 0,
            'correction' => true,
            default => throw new InvalidArgumentException("Geçersiz entry_type: {$entryType}"),
        };
        if (! $signOk) {
            throw new InvalidArgumentException("{$entryType} için tutar işareti geçersiz");
        }

        if ($paymentType !== null) {
            if (! in_array($entryType, ['payment', 'correction'], true)) {
                throw new InvalidArgumentException('payment_type yalnız payment/correction kaydında olabilir');
            }
            if (! in_array($paymentType, ['nakit', 'kart', 'havale'], true)) {
                throw new InvalidArgumentException("Geçersiz payment_type: {$paymentType}");
            }
        }
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
