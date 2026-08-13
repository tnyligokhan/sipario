<?php

namespace App\Support\Sync;

use App\Models\CashHandover;
use App\Models\User;
use InvalidArgumentException;

/**
 * Kasa devri push olaylarını uygular (APPEND cash_handovers). ChangeApplier 'cash_handover'
 * entity_type'ını buraya delege eder (OrderChangeApplier simetriği, 500 satır sınırı).
 *
 * Kayıt istemcide hesaplanmış bir MUTABAKAT SNAPSHOT'ıdır: counted/expected/diff olduğu gibi saklanır
 * (amount_kurus gibi istemciye güvenilir, kanıt append-only durur). tenant_id gövdeden alınmaz;
 * from_user_id / to_user_id / reverses_handover_id yazımdan ÖNCE RLS kapsamında doğrulanır — başka
 * bayinin kullanıcısına ya da devrine kayıt bağlanamaz (kırmızı çizgi #1, savepoint zehirlenmesini
 * önler).
 *
 * İPTAL de bir devirdir: `reverses_handover_id` dolu, `counted_cash_kurus` negatif bir TERS SATIR
 * (2026-08-13). Silme yoktur; ayrıntılı gerekçe aşağıda, alanın doğrulandığı yerde.
 */
class CashHandoverChangeApplier
{
    /**
     * @param  array<string, mixed>  $event
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    public function apply(string $tenantId, array $event): array
    {
        $op = (string) ($event['op'] ?? '');
        if ($op !== 'handover') {
            throw new InvalidArgumentException("Geçersiz kasa devri op: {$op}");
        }

        /** @var array<string, mixed> $payload */
        $payload = (array) ($event['payload'] ?? []);
        $id = (string) SyncPayload::req($payload, 'id');
        if (CashHandover::query()->find($id) !== null) {
            // AYNI ID YENİDEN GELDİ → 'duplicate' (SESSİZ YAKINSAMA), red DEĞİL.
            //
            // ASIL KAPAK BURASIDIR, `day_closings`te değil. İki cihaz aynı kuryenin aynı gününü
            // kapattığında kapanış sunucuya İKİ AYRI OLAY olarak gider (devir önce, arşiv sonra —
            // AraTahsilatSyncTest bu sırayı yazar) ve her olay kendi savepoint'indedir. Tekilliği
            // yalnız `day_closings`e koymak devri commit edip arşivi reddederdi: ortada SAHİPSİZ
            // bir devir kalır, o da "kapanışa bağlı olmayan devir" tanımı gereği ARA TAHSİLATA
            // terfi eder ve çift sayılan para (`teslimEdilenNakit`) hiç düzelmezdi. Para hatası
            // ekran özetinde değil PARANIN DEFTERİNDE kapanır.
            //
            // Kapanış devrinin id'si de kapanışla aynı çekirdekten TÜRETİLİR, yani aynı id = aynı
            // mantıksal devir.
            //
            // NEDEN RED DEĞİL: `rejected` istemcide KARANTİNAdır; iyi huylu bir tekrar elle
            // incelemeye kalırdı. 'duplicate' → `acked`, kayıp yok (kayıt zaten sunucuda).
            //
            // ⚠️ BEDELİ AÇIK VE KABUL EDİLDİ (lead kararı 2026-08-06): İKİNCİ denemenin SAYILAN
            // tutarı kayda GEÇMEZ — ilk mutabakat kazanır.
            //
            // ARA TAHSİLATLAR ETKİLENMEZ: id'leri türetilmez (rastgele kalır), yani "gün içinde
            // çok kez kasa devri" serbestliği korunur — kısıt yalnız KAPANIŞ devrindedir.
            //
            // ⚠️ BU DAL RLS'E BAĞLIDIR: `id` GLOBAL primary key olduğu için başka bir bayinin
            // kaydı da aynı id'yi taşıyabilir ve onu 'duplicate' saymak B'nin devrini A'nınki
            // yüzünden sessizce yutmak olurdu. `find()` RLS altında koştuğu için başka kiracının
            // satırı görünmez → null → INSERT → 23505 → GÖRÜNÜR red. Gerekçenin tamamı ve zinciri
            // kilitleyen test için bkz. `DayClosingChangeApplier` (aynı dal, aynı bağımlılık).
            return ['status' => 'duplicate', 'entity_id' => $id, 'changes' => []];
        }

        $fromUserId = (string) SyncPayload::req($payload, 'from_user_id');
        if (! User::query()->whereKey($fromUserId)->exists()) {
            throw new InvalidArgumentException('from_user_id bu bayide bulunamadı');
        }

        $toUserId = isset($payload['to_user_id']) ? (string) $payload['to_user_id'] : null;
        if ($toUserId !== null && ! User::query()->whereKey($toUserId)->exists()) {
            throw new InvalidArgumentException('to_user_id bu bayide bulunamadı');
        }

