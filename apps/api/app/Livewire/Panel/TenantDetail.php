<?php

namespace App\Livewire\Panel;

use App\Livewire\Panel\Forms\MusteriForm;
use App\Livewire\Panel\Forms\UrunForm;
use App\Panel\PanelStatsService;
use App\Panel\PanelTenantDataService;
use App\Panel\PanelWriteService;
use App\Panel\TenantAdminService;
use Illuminate\Support\Facades\Auth;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;
use RuntimeException;

/**
 * Bayi detayı — SEKMELİ (5c-3 · D2). Özet · Müşteriler · Siparişler · Defter · Ürünler · Denetim.
 *
 * Abonelik/durum eylemleri TenantAdminService'e delege edilir (tenants UPDATE panel bağlantısıyla).
 * İş verisi sekmeleri PanelTenantDataService ile SALT-OKUNUR okunur; müşteri/ürün YAZMA eylemleri
 * ayrı bileşendedir (D3) — bu bileşen iş verisine yazmaz.
 *
 * render() YALNIZ AÇIK SEKMENİN sorgusunu koşar: altı sekmenin verisini her turda çekmek, bir
 * sayfalama düğmesine basıldığında görünmeyen beş listeyi de yeniden sorgulamak olurdu.
 */
#[Layout('components.layouts.app')]
class TenantDetail extends Component
{
    use WithPagination;

    /** Geçerli sekmeler — bilinmeyen değer 'ozet'e düşer (URL'den elle sekme uydurulamaz). */
    public const SEKMELER = ['ozet', 'musteriler', 'siparisler', 'defter', 'urunler', 'denetim'];

    public string $tenantId;

    #[Url(as: 'sekme')]
    public string $sekme = 'ozet';

    public int $extendDays = 14;

    /** Şifre sıfırlama sonrası admin'e BİR KEZ gösterilir (kalıcı saklanmaz). */
    public ?string $newPassword = null;

    public string $musteriArama = '';

    public bool $musteriSilinmisler = false;

    /** Satır detayı açık olan müşteri (bakiye + son siparişler); null = kapalı. */
    public ?string $acikMusteri = null;

    public string $siparisDurum = '';

    public string $siparisBaslangic = '';

    public string $siparisBitis = '';

    public string $defterTip = '';

    public string $urunArama = '';

    public bool $urunSilinmisler = false;

    // --- Yazma (D3) ---------------------------------------------------------------------

    public MusteriForm $musteriForm;

    public UrunForm $urunForm;

    public bool $musteriFormAcik = false;

    public bool $urunFormAcik = false;

    /**
     * Kullanıcıya gösterilecek sonuç.
     *
     * @var array{tur: string, mesaj: string}|null
     */
    public ?array $bildirim = null;

    public function mount(string $tenant): void
    {
        $this->tenantId = $tenant;
    }

    public function sekmeSec(string $sekme): void
    {
        $this->sekme = in_array($sekme, self::SEKMELER, true) ? $sekme : 'ozet';
        $this->acikMusteri = null;
        $this->formlariKapat();
        $this->resetPage('msayfa');
        $this->resetPage('ssayfa');
        $this->resetPage('dsayfa');
        $this->resetPage('usayfa');
        $this->resetPage('ksayfa');
    }

    /** Süzgeç değişince sayfa 1'e döner — yoksa 5. sayfada daralan liste boş görünürdü. */
    public function updatedMusteriArama(): void
    {
        $this->resetPage('msayfa');
    }

    public function updatedUrunArama(): void
    {
        $this->resetPage('usayfa');
    }

    public function siparisSuzgeciUygula(): void
    {
        $this->resetPage('ssayfa');
    }

    public function defterSuzgeciUygula(): void
    {
        $this->resetPage('dsayfa');
    }

    public function musteriAc(string $id): void
    {
        $this->acikMusteri = ($this->acikMusteri === $id) ? null : $id;
    }

    // --- Müşteri / ürün yazma (D3) ------------------------------------------------------

    public function musteriFormAc(?string $id = null): void
    {
        $this->musteriForm->reset();
        $this->bildirim = null;

        if ($id !== null) {
            $detay = app(PanelTenantDataService::class)->customerDetail($this->tenantId, $id);
            if ($detay === null) {
                $this->bildirim = ['tur' => 'hata', 'mesaj' => 'Müşteri bulunamadı.'];

                return;
            }
            $this->musteriForm->doldur($detay['musteri'], $detay['telefonlar']->first(), $detay['adresler']->first());
        }

        $this->musteriFormAcik = true;
    }

