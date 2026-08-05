<?php

namespace App\Support\Sync;

use Illuminate\Database\Eloquent\Model;
use InvalidArgumentException;

/**
 * Senkron uygulayıcılarının paylaştığı iki saf yardımcı: değişiklik betimleyicisi üretimi ve
 * zorunlu payload alanı okuma. ChangeApplier ve OrderChangeApplier ortak kullanır (500 satır
 * sınırı için ayrıldı; durum tutmaz).
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
