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

        $settings = $existing ?? new TenantSetting;
        $settings->forceFill([
            'tenant_id' => $tenantId,
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
            'updated_occurred_at' => $occurredAt,
            'updated_device_id' => $deviceId,
        ]);
        $settings->exists = $existing !== null;
        $settings->save();

        return ['status' => 'applied', 'entity_id' => $tenantId,
            'changes' => [SyncPayload::change('tenant_settings', $tenantId, 'upsert', $settings)]];
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
            'phone' => $p['phone'] ?? null,
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
