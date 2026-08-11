<?php

namespace App\Models;

use App\Support\SiraKodu;
use Database\Factories\CustomerFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * Bayinin müşterisi. Kimlik UUIDv7, istemcide üretilir (offline-first). RLS: tenant_id policy'sine tabidir.
 *
 * balance_kurus OKUMA-MODELİ ÖNBELLEĞİdir (DECISIONS: kaynak ledger_entries). updated_occurred_at/
 * updated_device_id LWW meta'sıdır. deleted_at tombstone (fiziksel silme yok).
 * blacklisted_at kara liste damgası (null = değil); silmeden BAĞIMSIZDIR — kara listedeki müşteri
 * listede kalır, yalnız yeni sipariş alamaz.
 * favorite_product_ids sık alınan ürünlerin kimlik listesi (JSON dizi, `array` cast'i; null = yok).
 *
 * @property string $id
 * @property string $tenant_id
 * @property string $name
 * @property string|null $note
 * @property int|null $code
 * @property int $balance_kurus
 * @property list<string>|null $favorite_product_ids
 * @property Carbon $updated_occurred_at
 * @property string|null $updated_device_id
 * @property Carbon|null $blacklisted_at
 * @property Carbon|null $deleted_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
class Customer extends Model
{
    /** @use HasFactory<CustomerFactory> */
    use HasFactory, HasUuids;

    protected $fillable = [
        'id',
        'tenant_id',
        'name',
        'note',
        'code',
        'balance_kurus',
        'updated_occurred_at',
        'updated_device_id',
        'blacklisted_at',
        'favorite_product_ids',
        'deleted_at',
    ];

    protected function casts(): array
    {
        return [
            'code' => 'integer',
            'balance_kurus' => 'integer',
            'updated_occurred_at' => 'datetime',
            'blacklisted_at' => 'datetime',
            // Favori ürünler `text` kolonda JSON dizi olarak durur; cast okuma/yazmanın İKİ ucunu
            // da tek yerde çözer. Kritik olan OKUMA ucudur: senkronun istemciye yayınladığı iki
            // yol da (snapshot `->toArray()`, delta `SyncPayload::change`) cast'ten geçer, yani
            // telefona JSON metni değil GERÇEK BİR DİZİ iner. Cast olmasaydı istemci alanı bir
            // kez daha ayrıştırmak zorunda kalır ve `unit`/`name` gibi alanlarla aynı biçimde
            // okunamazdı (mobil ayrıştırıcı sözleşmesi: alan ne ise o).
            'favorite_product_ids' => 'array',
            'deleted_at' => 'datetime',
        ];
    }

    /**
     * Müşteri kodu MODEL DÜZEYİNDE atanır, senkron uygulayıcısında değil.
     *
     * Gerekçe: müşteri üç ayrı yoldan doğuyor (senkron push · demo seeder · panel/konsol
     * komutları). Kodu yalnız senkron yoluna koysaydık diğer iki yoldan doğan müşteriler
     * kodsuz kalır ve bayi listede boşluk görürdü — üstelik bu boşluk yalnız SAHADA fark
     * edilirdi. Tek kapı: `creating` olayı.
     *
     * Kod ZATEN VERİLMİŞSE dokunulmaz: geri-yükleme/aktarım senaryolarında var olan numarayı
     * korumak gerekir.
     */
    protected static function booted(): void
    {
        // tenant_id KONTROL EDİLMEZ: kolon NOT NULL'dur ve set edilmeden gelen bir müşteri
        // zaten kaydedilemez. Sessizce "kodsuz geç" demek, kaydı kurtarmaz — yalnız arızayı
        // koddan veritabanı hatasına erteler ve arada kod atlanmış olur.
        static::creating(function (self $m): void {
            $m->code ??= SiraKodu::sonraki('customers', $m->tenant_id);
        });
    }

    /** @return BelongsTo<Tenant, $this> */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    /** @return HasMany<CustomerPhone, $this> */
    public function phones(): HasMany
    {
        return $this->hasMany(CustomerPhone::class);
    }

    /** @return HasMany<CustomerAddress, $this> */
    public function addresses(): HasMany
    {
        return $this->hasMany(CustomerAddress::class);
    }
}
