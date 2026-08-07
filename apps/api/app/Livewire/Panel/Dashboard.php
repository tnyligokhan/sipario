<?php

namespace App\Livewire\Panel;

use App\Abonelik\GelirGiderRaporu;
use App\Abonelik\PlanDeposu;
use App\Livewire\Panel\Concerns\Bicim;
use App\Models\PaymentNotification;
use App\Panel\PanelDashboardService;
use App\Panel\PanelStatsService;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Title;
use Livewire\Component;

/**
 * DASHBOARD (tasarım `06-Dashboard.jsx`) — panelin ana sayfası, "bugün kime bakmalıyım"ın cevabı.
 * TAMAMEN SALT-OKUNUR: tek bir eylemi yoktur, bütün bağlantıları başka ekranlara götürür.
 *
 * BAĞLANTI: her okuma `pgsql_panel` (BYPASSRLS, SELECT-only). Abonelik servisleri varsayılan olarak
 * `pgsql_owner` ile gelir — orası YAZAN yolların bağlantısıdır; bir panonun superuser rolüyle okuması
 * için sebep yok (AbonelikServisi'nin belge başlığı bu geçişe açıkça izin veriyor).
 *
 * TASARIMA EKLENENLER (BRIEF md. 3 · panelde bugün var, kaybolmamalı):
 *   · bekleyen havale beyanı sayacı — navigasyonda ve panoda görünmezse o kuyruk hiç açılmaz
 *   · churn riski (N gündür sipariş girmeyen bayiler)
 *   · 60 günlük yenileme takvimi + haftalık çubuk grafik
 *   · aylık gelir/net trendi (çizgi) ve sipariş girme saati dağılımı (ısı şeridi)
 *
 * İKİ SORGU BU BİLEŞENDE: "ödemesi geciken" listesi ve ay içi ödeme adedi `PanelDashboardService`te
 * yok. İkisi de o servisin cross-tenant sözleşmesine uyar (yalnız `tenants` satırları ve ödeme
 * ZAMAN damgaları okunur, bayinin iş verisi DEĞERİ değil) ve yalnız bu ekranı ilgilendirir.
 */
#[Layout('components.layouts.panel')]
#[Title('Dashboard')]
class Dashboard extends Component
{
    /** Panelin salt-okunur bağlantısı (sipario_panel — BYPASSRLS, yazamaz). */
    private const BAGLANTI = 'pgsql_panel';

    /**
     * AY SINIRI SABİT +03:00. `Etc/GMT-3` POSIX işaretiyle UTC+3 demektir (DST yok) ve
     * GelirGiderRaporu'nun SQL'iyle BİREBİR aynıdır. `now()` ile ay anahtarı üretilseydi, ayın son
     * gecesi 21:00'den sonra pano bir sonraki ayı sorar, rapor bu ayı döndürürdü.
     */
    private const AY_DILIMI = 'Etc/GMT-3';

    /** Churn eşiği (gün) — kaç gündür sipariş girilmemiş bayiler riskli sayılsın. */
    public int $churnGun = 3;

    /** Yenileme takviminin ufku (gün). */
    public int $takvimGun = 60;

    /** Gelir/net trend çizgisinin kaç ayı gösterdiği. */
    public int $trendAy = 12;

    /** Saat dağılımının kaç günlük siparişe baktığı. */
    public int $saatGun = 30;

    public function render(): mixed
    {
        $pano = app(PanelDashboardService::class);
        $rapor = new GelirGiderRaporu(self::BAGLANTI);

        $ay = now(self::AY_DILIMI)->format('Y-m');
        $takvim = $pano->yenilemeTakvimi($this->takvimGun);
        $plan = new PlanDeposu(self::BAGLANTI);

        return view('livewire.panel.dashboard', [
            'ozet' => $pano->ozet(),
            // Geciken satırında bayinin KENDİ döneminin ücreti yazılır: aylık abonenin yanına
            // yıllık tutar yazmak, tahsil edilecek parayı 12 katı gösterirdi.
            'aylikKurus' => $plan->aylikKurus(),
            'yillikKurus' => $plan->yillikKurus(),
            'bitenDenemeler' => $pano->bitenDenemeler(7),
            'gecikenler' => $this->gecikenler(),
            'churnRiski' => $pano->churnRiski($this->churnGun),
            'takvim' => $takvim,
            'kovalar' => $pano->haftalikKovalar($takvim, $this->takvimGun),
            'ayOzet' => $rapor->ay($ay),
            'ayOdemeAdedi' => $this->ayOdemeAdedi($ay),
            'gelirTrendi' => $this->gelirTrendi($rapor),
            'saatDagilimi' => app(PanelStatsService::class)->saatDagilimiTum($this->saatGun),
            'bekleyenBildirim' => $this->bekleyenBildirim(),
        ]);
    }

    /**
     * ÖDEMESİ GECİKEN bayiler (tasarımın sağdaki listesi). Tasarım "aktif veya askıda + bitiş
     * geçmiş" diyordu; sunucuda ÜÇÜNCÜ bir durum daha aynı hikâyeyi anlatıyor: `locked` zaten
     * "süresi doldu" demektir ve listeden düşerse en acil bayiler görünmez olur.
     *
     * `trial` DIŞARIDA — denemenin bitişi borç değildir ve zaten soldaki kartın konusudur.
     * `cancelled` DIŞARIDA — bırakan bayiden tahsilat beklenmez (churn sayacına girer).
     *
     * @return Collection<int, \stdClass>
     */
    private function gecikenler(): Collection
    {
        return DB::connection(self::BAGLANTI)->table('tenants')
            ->select('id', 'name', 'slug', 'status', 'valid_until', 'billing_period')
            ->whereIn('status', ['active', 'suspended', 'locked'])
            ->whereNotNull('valid_until')
            ->where('valid_until', '<', now())
            ->orderBy('valid_until')
            ->get();
    }

    /** Bu ay düşen BAŞARILI ödeme adedi (kartın "N ödeme" alt satırı) — tutar raporun işi. */
    private function ayOdemeAdedi(string $ay): int
    {
        return DB::connection(self::BAGLANTI)->table('subscription_payments')
            ->where('status', 'success')
            ->whereRaw("to_char(occurred_at AT TIME ZONE 'Etc/GMT-3', 'YYYY-MM') = ?", [$ay])
            ->count();
    }

    /** Bekleyen havale beyanı sayısı. Servisin `bekleyenler()`i 200 satırla sınırlı — sayaç sayar. */
    private function bekleyenBildirim(): int
    {
        return DB::connection(self::BAGLANTI)->table('payment_notifications')
            ->where('status', PaymentNotification::STATUS_PENDING)
            ->count();
    }

    /**
     * Aylık gelir/net trendi, ESKİDEN YENİYE (rapor yeniden eskiye döner; grafik soldan sağa akar).
     * Grafikte NET çizilir: gelir tek başına gideri gizler ve "iyi ay" yanılsaması üretir.
     *
     * @return list<array{etiket: string, deger: float}>
     */
    private function gelirTrendi(GelirGiderRaporu $rapor): array
    {
        $aylar = array_reverse($rapor->aylikOzet($this->trendAy));

        // Ay etiketi `Bicim`den gelir — para ekranlarıyla aynı yazım. Kendi Carbon biçimimizi
        // kurmak, iki ekranın aynı ayı farklı yazması demekti (bu depoda yaşanmış bir hata).
        return array_map(fn (array $satir) => [
            'etiket' => Bicim::ayKisa($satir['ay']),
            'deger' => round($satir['net_kurus'] / 100, 2),
        ], $aylar);
    }
}
