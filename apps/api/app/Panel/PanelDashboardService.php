<?php

namespace App\Panel;

use Illuminate\Database\Query\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Panel GENEL BAKIŞ verisi (5c-3 · D1). SALT-OKUNUR — `pgsql_panel` rolüyle (BYPASSRLS) okunur.
 *
 * KIRMIZI ÇİZGİ #1 NOTU: buradaki sorgular BİLEREK cross-tenant'tır (panelin tamamına ait pano);
 * `PanelExportService`/`PanelStatsService`'teki "her tabloda açık tenant_id filtresi" kuralı TEK BİR
 * bayinin verisini gösteren yüzeyler içindir. Bu sınıf tek bayi verisi DÖNDÜRMEZ: yalnız tenants
 * satırları (bizim müşteri listemiz) ve sipariş ZAMAN damgalarının varlığı/en büyüğü — bayinin iş
 * verisi DEĞERİ (müşteri adı, tutar, adres) hiçbir sorguda seçilmez (KVKK, kırmızı çizgi #4).
 *
 * "Yazabilir" tanımı SyncService::resolveLock ile BİREBİR aynıdır: status ∈ {trial, active} VE
 * (valid_until NULL VEYA gelecekte). Panelin "aktif bayi" dediği ile sunucunun push'ta kabul ettiği
 * bayi aynı küme olmalıdır — iki yüzey farklı sayı konuşursa pano yanıltıcıdır.
 */
class PanelDashboardService
{
    public function __construct(private readonly string $connection = 'pgsql_panel') {}

    /**
     * Bayi sayıları: toplam, yazabilir (= sunucunun kilitlemediği) ve durum dağılımı.
     * Dağılım dört durumu da ANAHTAR olarak taşır (hiç bayisi olmayan durum 0 görünür, kaybolmaz).
     *
     * @return array{toplam: int, yazabilir: int, dagilim: array<string, int>}
     */
    public function ozet(): array
    {
        $rows = DB::connection($this->connection)->table('tenants')
            ->selectRaw('status, count(*) as adet')
            ->groupBy('status')->get();

        $dagilim = ['trial' => 0, 'active' => 0, 'locked' => 0, 'suspended' => 0];
        $toplam = 0;
        foreach ($rows as $row) {
            $dagilim[(string) $row->status] = (int) $row->adet;
            $toplam += (int) $row->adet;
        }

        return [
            'toplam' => $toplam,
            'yazabilir' => $this->yazabilirSorgusu()->count(),
            'dagilim' => $dagilim,
        ];
    }

    /**
     * Denemesi $gun gün içinde bitecek bayiler (bugün dahil; süresi ZATEN geçmişler DIŞARIDA —
     * onlar artık "biten deneme" değil kilitli bayidir ve panonun başka satırında görünür).
     *
     * @return Collection<int, \stdClass>
     */
    public function bitenDenemeler(int $gun = 7): Collection
    {
        return DB::connection($this->connection)->table('tenants')
            ->select('id', 'name', 'slug', 'trial_ends_at', 'valid_until')
            ->where('status', 'trial')
            ->whereNotNull('trial_ends_at')
            ->where('trial_ends_at', '>=', now())
            ->where('trial_ends_at', '<=', now()->addDays($gun))
            ->orderBy('trial_ends_at')
            ->get();
    }

    /**
     * CHURN RİSKİ: yazabilir olduğu hâlde son $gun gündür HİÇ sipariş girmemiş bayiler.
     *
     * "Hiç sipariş girmemiş" iki farklı hikâyedir ve ikisi de risktir: (a) kullanmayı bırakmış
     * (son_siparis dolu ama eski), (b) hiç başlamamış (son_siparis null — kurulum yapıldı, ürün
     * hayata girmedi). Ayrımı satırdaki "Son sipariş" sütunu gösterir; ikisini ayrı listeye bölmek
     * aynı eylemi (bayiyi ara) iki yere dağıtırdı.
     *
     * @return Collection<int, \stdClass>
     */
    public function churnRiski(int $gun = 3): Collection
    {
        $esik = now()->subDays($gun);

        return $this->yazabilirSorgusu()
            ->select('t.id', 't.name', 't.slug', 't.status', 't.created_at')
            ->selectSub(
                DB::connection($this->connection)->table('orders')
                    ->selectRaw('max(occurred_at)')
                    ->whereColumn('orders.tenant_id', 't.id')
                    ->whereNull('orders.deleted_at'),
                'son_siparis'
            )
            ->whereNotExists(function ($q) use ($esik) {
                $q->selectRaw('1')->from('orders')
                    ->whereColumn('orders.tenant_id', 't.id')
                    ->whereNull('orders.deleted_at')
                    ->where('orders.occurred_at', '>=', $esik);
            })
            ->orderBy('t.name')
            ->get();
    }

    /**
     * Önümüzdeki $gun günde aboneliği/denemesi bitecek bayiler (yenileme takvimi). Çıpa
     * `valid_until`dır — 5a'da kilidi belirleyen alan odur; trial_ends_at yalnız "deneme miydi"
     * bilgisidir ve tek başına takvim kurmak yanlış tarihi gösterirdi.
     *
     * @return Collection<int, \stdClass>
     */
    public function yenilemeTakvimi(int $gun = 60): Collection
    {
        return DB::connection($this->connection)->table('tenants')
            ->select('id', 'name', 'slug', 'status', 'valid_until')
            ->whereNotNull('valid_until')
            ->where('valid_until', '>=', now())
            ->where('valid_until', '<=', now()->addDays($gun))
            ->orderBy('valid_until')
            ->get();
    }

    /**
     * Takvimi 7 günlük kovalara böler (saf SVG çubuk grafiğin veri kaynağı — JS grafik kütüphanesi
     * EKLENMEZ). Boş hafta de dönülür: eksik kova çubuğu değil, sıfır yüksekliğinde çubuk gösterir;
     * yoksa takvimdeki boşluk grafikte görünmez olurdu.
     *
     * @param  Collection<int, \stdClass>  $takvim
     * @return list<array{etiket: string, adet: int}>
     */
    public function haftalikKovalar(Collection $takvim, int $gun = 60): array
    {
        $baslangic = now()->startOfDay();
        $kovaSayisi = (int) ceil($gun / 7);

        $kovalar = [];
        for ($i = 0; $i < $kovaSayisi; $i++) {
            $kovalar[] = ['etiket' => $baslangic->copy()->addDays($i * 7)->format('d.m'), 'adet' => 0];
        }

        foreach ($takvim as $satir) {
            $gunFarki = (int) $baslangic->diffInDays(Carbon::parse((string) $satir->valid_until)->startOfDay(), false);
            $kova = intdiv(max($gunFarki, 0), 7);
            if ($kova < $kovaSayisi) {
                $kovalar[$kova]['adet']++;
            }
        }

        return $kovalar;
    }

    /**
     * Yazabilir bayi sorgusu (SyncService::resolveLock'un SQL karşılığı). `t` takma adıyla döner ki
     * churn sorgusu alt-sorgularda kolon çakışması yaşamadan üstüne bina edebilsin.
     *
     * @return Builder
     */
    private function yazabilirSorgusu()
    {
        return DB::connection($this->connection)->table('tenants as t')
            ->whereIn('t.status', ['trial', 'active'])
            ->where(function ($q) {
                $q->whereNull('t.valid_until')->orWhere('t.valid_until', '>=', now());
            });
    }
}
