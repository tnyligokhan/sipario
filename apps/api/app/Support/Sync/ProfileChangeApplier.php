<?php

namespace App\Support\Sync;

use App\Models\TenantSetting;
use App\Models\User;
use Illuminate\Support\Carbon;
use InvalidArgumentException;

/**
 * Profil push olaylarını uygular: `tenant_settings` (işletme profili) ve `user_profile` (kurye/kullanıcı
 * profili). ChangeApplier bu iki entity_type'ı buraya delege eder (500 satır sınırı, CashHandover
 * simetriği). İkisi de LWW'dir — çakışma değil, birleşme yok; SON YAZAN kazanır.
 *
 * tenant_settings: payload'da id YOKTUR — anahtar oturumdaki tenant'tır (migration 601: PK = tenant_id).
 * İki cihazın çevrimdışı yazımı AYNI satırda buluşur, çakışıp reddedilemez.
 *
 * user_profile: YALNIZ name/phone/status güncellenir; kullanıcı OLUŞTURULAMAZ, rol/e-posta/parola
 * DEĞİŞTİRİLEMEZ (kimlik yüzeyi senkron yoluyla açılmaz — yetki yükseltme vektörü olurdu). Kullanıcı
 * yaratmak kimlik bilgisi (e-posta+parola) üretmeyi gerektirir; o yol panel/owner tarafındadır.
 * Değişiklik `sync_changes`'e YAZILMAZ: users delta günlüğünde hiç yoktur, her yanıttaki `team`
 * bloğuyla toptan tazelenir (DECISIONS 4b Dilim 4) — diğer cihazlara oradan iner.
 */
class ProfileChangeApplier
{
    /**
     * @param  array<string, mixed>  $event
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    public function apply(string $tenantId, array $event): array
    {
        $type = (string) ($event['entity_type'] ?? '');
        $op = (string) ($event['op'] ?? '');
        if ($op !== 'upsert') {
            throw new InvalidArgumentException("{$type} için geçersiz op: {$op}");
        }

        /** @var array<string, mixed> $payload */
        $payload = (array) ($event['payload'] ?? []);
        $occurredAt = (string) ($event['occurred_at'] ?? '');
        $deviceId = $event['device_id'] ?? null;

