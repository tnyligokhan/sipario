<?php

namespace App\Support\Sync;

use Illuminate\Database\Eloquent\Model;
use InvalidArgumentException;

/**
 * Senkron uygulayıcılarının paylaştığı saf yardımcılar: değişiklik betimleyicisi üretimi, zorunlu
 * payload alanı okuma ve sürüm çarpıklığı filtresi. ChangeApplier, OrderChangeApplier ve
 * ProfileChangeApplier ortak kullanır (500 satır sınırı için ayrıldı; durum tutmaz).
 *
 * ==================================================================================
 * ŞEMA EVRİMİ SÖZLEŞMESİ — MIGRATION YAZMADAN ÖNCE OKU
 * ==================================================================================
 *
 * Sunucu şeması bizim elimizde, telefondaki uygulama BAYİNİN elinde. Mağaza güncellemesi
 * günler sürer ve o boşlukta ESKİ istemci hem yazar hem okur. Bu yüzden senkron yükü bir API
 * değil, GERİYE UYUMLU BİR SÖZLEŞMEdir:
 *
 *   ✅ ALAN EKLEMEK serbest. Eski istemci bilmediği anahtarı yok sayar.
 *   ❌ ALAN KALDIRMAK / YENİDEN ADLANDIRMAK yasak.
 *   ❌ Zorunlu (non-null) bir alanı NULLABLE yapmak yasak — kaldırmakla aynı kapıdır.
 *   ❌ Alanın TİPİNİ değiştirmek yasak (string → sayı, sayı → string).
 *
 * NEDEN BU KADAR KESKİN: mobil ayrıştırıcı (`sync_engine.dart::_applyEntity`) zorunlu alanları
 * `as String` / `as num` ile okur. Alan kalkarsa/null gelirse o SATIR TypeError atar. Satır
 * bazında izolasyon 2026-08-05'te eklendi (satır atlanır, cursor ilerler, tur `veri` hatası
 * verir) — yani artık senkron ÖLMEZ; ama o satırın verisi telefona İNMEZ ve bayi eksik
 * müşteriyle/siparişle çalışır. İzolasyon bir emniyet ağıdır, sözleşmenin YERİNE GEÇMEZ.
 *
 * ZORUNLU ALANLAR (bunlara dokunmadan önce mobil ayrıştırıcıyı AÇ ve oku):
 *   her varlık: `id`, `updated_occurred_at` (LWW damgası taşıyanlarda)
 *   customer: name · customer_phone: customer_id, phone_e164, phone_last10
 *   customer_address: customer_id, address_text · product: name, unit, unit_price_kurus
 *   order: status, total_kurus, occurred_at · order_line: order_id, product_name,
 *     unit_price_kurus, qty, line_total_kurus
 *   order_event: order_id, event_type, client_event_id, occurred_at
 *   ledger_entry: entry_type, amount_kurus, client_event_id, occurred_at
 *   cash_handover: from_user_id, counted/expected/diff_kurus, occurred_at
 *   exempt_number: phone_e164, phone_last10 · call_log: phone_e164, phone_last10, direction
 *   day_closing: scope, occurred_at · team bloğu: id, name, role, status
 *   zarf: `mode` (snapshot|delta) — bu alan kalkarsa pull HİÇ çözülemez.
 *   (`tenant_settings` istisnadır: TÜM alanları null-güvenli okunur.)
 *
 * MIGRATION YAZARKEN SOR:
 *  1. Bu migration bir senkron varlığının KOLONUNU kaldırıyor/adlandırıyor/nullable yapıyor mu?
 *     Evetse: sahadaki en eski istemci bu alanı ZORUNLU okuyor mu? (Yukarıdaki liste + mobil
 *     ayrıştırıcı.) Okuyorsa yol şudur: önce kolonu yayında TUT ve istemciyi null-güvenli yapan
 *     sürümü yayınla, o sürüm sahaya YAYILDIKTAN SONRA kaldır. İki adım, tek vardiya değil.
 *  2. Bu migration mevcut satırların DEĞERİNİ değiştiriyor mu? Evetse `sync_changes`e delta
 *     düşürmeli — yoksa değişiklik telefona HİÇ ulaşmaz (2026-07-29 dersi,
 *     `emit_code_sync_changes`). "Sunucuda doğru duran ama inmeyen alan YOKTUR."
 *  3. Yeni kolon bir senkron varlığına mı ekleniyor? O zaman ÜÇ yer birlikte güncellenir:
 *     uygulayıcının kolon listesi, mobil ayrıştırıcı (varsayılanlı okuma) ve mobil şema
 *     migration'ı. Eksik kalan yer sessizdir — hata vermez, alan hiç görünmez.
 *  4. Kolon `tenants` üzerinde mi? `tenants` senkron varlığı DEĞİLDİR; telefona ulaşması için
 *     `SyncService::subscriptionPayload` bloğuna eklenmesi gerekir (delta değil, tam durum).
 *  5. Yeni bir CHECK/uzunluk/tip kısıtı mı geliyor? İstemcinin gönderdiği veriden doğabilecek
 *     SQLSTATE'ler `SyncService::CLIENT_DATA_SQLSTATES` beyaz listesinde olmalı — yoksa 500
 *     döner ve kuyruk sonsuza dek kilitlenir (zehirli hap).
 */
