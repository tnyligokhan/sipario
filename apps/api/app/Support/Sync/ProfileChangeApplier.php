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
 * user_profile: name/phone/status + KİŞİYE ÖZEL KURYE YETKİLERİ güncellenir; kullanıcı
 * OLUŞTURULAMAZ, rol/e-posta/parola DEĞİŞTİRİLEMEZ (kimlik yüzeyi senkron yoluyla açılmaz — yetki
 * yükseltme vektörü olurdu). Kullanıcı yaratmak kimlik bilgisi (e-posta+parola) üretmeyi gerektirir;
 * o yol panel/owner tarafındadır. Yetki alanları 2026-08-10'da eklendi ve kendi kapısıyla geldi
 * (bkz. `applyUserProfile`): yazan aktör patron/operatör değilse olay reddedilir.
 * Değişiklik `sync_changes`'e YAZILMAZ: users delta günlüğünde hiç yoktur, her yanıttaki `team`
 * bloğuyla toptan tazelenir (DECISIONS 4b Dilim 4) — diğer cihazlara oradan iner.
 */
class ProfileChangeApplier
{
    /**
     * @param  User  $aktor  Push'u YAPAN oturum kullanıcısı (olayın hedefi DEĞİL). Yetki yükseltme
     *                       kapısı buna bakar; olay gövdesinden okunamaz — gövde istemcinin beyanıdır.
     */
    public function __construct(private readonly User $aktor) {}

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
        // UTC'ye normalize: `updated_occurred_at` yazımları ve LWW karşılaştırması buradan türer
        // (bkz. SyncPayload::zaman — offset'li damga timestamptz'e 3 saat kaymış yazılıyordu).
        $occurredAt = (string) SyncPayload::zaman((string) ($event['occurred_at'] ?? ''));
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
            // IBAN alıcı adı + hatırlatma şablonu (kullanıcı isteği 2026-08-06). Uzunluk kapısı
            // `iban` ile AYNI gerekçeyle burada: kolon sınırına dayanıp 22001 almak TÜM senkron
            // partisini düşürürdü, buradan fırlayan istisna yalnız BU olayı 'rejected' işaretler.
            // Kırpma YOK — yarım kalmış bir mesaj metni bayinin müşterisine yarım gider.
            'iban_owner_name' => self::sinirliMetin($p['iban_owner_name'] ?? null, 120, 'iban_owner_name'),
            'reminder_template' => self::sinirliMetin($p['reminder_template'] ?? null, 1000, 'reminder_template'),
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
     * Serbest metin kolonu için uzunluk kapısı. Boş metin `null`dur — "girilmedi" ile "boşaltıldı"
     * bu alanlarda aynı şeydir ve boş dizeyle null'ın iki ayrı durum olması, istemcideki
     * "varsayılana dön" kararını (şablon boşsa varsayılan metin) belirsizleştirirdi.
     *
     * SINIR AŞILIRSA REDDEDİLİR, KIRPILMAZ: yarım kalmış bir hatırlatma metni bayinin müşterisine
     * yarım gider ve bayi bunu ancak müşteri sorunca öğrenir. Sessiz "en iyi çaba" bu alanda da
     * kabul edilemez (IBAN'ın 34 hane kapısıyla aynı çizgi).
     *
     * YER TUTUCU DENETİMİ YOK (bilinçli): bilinmeyen `*...*` dizileri istemcide OLDUĞU GİBİ kalır —
     * WhatsApp'ta yıldız kalın yazı demektir ve bayinin kendi vurgusunu reddetmek metnini bozardı.
     */
    private static function sinirliMetin(mixed $ham, int $azami, string $alan): ?string
    {
        if ($ham === null) {
            return null;
        }
        $s = trim((string) $ham);
        if ($s === '') {
            return null;
        }
        if (mb_strlen($s) > $azami) {
            throw new InvalidArgumentException("{$alan} {$azami} karakterden uzun olamaz");
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

        // YETKİ YÜKSELTME KAPISI (2026-08-10). Yalnız payload'da GERÇEKTEN yer alan yetki anahtarları
        // toplanır; kapı da tam bu kümeye bakar. Kapı ad/telefon/status yazımını ETKİLEMEZ — kurye
        // kendi telefonunu güncelleyebilmeli, o bir yetki değil iletişim bilgisidir.
        //
        // KAPI LWW'DEN VE KULLANICI ARAMASINDAN ÖNCE: yetkisi olmayan bir aktörün yazımı, olayın
        // eski ya da hedefin var olup olmaması gibi tesadüflere bağlı olarak 'stale' değil, HER
        // ZAMAN 'rejected' dönmelidir — yoksa reddin görünürlüğü zamanlamaya kalırdı.
        $izinler = self::kisiselIzinler($p);
        if ($izinler !== [] && ! $this->aktor->role->kuryeYetkisiAtayabilir()) {
            throw new InvalidArgumentException('kurye yetkilerini yalnız patron veya operatör değiştirebilir');
        }

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

        $user->forceFill($izinler + [
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
     * KİŞİYE ÖZEL kurye yetkileri — ÜÇ DEĞERLİ okuma (2026-08-10, migration 004008).
     *
     * Dönen dizi YALNIZ payload'da GERÇEKTEN geçen anahtarları taşır; geri kalanı hiç yazılmaz.
     * Üç hâl ve üçü de ayrı şeydir:
     *
     *   anahtar HİÇ YOK        → dizide de yok → kolon MEVCUT değerini korur (sürüm çarpıklığı
     *                            kapısı; `applySettings`'teki `SyncPayload::gonderilenler` ile aynı
     *                            disiplin — yetkiyi bilmeyen eski bir build, patronun az önce
     *                            kişiselleştirdiği yetkiyi sessizce silerdi)
     *   anahtar VAR, değer null → NULL yazılır = "bayi varsayılanına dön" (devralma)
     *   anahtar VAR, bool      → kişiye özel ezme yazılır
     *
     * `filter_var(..., FILTER_VALIDATE_BOOL)` ZORUNLU: istemciler booleanı üç biçimde gönderir
     * (true / "true" / 1) ve PHP'nin gevşek dönüşümü `"false"` METNİNİ true sayardı — yani
     * "kapalı" diye gönderilen bir yetki AÇIK yazılırdı (tenant_settings tarafında aynı ders).
     *
     * OKUNAMAYAN DEĞER (`"belki"`, dizi, nesne) NULL'a düşer, yani "devral": bu alanda "belirsiz"
     * diye bir durum olamaz ve devralma güvenli taraftır — kişisel ezmeyi uydurmaktansa bayinin
     * kendi varsayılanına dönmek. Olayı reddetmek de olurdu ama tek bozuk anahtar yüzünden ad/
     * telefon/aktiflik yazımını da düşürürdü.
     *
     * @param  array<string, mixed>  $p
     * @return array<string, bool|null>
     */
    private static function kisiselIzinler(array $p): array
    {
        $sonuc = [];
        foreach (User::kuryeIzinKolonlari() as $kolon) {
            if (! array_key_exists($kolon, $p)) {
                continue; // anahtar YOK ≠ anahtar null
            }
            $ham = $p[$kolon];
            $sonuc[$kolon] = $ham === null
                ? null
                : filter_var($ham, FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE);
        }

        return $sonuc;
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