    public function musteriKaydet(): void
    {
        $this->musteriForm->validate();

        $this->yazmayiCalistir(function () {
            $sonuc = app(PanelWriteService::class)
                ->musteriKaydet($this->tenantId, $this->musteriForm->veri(), $this->adminId());

            if ($sonuc['durum'] === 'applied') {
                $this->musteriFormAcik = false;
                $this->musteriForm->reset();
            }

            return $sonuc;
        }, 'Müşteri kaydedildi.');
    }

    public function musteriKaraListe(string $id, bool $karaListe): void
    {
        $this->yazmayiCalistir(
            fn () => app(PanelWriteService::class)->musteriKaraListe($this->tenantId, $id, $karaListe, $this->adminId()),
            $karaListe ? 'Müşteri kara listeye alındı.' : 'Müşteri kara listeden çıkarıldı.',
        );
    }

    public function urunFormAc(?string $id = null): void
    {
        $this->urunForm->reset();
        $this->bildirim = null;

        if ($id !== null) {
            $urun = app(PanelTenantDataService::class)->product($this->tenantId, $id);
            if ($urun === null) {
                $this->bildirim = ['tur' => 'hata', 'mesaj' => 'Ürün bulunamadı.'];

                return;
            }
            $this->urunForm->doldur($urun);
        }

        $this->urunFormAcik = true;
    }

    public function urunKaydet(): void
    {
        $this->urunForm->validate();

        if ($this->urunForm->fiyatKurus() < 0) {
            $this->addError('urunForm.fiyat', 'Fiyat negatif olamaz.');

            return;
        }

        $this->yazmayiCalistir(function () {
            $sonuc = app(PanelWriteService::class)
                ->urunKaydet($this->tenantId, $this->urunForm->veri(), $this->adminId());

            if ($sonuc['durum'] === 'applied') {
                $this->urunFormAcik = false;
                $this->urunForm->reset();
            }

            return $sonuc;
        }, 'Ürün kaydedildi.');
    }

    public function urunAktiflik(string $id, bool $aktif): void
    {
        $this->yazmayiCalistir(
            fn () => app(PanelWriteService::class)->urunAktiflik($this->tenantId, $id, $aktif, $this->adminId()),
            $aktif ? 'Ürün etkinleştirildi.' : 'Ürün pasifleştirildi.',
        );
    }

    public function formlariKapat(): void
    {
        $this->musteriFormAcik = false;
        $this->urunFormAcik = false;
        $this->bildirim = null;
    }

    /**
     * Yazma eylemlerinin ortak kabuğu: sonucu KULLANICIYA DÜRÜSTÇE bildirir.
     *
     * Kritik nokta 'applied' dışındaki durumlardır — kilitli bayi ('locked') ve daha yeni bir
     * yazımın üstüne yazma ('stale') sessiz kalırsa panel "kaydettim" der ama hiçbir şey yazılmaz.
     *
     * @param  callable():array{durum: string, mesaj: string|null}  $is
     */
    private function yazmayiCalistir(callable $is, string $basariMesaji): void
    {
        try {
            $sonuc = $is();
        } catch (RuntimeException $e) {
            $this->bildirim = ['tur' => 'hata', 'mesaj' => $e->getMessage()];

            return;
        }

        $this->bildirim = $sonuc['durum'] === 'applied'
            ? ['tur' => 'ok', 'mesaj' => $basariMesaji]
            : ['tur' => 'hata', 'mesaj' => $sonuc['mesaj'] ?? 'Kayıt uygulanamadı ('.$sonuc['durum'].').'];
    }

    // --- Abonelik / durum eylemleri (5c-1'den; iş verisine dokunmaz) ---------------------
    //
    // HEPSİ YALNIZ SUPERADMIN (5c-3 · D5). Ayrımın mantığı: destek ekibi bayinin işini yapmasına
    // yardım edebilmeli (müşteri/ürün girişi, CSV aktarımı — geri alınabilir ve denetlenir) ama
    // bayinin ABONELİĞİNE, kilidine ya da patron şifresine dokunamamalı; bunlar parasal ve
    // erişimsel kararlardır. Kapı her eylemin İÇİNDEDİR: Blade'de düğmeyi gizlemek yetki denetimi
    // değildir, Livewire eylemi doğrudan da çağrılabilir.