final class SyncPayload
{
    /**
     * Değişiklik betimleyicisi: sync_changes satırına yazılacak materyalize snapshot.
     * refresh() DB tarafı varsayılanlarını (ör. balance_kurus, created_at useCurrent) yakalar.
     *
     * @return array{entity_type: string, entity_id: string, op: string, payload: array<string, mixed>}
     */
    public static function change(string $entityType, string $entityId, string $op, Model $model): array
    {
        return [
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'op' => $op,
            'payload' => $model->refresh()->attributesToArray(),
        ];
    }

    /**
     * Zorunlu payload alanı; yoksa istemci-kaynaklı geçersizlik (savepoint ile reddedilir).
     *
     * @param  array<string, mixed>  $arr
     */
    public static function req(array $arr, string $key): mixed
    {
        return $arr[$key] ?? throw new InvalidArgumentException("payload.{$key} gerekli");
    }

    /**
     * SÜRÜM ÇARPIKLIĞI KAPISI — **anahtar YOK ≠ anahtar null.**
     *
     * MEVCUT bir satıra uygulanacak kolon kümesinden, payload'da HİÇ GEÇMEYEN anahtarları düşürür;
     * o kolonlar sunucudaki değerini korur. Payload'da AÇIKÇA null gelen anahtar düşmez — yazılır.
     *
     * NEDEN GEREKLİ: LWW upsert satırın TAMAMINI yazar. Bir migration yeni kolon eklediğinde
     * sahadaki eski istemci o anahtarı göndermez; `$p['yeni'] ?? null` yazan bir uygulayıcıda bu,
     * "kullanıcı burayı boşalttı" diye okunur ve taze `occurred_at` LWW'yi kazandığı için YENİ
     * cihazdan/panelden girilmiş değeri SESSİZCE SİLER. Hata yok, günlük yok, alan boş. Mağaza
     * güncellemesi bayinin elinde olduğu için bu boşluk günlerce açık kalır.
     *
     * NEDEN "AÇIK NULL"U AYIRIYORUZ: "temizle" niyeti ifade edilebilir kalmalı — kara listeden
     * çıkarma, IBAN'ı silme, yetkiyi kapatma. Ayrımı DEĞERE değil anahtarın VARLIĞINA bağlamak
     * ikisini de mümkün kılar: yokluk "bilmiyorum", açık null "boşalt" demektir.
     *
     * MEVCUT İSTEMCİLERİ ETKİLEMEZ: mobil depolar (customer/product/tenant_settings…) payload'ı
     * sabit anahtar kümesiyle kurar, yani her zaman TAM satır gönderir — onlar için her anahtar
     * zaten mevcuttur ve bu filtre hiçbir şeyi düşürmez (SurumCarpikligiTest bunu da kilitler).
     *
     * [$tureyen] payload anahtarı OLMAYAN ama başka bir alandan hesaplanan kolonlar içindir
     * (ör. `phone_last10` `phone_e164`den türer; call_log'un `occurred_at`/`device_id`si olay
     * zarfından gelir). Onlar filtreye girmez, yoksa numara güncellenirken eşleşme anahtarı
     * eski değerde donardı.
     *
     * @param  array<string, mixed>  $cols  uygulanacak kolonlar (varsayılanları hesaplanmış hâlde)
     * @param  array<string, mixed>  $payload  istemcinin gönderdiği ham payload
     * @param  list<string>  $tureyen  payload'dan bağımsız hesaplanan kolon adları
     * @return array<string, mixed>
     */
    public static function gonderilenler(array $cols, array $payload, array $tureyen = []): array
    {
        return array_filter(
            $cols,
            fn (string $kolon) => array_key_exists($kolon, $payload) || in_array($kolon, $tureyen, true),
            ARRAY_FILTER_USE_KEY
        );
    }
}
