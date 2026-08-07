<?php

namespace App\Support\Sync;

use Illuminate\Support\Facades\Log;

/**
 * Reddedilen senkron olaylarının sunucu günlüğü — ve KVKK sözleşmesinin TEK yeri (500 satır
 * sınırı için SyncService'ten ayrıldı; durum tutmaz).
 *
 * İKİ KURAL, ikisi de pazarlıksız:
 *
 *  1. REDDETME SESSİZ OLMAZ. Sessizce reddedilen olay, sahada "kaydettim ama yok" olarak görünür
 *     ve destek bunu telefonda teşhis edemez. Her red bir satır, her parti bir özet bırakır.
 *
 *  2. GÜNLÜĞE PII GİRMEZ. Yazılan alanlar YALNIZ: client_event_id, entity_type, op, sebep kodu.
 *     Payload içeriği, tutar, ad/telefon ve serbest metin `message` ASLA yazılmaz — reddin sebebini
 *     anlamak için kimliğe ve koda ihtiyaç var, müşterinin adına yok. Buraya alan eklemeden önce
 *     "bu değer bir bayinin müşterisine ait olabilir mi?" diye sorun.
 */
final class SyncRejectionLog
{
    /** Tek olayın reddi. */
    public static function event(string $clientEventId, mixed $entityType, mixed $op, string $reason): void
    {
        Log::warning('sync.event_rejected', [
            'client_event_id' => self::kisa($clientEventId),
            'entity_type' => self::kisa($entityType),
            'op' => self::kisa($op),
            'reason' => $reason,
        ]);
    }

    /**
     * Parti özeti: kaç olay, hangi sebeplerle. Filoya yayılmış bir zehirli hap (ör. artık
     * desteklenmeyen bir entity_type) tek tek satırlarda değil, burada toplu olarak görünür.
     *
     * @param  list<array<string, mixed>>  $results
     */
    public static function batch(array $results): void
    {
        /** @var array<string, int> $sebepler */
        $sebepler = [];
        foreach ($results as $sonuc) {
            $reason = $sonuc['reason'] ?? null;
            if (($sonuc['status'] ?? null) !== 'rejected' || ! is_string($reason)) {
                continue;
            }
            $sebepler[$reason] = ($sebepler[$reason] ?? 0) + 1;
        }

        if ($sebepler !== []) {
            Log::warning('sync.push_rejected', ['count' => array_sum($sebepler), 'reasons' => $sebepler]);
        }
    }

    /** Skaler değilse boş, uzunsa kırpılır (günlük şişirme + enjeksiyon). */
    private static function kisa(mixed $value): string
    {
        return is_scalar($value) ? mb_substr((string) $value, 0, 40) : '';
    }
}
