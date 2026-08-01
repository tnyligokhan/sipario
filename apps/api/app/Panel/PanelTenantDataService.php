<?php

namespace App\Panel;

use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Bir bayinin İŞ VERİSİNİ okuyan panel servisi (5c-3 · D2). SALT-OKUNUR — `pgsql_panel` rolüyle
 * (BYPASSRLS) okunur; bu rolün iş tablolarında INSERT/UPDATE/DELETE grant'i YOKTUR (migration 504),
 * yani bu sınıftan yanlışlıkla bile yazılamaz. Yazma yolu ayrıdır (PanelWriteService, D3).
 *
 * KIRMIZI ÇİZGİ #1: panel BYPASSRLS ile TÜM bayileri görür → buradaki HER sorgu `tenant_id` ile
 * AÇIKÇA filtrelenir; RLS yedeği YOKTUR, sızıntıyı yalnız bu filtreler önler. Alt sorgular da
 * `tenant_id`yi kolon eşleşmesiyle taşır (yalnız customer_id eşlemek başka bayinin satırını
 * getirebilirdi — id'ler global tekil olsa da bu güvence şemaya değil şansa dayanırdı).
 *
 * KVKK: bu ekranlar müşteri adı/telefonu/adresi GÖSTERİR. Bu, 2026-08-01 kararının bilinçli
 * sonucudur (destek ekibi bayinin verisini görmeden onboarding/destek yapamıyordu). Sınır şudur:
 * veri EKRANDA gösterilir, `panel_audit`e DEĞER olarak yazılmaz (denetim kaydı yalnız eylem + id).
 */
class PanelTenantDataService
{
    public function __construct(private readonly string $connection = 'pgsql_panel') {}

    /**
     * Müşteri listesi: kod, ad, bakiye, birincil telefon, son sipariş. Arama ada, koda ve
     * TELEFONUN SON 10 HANESİNE bakar — destek çağrısında elde çoğu zaman yalnız numara olur.
     *
     * @return LengthAwarePaginator<int, \stdClass>
     */
    public function customers(string $tenantId, string $arama = '', bool $silinmisler = false, int $perPage = 20, string $pageName = 'msayfa'): LengthAwarePaginator
    {
        $q = DB::connection($this->connection)->table('customers as c')
            ->where('c.tenant_id', $tenantId)
            ->select('c.id', 'c.code', 'c.name', 'c.note', 'c.balance_kurus', 'c.blacklisted_at', 'c.deleted_at')
            ->selectSub($this->birincilTelefon(), 'telefon')
            ->selectSub($this->sonSiparis(), 'son_siparis');

        if (! $silinmisler) {
            $q->whereNull('c.deleted_at');
        }

        $this->musteriArama($q, $tenantId, $arama);

        return $q->orderBy('c.name')->paginate($perPage, ['*'], $pageName);
    }

    /**
     * Tek müşterinin destek görünümü: kayıt + telefonlar + adresler + son 5 sipariş + bakiye.
     * Yoksa null (başka bayinin müşterisi de burada null döner — tenant_id filtresi yüzünden).
     *
     * @return array{musteri: \stdClass, telefonlar: Collection<int, \stdClass>, adresler: Collection<int, \stdClass>, siparisler: Collection<int, \stdClass>}|null
     */
    public function customerDetail(string $tenantId, string $customerId): ?array
    {
        $musteri = DB::connection($this->connection)->table('customers')
            ->where('tenant_id', $tenantId)->where('id', $customerId)->first();

        if ($musteri === null) {
            return null;
        }

        return [
            'musteri' => $musteri,
            'telefonlar' => DB::connection($this->connection)->table('customer_phones')
                ->where('tenant_id', $tenantId)->where('customer_id', $customerId)
                ->whereNull('deleted_at')->orderByDesc('is_primary')->get(),
            'adresler' => DB::connection($this->connection)->table('customer_addresses')
                ->where('tenant_id', $tenantId)->where('customer_id', $customerId)
                ->whereNull('deleted_at')->orderByDesc('is_primary')->get(),
            'siparisler' => DB::connection($this->connection)->table('orders')
                ->where('tenant_id', $tenantId)->where('customer_id', $customerId)
                ->whereNull('deleted_at')
                ->select('id', 'code', 'status', 'total_kurus', 'payment_type', 'occurred_at')
                ->orderByDesc('occurred_at')->limit(5)->get(),
        ];
    }

    /**
     * Sipariş listesi (SALT-OKUNUR — panelden sipariş yazılmaz, DECISIONS 2026-08-01).
     * Süzgeçler: durum (open/delivered/cancelled) + tarih aralığı (TR günü, +03:00 sabit).
     *
     * @param  array{durum?: string, baslangic?: string, bitis?: string}  $filtre
     * @return LengthAwarePaginator<int, \stdClass>
     */
    public function orders(string $tenantId, array $filtre = [], int $perPage = 20, string $pageName = 'ssayfa'): LengthAwarePaginator
    {
        $q = DB::connection($this->connection)->table('orders as o')
            ->where('o.tenant_id', $tenantId)
            ->whereNull('o.deleted_at')
            ->leftJoin('customers as c', function ($j) {
                $j->on('c.id', '=', 'o.customer_id')->on('c.tenant_id', '=', 'o.tenant_id');
            })
            ->leftJoin('users as u', function ($j) {
                $j->on('u.id', '=', 'o.assigned_user_id')->on('u.tenant_id', '=', 'o.tenant_id');
            })
            ->select('o.id', 'o.code', 'o.status', 'o.total_kurus', 'o.payment_type', 'o.occurred_at',
                'c.name as musteri', 'c.code as musteri_kodu', 'u.name as kurye');

        if (($filtre['durum'] ?? '') !== '') {
            $q->where('o.status', $filtre['durum']);
        }
        // Tarih sınırı TR gününe göre: kullanıcı "01.08" yazdığında Türkiye'nin 1 Ağustos'unu kasteder,
        // UTC'ninkini değil. DayEndRepository/PanelStatsService ile aynı sabit ofset (DST yok).
        if (($filtre['baslangic'] ?? '') !== '') {
            $q->whereRaw("(o.occurred_at AT TIME ZONE 'Etc/GMT-3')::date >= ?", [$filtre['baslangic']]);
        }
        if (($filtre['bitis'] ?? '') !== '') {
            $q->whereRaw("(o.occurred_at AT TIME ZONE 'Etc/GMT-3')::date <= ?", [$filtre['bitis']]);
        }

        return $q->orderByDesc('o.occurred_at')->paginate($perPage, ['*'], $pageName);
    }

    /**
     * Defter hareketleri (SALT-OKUNUR — append-only tablo; panelden para kaydı YAZILMAZ).
     *
     * @param  array{tip?: string, baslangic?: string, bitis?: string}  $filtre
     * @return LengthAwarePaginator<int, \stdClass>
     */
    public function ledger(string $tenantId, array $filtre = [], int $perPage = 30, string $pageName = 'dsayfa'): LengthAwarePaginator
    {
        $q = DB::connection($this->connection)->table('ledger_entries as l')
            ->where('l.tenant_id', $tenantId)
            ->leftJoin('customers as c', function ($j) {
                $j->on('c.id', '=', 'l.customer_id')->on('c.tenant_id', '=', 'l.tenant_id');
            })
            ->select('l.id', 'l.entry_type', 'l.amount_kurus', 'l.payment_type', 'l.note',
                'l.occurred_at', 'l.related_order_id', 'c.name as musteri', 'c.code as musteri_kodu');

        if (($filtre['tip'] ?? '') !== '') {
            $q->where('l.entry_type', $filtre['tip']);
        }
        if (($filtre['baslangic'] ?? '') !== '') {
            $q->whereRaw("(l.occurred_at AT TIME ZONE 'Etc/GMT-3')::date >= ?", [$filtre['baslangic']]);
        }
        if (($filtre['bitis'] ?? '') !== '') {
            $q->whereRaw("(l.occurred_at AT TIME ZONE 'Etc/GMT-3')::date <= ?", [$filtre['bitis']]);
        }

        return $q->orderByDesc('l.occurred_at')->paginate($perPage, ['*'], $pageName);
    }

    /**
     * Defter özeti (bakiye/kasa değil — hareket sayısı ve tip kırılımı; kasa hesabı mobilin işi).
     *
     * @return Collection<int, \stdClass>
     */
    public function ledgerOzet(string $tenantId): Collection
    {
        return DB::connection($this->connection)->table('ledger_entries')
            ->where('tenant_id', $tenantId)
            ->selectRaw('entry_type, count(*) as adet, sum(amount_kurus) as toplam')
            ->groupBy('entry_type')->orderBy('entry_type')->get();
    }

    /**
     * Ürün kataloğu.
     *
     * @return LengthAwarePaginator<int, \stdClass>
     */
    public function products(string $tenantId, string $arama = '', bool $silinmisler = false, int $perPage = 20, string $pageName = 'usayfa'): LengthAwarePaginator
    {
        $q = DB::connection($this->connection)->table('products')
            ->where('tenant_id', $tenantId)
            ->select('id', 'name', 'unit_price_kurus', 'unit', 'barcode', 'is_active', 'deleted_at');

        if (! $silinmisler) {
            $q->whereNull('deleted_at');
        }
        if ($arama !== '') {
            $q->where(function ($w) use ($arama) {
                $w->where('name', 'ilike', '%'.$arama.'%')->orWhere('barcode', 'ilike', '%'.$arama.'%');
            });
        }

        return $q->orderBy('name')->paginate($perPage, ['*'], $pageName);
    }

    /**
     * Bu bayiye ait panel denetim kayıtları — kim, ne zaman, ne yaptı. `admin_users` ile
     * birleştirilir ki satırda uuid değil isim görünsün (destek ekibinin okuyacağı şey budur).
     *
     * @return LengthAwarePaginator<int, \stdClass>
     */
    public function audit(string $tenantId, int $perPage = 30, string $pageName = 'ksayfa'): LengthAwarePaginator
    {
        return DB::connection($this->connection)->table('panel_audit as a')
            ->where('a.tenant_id', $tenantId)
            ->leftJoin('admin_users as au', 'au.id', '=', 'a.admin_user_id')
            ->select('a.id', 'a.action', 'a.detail', 'a.created_at', 'au.name as admin', 'au.email as admin_email')
            ->orderByDesc('a.created_at')
            ->paginate($perPage, ['*'], $pageName);
    }

    /**
     * Tek ürün — düzenleme formunu doldurmak için. Başka bayinin ürünü SORULSA da null döner
     * (tenant_id filtresi). Ayrı bir metot: listeyi sayfalayıp içinden aramak, tek satır için
     * bütün katalogu çekmek olurdu.
     */
    public function product(string $tenantId, string $productId): ?\stdClass
    {
        return DB::connection($this->connection)->table('products')
            ->where('tenant_id', $tenantId)
            ->where('id', $productId)
            ->first();
    }

    /**
     * Sekme rozetlerindeki sayılar (tek turda; her biri tenant_id filtreli).
     *
     * @return array{musteri: int, siparis: int, defter: int, urun: int, denetim: int}
     */
    public function sayilar(string $tenantId): array
    {
        $say = fn (string $tablo, bool $tombstone = true) => (int) DB::connection($this->connection)
            ->table($tablo)->where('tenant_id', $tenantId)
            ->when($tombstone, fn ($q) => $q->whereNull('deleted_at'))->count();

        return [
            'musteri' => $say('customers'),
            'siparis' => $say('orders'),
            'defter' => $say('ledger_entries', false),
            'urun' => $say('products'),
            'denetim' => (int) DB::connection($this->connection)->table('panel_audit')
                ->where('tenant_id', $tenantId)->count(),
        ];
    }

    // ------------------------------------------------------------------------------------

    /**
     * Ada / koda / telefonun son 10 hanesine göre arama. Telefon araması alt sorgudur (JOIN
     * kullanılsaydı iki numarası olan müşteri listede iki kez çıkardı).
     *
     * @param  Builder  $q
     */
    private function musteriArama($q, string $tenantId, string $arama): void
    {
        $arama = trim($arama);
        if ($arama === '') {
            return;
        }

        $rakam = preg_replace('/\D/', '', $arama) ?? '';

        $q->where(function ($w) use ($arama, $rakam, $tenantId) {
            $w->where('c.name', 'ilike', '%'.$arama.'%');

            if ($rakam !== '') {
                $w->orWhere('c.code', '=', (int) $rakam);
                $w->orWhereExists(function ($s) use ($rakam, $tenantId) {
                    $s->selectRaw('1')->from('customer_phones')
                        ->where('customer_phones.tenant_id', $tenantId)
                        ->whereColumn('customer_phones.customer_id', 'c.id')
                        ->whereNull('customer_phones.deleted_at')
                        ->where('customer_phones.phone_last10', 'like', '%'.substr($rakam, -10).'%');
                });
            }
        });
    }

    /** @return Builder */
    private function birincilTelefon()
    {
        return DB::connection($this->connection)->table('customer_phones as p')
            ->select('p.phone_e164')
            ->whereColumn('p.tenant_id', 'c.tenant_id')
            ->whereColumn('p.customer_id', 'c.id')
            ->whereNull('p.deleted_at')
            ->orderByDesc('p.is_primary')->limit(1);
    }

    /** @return Builder */
    private function sonSiparis()
    {
        return DB::connection($this->connection)->table('orders as o')
            ->selectRaw('max(o.occurred_at)')
            ->whereColumn('o.tenant_id', 'c.tenant_id')
            ->whereColumn('o.customer_id', 'c.id')
            ->whereNull('o.deleted_at');
    }
}