        return $type === 'tenant_settings'
            ? $this->applySettings($tenantId, $payload, $occurredAt, $deviceId)
            : $this->applyUserProfile($payload, $occurredAt, $deviceId);
    }

    /**
     * @param  array<string, mixed>  $p
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    private function applySettings(string $tenantId, array $p, string $occurredAt, ?string $deviceId): array
    {
        /** @var TenantSetting|null $existing */
        $existing = TenantSetting::query()->find($tenantId);

        if ($existing !== null && ! self::lwwWins($existing->updated_occurred_at, $existing->updated_device_id, $occurredAt, $deviceId)) {
            return ['status' => 'stale', 'entity_id' => $tenantId, 'changes' => []];
        }

        $cols = self::ayarKolonlari($p);

        // SÜRÜM ÇARPIKLIĞI KAPISI (2026-08-05). Bu satır en hızlı EVRİLEN senkron varlığıdır —
        // `order_code_display` (07-29), `iban` ve beş kurye yetkisi (08-04) art arda eklendi.
        // Her eklemede, o kolonu bilmeyen sahadaki build'in ilk profil yazımı yeni değerleri
        // siliyordu: IBAN boşalıyor, KAPATILMIŞ iskonto yetkisi geri açılıyor, kod tercihi
        // varsayılana dönüyordu. Artık payload'da HİÇ GEÇMEYEN anahtar mevcut değerini korur;
        // açıkça null/false gönderilen anahtar yazılır (bkz. SyncPayload::gonderilenler).
        //
        // YENİ satırda filtre YOK: korunacak değer yoktur ve kurye yetkileri NOT NULL'dur —
        // varsayılanları yazılmalıdır.
        if ($existing !== null) {
            $cols = SyncPayload::gonderilenler($cols, $p);
        }

        $settings = $existing ?? new TenantSetting;
        $settings->forceFill($cols + [
            'tenant_id' => $tenantId,
            'updated_occurred_at' => $occurredAt,
            'updated_device_id' => $deviceId,
        ]);
        $settings->exists = $existing !== null;
        $settings->save();

        return ['status' => 'applied', 'entity_id' => $tenantId,
            'changes' => [SyncPayload::change('tenant_settings', $tenantId, 'upsert', $settings)]];
    }

    /**
     * İstemciden yazılabilir profil kolonları — anahtarlar KOLON ADIYLA birebir eşleşir; sürüm
     * çarpıklığı filtresi (SyncPayload::gonderilenler) bu eşleşmeye dayanır, bozulursa koruma
     * sessizce çalışmaz olur. Türeyen/serbest adlı kolon YOKTUR.
     *
     * @param  array<string, mixed>  $p
     * @return array<string, mixed>
     */
    private static function ayarKolonlari(array $p): array
    {
        return [
            'business_name' => $p['business_name'] ?? null,
            'owner_name' => $p['owner_name'] ?? null,
            'phone' => $p['phone'] ?? null,
            'whatsapp' => $p['whatsapp'] ?? null,
            'address_text' => $p['address_text'] ?? null,
            'tax_office' => $p['tax_office'] ?? null,
            'tax_number' => $p['tax_number'] ?? null,
            'opens_at' => $p['opens_at'] ?? null,
            'closes_at' => $p['closes_at'] ?? null,
            'receipt_note' => $p['receipt_note'] ?? null,
            'iban' => self::iban($p['iban'] ?? null),
            ...self::kuryeIzinleri($p),
            // Sipariş satırındaki kod tercihi (kullanıcı isteği 2026-07-29). BEYAZ LİSTE:
            // tanınmayan bir değer varsayılana düşer — istemci sürümleri ayrışabilir ve
            // sunucuya gelen serbest metin, kararı okuyan her yüzeyi bilinmeyen bir dala sokar.
            // (Anahtar HİÇ gelmediğinde varsayılana düşmez, KORUNUR — üstteki filtre kapsar.)
            'order_code_display' => in_array($p['order_code_display'] ?? null, ['musteri', 'siparis'], true)
                ? $p['order_code_display']
                : 'musteri',
        ];
    }

    /**
     * Kurye yetki anahtarları — payload'dan yalnız BİLİNEN anahtarlar okunur, gerisi atılır.
     *
     * Değer `filter_var(..., FILTER_VALIDATE_BOOL)` ile okunur çünkü istemciler bir booleanı üç
     * ayrı biçimde gönderebilir (true / "true" / 1) ve PHP'nin gevşek dönüşümü `"false"` metnini
     * TRUE sayardı — yani "kapalı" diye gönderilen bir yetki AÇIK yazılırdı. Tanınmayan/eksik
     * değer VARSAYILANA düşer; yetki alanında "belirsiz" diye bir durum olamaz.
     *
     * NOT: buradaki "eksik", anahtar VAR ama değeri okunamadı demektir. Anahtarın HİÇ olmaması
     * ayrı bir hâldir ve varsayılana değil MEVCUT değere düşer (bkz. applySettings'teki filtre) —
     * yoksa yetkiyi bilmeyen eski bir build bayinin kapattığı yetkiyi geri açardı.
     *
     * @param  array<string, mixed>  $p
     * @return array<string, bool>
     */
    private static function kuryeIzinleri(array $p): array
    {
        $sonuc = [];
        foreach (TenantSetting::KURYE_IZINLERI as $kolon => $varsayilan) {
            $ham = $p[$kolon] ?? null;
            $sonuc[$kolon] = $ham === null
                ? $varsayilan
                : (filter_var($ham, FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) ?? $varsayilan);
        }

        return $sonuc;
    }

    /**
     * IBAN normalleştirme + uzunluk kapısı (kullanıcı isteği 2026-08-04).
     *
     * Boşluklar silinir, harfler büyütülür: bayi "TR12 3456 …" diye yazar, mesaja ve karşılaştırmaya
     * tek biçim girmeli. Boş metin `null`dur — "IBAN tanımlı değil" gerçek bir durumdur ve boş
     * dizeyle null'ın iki ayrı şey olması, hatırlatma düğmesinin kapısını belirsizleştirirdi.
     *
     * 34'ten UZUN DEĞER REDDEDİLİR, kırpılmaz: sessizce kırpmak bayinin hesap numarasını BOZAR ve
     * müşteriye yanlış hesap gönderilir — bu alanda "en iyi çaba" davranışı kabul edilemez. Kolon
     * sınırına dayanıp 22001 almak da olmaz: o hata TÜM senkron partisini düşürürdü (panel test
     * vardiyasının 22001 dersi), oysa buradan fırlayan istisna savepoint ile yalnız BU olayı
     * 'rejected' işaretler ve partinin geri kalanı yazılır.
     *
     * Mod-97 denetimi BURADA YOK, istemcidedir: geçersiz IBAN kullanıcıya formda söylenmeli,
     * senkron partisinin içinde değil.
     */
    private static function iban(mixed $ham): ?string
    {
        if ($ham === null) {
            return null;
        }
        $s = mb_strtoupper(preg_replace('/\s+/u', '', (string) $ham) ?? '');
        if ($s === '') {
            return null;
        }
        if (mb_strlen($s) > 34) {
            throw new InvalidArgumentException('iban 34 karakterden uzun olamaz');
        }

        return $s;
    }

    /**
     * @param  array<string, mixed>  $p
     * @return array{status: string, entity_id: string, changes: list<array<string, mixed>>}
     */
    private function applyUserProfile(array $p, string $occurredAt, ?string $deviceId): array
    {
        $id = (string) SyncPayload::req($p, 'id');
        /** @var User|null $user */
        $user = User::query()->find($id); // RLS kapsamlı: başka bayinin kullanıcısı bulunamaz
        if ($user === null) {
            throw new InvalidArgumentException('user_id bu bayide bulunamadı');
        }

        if (! self::lwwWins($user->updated_occurred_at, $user->updated_device_id, $occurredAt, $deviceId)) {
            return ['status' => 'stale', 'entity_id' => $id, 'changes' => []];
        }

        $status = (string) ($p['status'] ?? $user->status);
        if (! in_array($status, ['active', 'disabled'], true)) {
            throw new InvalidArgumentException("Geçersiz status: {$status}");
        }

        $user->forceFill([
            'name' => (string) ($p['name'] ?? $user->name),
            // `name`/`status` ile SİMETRİK (2026-08-05): anahtar gelmediyse mevcut değer korunur.
            // Eskiden `?? null` idi ve tek asimetrik alandı — `phone`u bilmeyen bir yüzeyin profil
            // yazımı kuryenin telefonunu siliyordu. Açıkça null gönderilirse yine temizlenir.
            'phone' => array_key_exists('phone', $p) ? $p['phone'] : $user->phone,
            'status' => $status,
            'updated_occurred_at' => $occurredAt,
            'updated_device_id' => $deviceId,
        ])->save();

        // changes BOŞ: users sync_changes delta günlüğünde yer almaz, `team` bloğuyla yayılır.
        return ['status' => 'applied', 'entity_id' => $id, 'changes' => []];
    }

    /**
     * Son yazan kazanır. Mevcut damga NULL ise (bu satır hiç senkronla yazılmamış) gelen olay kazanır.
     */
    private static function lwwWins(?Carbon $currentAt, ?string $currentDevice, string $occurredAt, ?string $deviceId): bool
    {
        if ($currentAt === null) {
            return true;
        }
        $incoming = Carbon::parse($occurredAt);
        if (! $incoming->equalTo($currentAt)) {
            return $incoming->greaterThan($currentAt);
        }

        return (string) $deviceId > (string) $currentDevice;
    }
}
