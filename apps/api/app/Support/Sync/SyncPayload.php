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
}