    public function extendTrial(): void
    {
        $this->superadminZorunlu();
        $this->service()->extendTrial($this->tenantId, $this->extendDays, $this->adminId());
    }

    public function activate(): void
    {
        $this->superadminZorunlu();
        $this->service()->activateSubscription($this->tenantId, 365, $this->adminId());
    }

    public function lock(): void
    {
        $this->superadminZorunlu();
        $this->service()->lock($this->tenantId, $this->adminId());
    }

    public function unlock(): void
    {
        $this->superadminZorunlu();
        $this->service()->unlock($this->tenantId, $this->adminId());
    }

    public function suspend(): void
    {
        $this->superadminZorunlu();
        $this->service()->suspend($this->tenantId, $this->adminId());
    }

    /** Opsiyonel modül aç/kapa (FAZ 5c-2). Mevcut durumu tersine çevirir. */
    public function toggleModule(string $module): void
    {
        $this->superadminZorunlu();
        $detail = $this->service()->tenantDetail($this->tenantId);
        $current = (bool) ($detail['tenant']->modules[$module] ?? false);
        $this->service()->setModule($this->tenantId, $module, ! $current, $this->adminId());
    }

    /** Patron şifre sıfırlama (FAZ 5c-2). Yeni parola BİR KEZ gösterilir (owner ile üretilir). */
    public function resetPassword(): void
    {
        $this->superadminZorunlu();
        $this->newPassword = $this->service()->resetPatronPassword($this->tenantId, $this->adminId());
    }

    public function superadminMi(): bool
    {
        return Auth::guard('admin')->user()?->isSuperadmin() === true;
    }

    private function superadminZorunlu(): void
    {
        abort_unless($this->superadminMi(), 403);
    }

    public function render(): mixed
    {
        $detail = $this->service()->tenantDetail($this->tenantId);
        abort_if($detail === null, 404);

        if (! in_array($this->sekme, self::SEKMELER, true)) {
            $this->sekme = 'ozet';
        }

        $data = app(PanelTenantDataService::class);

        return view('livewire.panel.tenant-detail', [
            'detail' => $detail,
            'sayilar' => $data->sayilar($this->tenantId),
            'superadmin' => $this->superadminMi(),
        ] + $this->sekmeVerisi($data));
    }

    /**
     * Açık sekmenin verisi (yalnız o sekmenin sorguları koşar).
     *
     * @return array<string, mixed>
     */
    private function sekmeVerisi(PanelTenantDataService $data): array
    {
        return match ($this->sekme) {
            'musteriler' => [
                'musteriler' => $data->customers($this->tenantId, $this->musteriArama, $this->musteriSilinmisler),
                'musteriDetay' => $this->acikMusteri !== null
                    ? $data->customerDetail($this->tenantId, $this->acikMusteri)
                    : null,
            ],
            'siparisler' => ['siparisler' => $data->orders($this->tenantId, [
                'durum' => $this->siparisDurum,
                'baslangic' => $this->siparisBaslangic,
                'bitis' => $this->siparisBitis,
            ])],
            'defter' => [
                'defter' => $data->ledger($this->tenantId, ['tip' => $this->defterTip]),
                'defterOzet' => $data->ledgerOzet($this->tenantId),
            ],
            'urunler' => ['urunler' => $data->products($this->tenantId, $this->urunArama, $this->urunSilinmisler)],
            'denetim' => ['denetim' => $data->audit($this->tenantId)],
            default => $this->ozetVerisi(),
        };
    }

    /** @return array<string, mixed> */
    private function ozetVerisi(): array
    {
        $stats = app(PanelStatsService::class);

        return [
            'dailyOrders' => $stats->dailyOrders($this->tenantId),
            'hourDistribution' => $stats->orderHourDistribution($this->tenantId),
            'minutesToFirstOrder' => $stats->minutesToFirstOrder($this->tenantId),
            'activeDevices' => $stats->activeDeviceCount($this->tenantId),
            'devices' => $stats->devices($this->tenantId),
        ];
    }

    private function service(): TenantAdminService
    {
        return app(TenantAdminService::class);
    }

    private function adminId(): ?string
    {
        $id = Auth::guard('admin')->id();

        return $id !== null ? (string) $id : null;
    }
}
