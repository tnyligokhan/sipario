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
            // AYNI ID YENİDEN GELDİ → 'duplicate' (SESSİZ YAKINSAMA), red DEĞİL.
            //
            // Kapanışın id'si (tenant|scope|user_id|TR gün) çekirdeğinden TÜRETİLİR (teslim
            // idempotensiyle aynı uuid5 kalıbı), yani aynı id = aynı MANTIKSAL olay. İki cihaz
            // aynı kuryenin aynı gününü kapatırsa ikincisi buraya düşer.
            //
            // NEDEN RED DEĞİL: `rejected` istemcide KARANTİNAdır (outbox satırı elle incelemeye
            // kalır). İki kişinin aynı hesabı kapatması nadir bir OPERASYON hatasıdır, kötü niyet
            // değil; iyi huylu bir tekrarın kuyruğu rehin alması bu deponun çıktığı hata sınıfıdır.
            // 'duplicate' istemcide `acked` olur: satır temizlenir, veri kaybı yoktur (kayıt zaten
            // sunucuda duruyor) ve parti akmaya devam eder.
            //
            // ⚠️ BEDELİ AÇIK VE KABUL EDİLDİ (lead kararı 2026-08-06): İKİNCİ denemenin SAYILAN
            // tutarı kayda GEÇMEZ — ilk mutabakat kazanır. İki cihaz farklı sayım girmişse
            // ikincisi sessizce düşer. Kayıt append-only olduğu için düzeltmenin yolu yenisini
            // yazmak değil, ilkini okumaktır; ikinci sayımı da saklamak "aynı gün iki kapanış"
            // demek olurdu ve düzeltilen para hatası tam olarak buydu.
            //
            // ARA TAHSİLAT BU YOLDAN ETKİLENMEZ: onların id'si türetilmez (rastgele kalır), yani
            // gün içinde çok kez devir alınabilmesi bozulmaz — kısıt yalnız KAPANIŞ devrindedir.
            //
            // ⚠️ BU DAL RLS'E BAĞLIDIR ve öyle kalmalı. `id` GLOBAL primary key'dir
            // (`unique(tenant_id,id)` onun ÜSTÜNE ek kısıttır), yani başka bir bayinin kaydı da
            // teorik olarak aynı id'yi taşıyabilir. Onu 'duplicate' saymak B bayisinin kapanışını
            // A'nınki yüzünden SESSİZCE yutmak olurdu (kırmızı çizgi #1'in kenarı). Bu olmuyor
            // çünkü aşağıdaki `find()` RLS ALTINDA koşuyor: `tenant_isolation` politikası (cmd=ALL)
            // + FORCE ROW LEVEL SECURITY, applier RLS'li `pgsql` bağlantısında ve
            // `ResolveTenantContext` `app.tenant_id`yi kuruyor. Başka kiracının satırı GÖRÜNMEZ →
            // `find()` null → INSERT → global PK ihlali (23505) → olay bazında GÖRÜNÜR red.
            // Applier owner bağlantısına taşınırsa ya da politikadan SELECT düşerse bu dal sessiz
            // yutmaya döner — `KapanisYakinsamaTest::baska_kiracinin_ayni_idsi_duplicate_SAYILMAZ`
            // o zinciri uçtan uca kilitler.
            return ['status' => 'duplicate', 'entity_id' => $id, 'changes' => []];
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

        // ── KAPANIŞI GERİ ALMA (2026-08-18) — `reverses_closing_id` ─────────────────────────
        //
        // `CashHandoverChangeApplier`daki iptal dalının birebir eşi. Üç kapı, üçü de FARKLI bir
        // sessiz bozulmayı kapatıyor:
        //
        //  1. HEDEF VAR MI — RLS kapsamında sorulur, yani başka bayinin kapanışı GÖRÜNMEZ ve
        //     "bulunamadı" reddi alır (kırmızı çizgi #1). FK son kapıdır; bu, GÖRÜNÜR reddi
        //     üretir (istemcide karantina) — ikisi farklı şeyleri korur.
        //  2. ZATEN GERİ ALINMIŞ MI — kısmi unique indeks bunu DB'de de kapatıyor ama indeks
        //     23505 üretir ve olay 'rejected' olur; buradaki kontrol AYNI sonucu TÜRKÇE bir
        //     gerekçeyle verir. İndeks yarışı kapatır, bu kapı hatayı AÇIKLAR.
        //  3. GERİ ALMANIN GERİ ALINMASI YASAK — ters satırın tersi, "kapanış yeniden geçerli"
        //     demek olurdu ve o an arşivde iki geçerli kapanış görünürdü. Düzeltmenin yolu
        //     yeniden KAPATMAKTIR (yeni bir kapanış satırı), eskiyi diriltmek değil.
        $reversesId = isset($payload['reverses_closing_id'])
            ? (string) $payload['reverses_closing_id']
            : null;

        if ($reversesId !== null) {
            $hedef = DayClosing::query()->find($reversesId);
            if ($hedef === null) {
                throw new InvalidArgumentException('reverses_closing_id bu bayide bulunamadı');
            }
            if ($hedef->reverses_closing_id !== null) {
                throw new InvalidArgumentException('bu satır zaten bir geri alma kaydı; geri alınamaz');
            }
            if (DayClosing::query()->where('reverses_closing_id', $reversesId)->exists()) {
                throw new InvalidArgumentException('bu kapanış zaten geri alınmış');
            }
            // KAPSAM HEDEFLE AYNI OLMAK ZORUNDA: gün kapanışını bir kurye kapanışıyla geri almak,
            // arşivde birbirini işaret eden ama aynı hesabı konuşmayan iki satır bırakırdı.
            if ($hedef->scope !== $scope || $hedef->user_id !== $userId) {
                throw new InvalidArgumentException('geri alma kaydı, kapanışla aynı kapsamda olmalı');
            }
        }

        $closing = new DayClosing;
        $closing->forceFill([
            'id' => $id,
            'tenant_id' => $tenantId,
            'scope' => $scope,
            'user_id' => $userId,
            'reverses_closing_id' => $reversesId,
            'period_start' => SyncPayload::zaman($payload['period_start'] ?? null),
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
            'occurred_at' => SyncPayload::zaman((string) ($event['occurred_at'] ?? '')),
            'device_id' => $event['device_id'] ?? null,
        ])->save();

        return ['status' => 'applied', 'entity_id' => $id,
            'changes' => [SyncPayload::change('day_closing', $id, 'upsert', $closing)]];
    }
}