        // ───────────────────────────────────────────────────────────────────────────────────────
        // ARA TAHSİLAT İPTALİ (kullanıcı kararı 2026-08-13) — `reverses_handover_id`.
        //
        // İptal YENİ BİR OP DEĞİLDİR: aynı `handover` op'una opsiyonel bir alan eklendi. Ayrı bir op
        // açmak (`handover_cancel` gibi) eski istemcide TANINMAYAN op demekti ve EventValidator
        // partiyi olay bazında reddederdi; alan eklemek ise sözleşmenin serbest bıraktığı tek yön
        // (bkz. SyncPayload şema evrimi başlığı). Ters satır, tablonun kendisine yazılan NORMAL bir
        // devirdir — `counted_cash_kurus` negatif — yani hiçbir mevcut okuma yolu değişmez: kasa
        // toplamları zaten SUM ile türetiliyor, iptal kendiliğinden düşer.
        //
        // ① HEDEF BU BAYİDE OLMALI. `from_user_id` doğrulamasıyla AYNI titizlik: sorgu RLS altında
        //    koştuğu için bulunamama hem "hiç yok" hem "başka bayinin" hâlini kapsar (kırmızı
        //    çizgi #1). DB'deki bileşik self-FK de aynı şeyi söyler ama oradan gelen 23503 istemciye
        //    ayırt edilemez bir 'invalid_data' olarak döner; buradaki açık istisna hem GEREKÇEYİ
        //    taşır hem `SyncRejectionLog`da teşhis edilebilir bir iz bırakır.
        //
        // ② ÇİFT İPTAL REDDEDİLİR. Bir devir en fazla BİR KEZ geri alınabilir. Gerekçe para
        //    aritmetiğidir: iki ters satır aynı tahsilatı işaret ederse kasaya para İKİ KEZ geri
        //    döner ve tablo append-only olduğu için bu hata bir daha DÜZELMEZ — yalnız üçüncü bir
        //    telafi kaydıyla örtülür, ki o da bayinin defteriyle tutmayan bir kasa demektir
        //    (BRIEF: "rakamlar defterle kuruşu kuruşuna tutmazsa ürüne güven ölür").
        //    ASIL KAPAK BURASI VE VERİTABANIDIR, istemci değil: iki cihaz çevrimdışıyken aynı
        //    tahsilatı iptal edebilir ve istemcideki düğme kapısı birbirlerini göremez. Buradaki
        //    kontrol GÖRÜNÜR ve gerekçeli bir red üretir; eşzamanlı iki isteğin ikisi de "iptal yok"
        //    okuyabildiği yarışı ise migration 004011'deki kısmi unique indeks kapatır (23505 →
        //    yine 'rejected', çünkü CLIENT_DATA_SQLSTATES beyaz listesinde).
        //
        // ⚠️ NEDEN 'duplicate' DEĞİL 'rejected': yukarıdaki `find($id)` dalı AYNI OLAYIN tekrarıdır
        //    (iyi huylu, sessiz yakınsar). Burası FARKLI id'li İKİNCİ BİR İPTAL olayıdır — kullanıcı
        //    niyeti farklıdır ve sessizce yutulursa cihaz "iptal ettim" sanır. Karantina doğrudur.
        //
        // KAPSAM DIŞI, BİLİNÇLİ: (a) tutarın işaretini/büyüklüğünü doğrulamıyoruz — sunucu bu
        // tablonun aritmetiğine karışmaz, counted/expected/diff İSTEMCİ SNAPSHOT'ıdır (DECISIONS
        // Faz 4, AraTahsilatSyncTest kilitliyor); işaret kuralını buraya koymak "kalan nakit"
        // tanımını ikinci bir yerde tanımlamak olurdu. (b) İptalin kendisinin iptal edilmesi
        // (ters satırı hedef gösteren üçüncü satır) yasaklanmadı: aritmetiği tutarlıdır (geri alınan
        // para yeniden sayılır) ve kısmi unique indeks yine tek kez olmasını garanti eder.
        // (c) Kapanışa BAĞLI bir devrin iptali de yasaklanmadı — kural `day_closings`e bakmayı
        // gerektirir, istemci o düğmeyi yalnız ara tahsilatta gösterir ve yanlışlıkla yazılsa bile
        // kayıp yoktur (her iki satır da append-only durur, mutabakat farkı GÖRÜNÜR kalır).
        $reversesId = isset($payload['reverses_handover_id'])
            ? (string) $payload['reverses_handover_id']
            : null;

        if ($reversesId !== null) {
            if (CashHandover::query()->find($reversesId) === null) {
                throw new InvalidArgumentException('reverses_handover_id bu bayide bulunamadı');
            }

            if (CashHandover::query()->where('reverses_handover_id', $reversesId)->exists()) {
                throw new InvalidArgumentException('bu kasa devri zaten iptal edilmiş');
            }
        }

        $handover = new CashHandover;
        $handover->forceFill([
            'id' => $id,
            'tenant_id' => $tenantId,
            'from_user_id' => $fromUserId,
            'to_user_id' => $toUserId,
            'reverses_handover_id' => $reversesId,
            'counted_cash_kurus' => (int) SyncPayload::req($payload, 'counted_cash_kurus'),
            'expected_cash_kurus' => (int) SyncPayload::req($payload, 'expected_cash_kurus'),
            'diff_kurus' => (int) SyncPayload::req($payload, 'diff_kurus'),
            'period_start' => SyncPayload::zaman($payload['period_start'] ?? null),
            'occurred_at' => SyncPayload::zaman((string) ($event['occurred_at'] ?? '')),
            'device_id' => $event['device_id'] ?? null,
            'note' => $payload['note'] ?? null,
        ])->save();

        return ['status' => 'applied', 'entity_id' => $id,
            'changes' => [SyncPayload::change('cash_handover', $id, 'upsert', $handover)]];
    }
}
