<?php

namespace App\Livewire\Panel;

use App\Panel\PanelImportService;
use App\Panel\PanelTenantDataService;
use Illuminate\Support\Facades\Auth;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Validate;
use Livewire\Component;
use Livewire\WithFileUploads;
use RuntimeException;

/**
 * Müşteri CSV toplu aktarım ekranı (5c-3 · D4). Üç adım: şablon indir → dosya yükle (ÖNİZLEME) →
 * onayla. Kendi sayfasıdır, bayi detayının sekmesi DEĞİL: çok adımlı bir sihirbaz, sekme
 * değiştirince durumu kaybolan bir yüzeyde yaşayamaz.
 *
 * Dosyanın İÇERİĞİ bileşen durumunda TUTULMAZ; yüklenen geçici dosya iki istek arasında yaşar ve
 * `uygula()` onu yeniden okur. 2 MB'lık bir CSV'yi Livewire durumunda taşımak her tıklamada
 * ağdan geçerdi — ve o içerik zaten müşteri verisidir.
 */
#[Layout('components.layouts.app')]
class CustomerImport extends Component
{
    use WithFileUploads;

    /** Önizlemede ekrana çizilen azami satır (özet sayılar TÜM dosyayı kapsar). */
    private const ONIZLEME_TAVANI = 200;

    public string $tenantId;

    #[Validate('required|file|max:2048|mimes:csv,txt')]
    public mixed $dosya = null;

    /** @var array{satirlar: list<array<string, mixed>>, ozet: array<string, int>}|null */
    public ?array $onizleme = null;

    /** @var array<string, mixed>|null */
    public ?array $sonuc = null;

    public ?string $hata = null;

    public function mount(string $tenant): void
    {
        $this->tenantId = $tenant;
    }

    /** Dosyayı çözümler ve ne olacağını gösterir — HİÇBİR ŞEY YAZMAZ. */
    public function onizle(): void
    {
        $this->validate();
        $this->sonuc = null;
        $this->hata = null;

        try {
            $this->onizleme = app(PanelImportService::class)
                ->onizleme($this->tenantId, (string) $this->dosya->get());
        } catch (RuntimeException $e) {
            $this->onizleme = null;
            $this->hata = $e->getMessage();
        }
    }

    /**
     * Onay. Servis dosyayı YENİDEN çözümler ve dedup'ı yeniden koşar — ekrandaki önizleme
     * bilgilendirmedir, karar yazma anında sunucuda verilir.
     */
    public function uygula(): void
    {
        if ($this->onizleme === null) {
            $this->hata = 'Önce dosyayı yükleyip önizleyin.';

            return;
        }

        $this->hata = null;

        try {
            $this->sonuc = app(PanelImportService::class)
                ->uygula($this->tenantId, (string) $this->dosya->get(), $this->adminId());
            $this->onizleme = null;
        } catch (RuntimeException $e) {
            $this->hata = $e->getMessage();
        }
    }

    public function sifirla(): void
    {
        $this->reset(['dosya', 'onizleme', 'sonuc', 'hata']);
    }

    public function render(): mixed
    {
        $detay = app(PanelTenantDataService::class);

        return view('livewire.panel.customer-import', [
            'sayilar' => $detay->sayilar($this->tenantId),
            'gosterilecek' => $this->onizleme !== null
                ? array_slice($this->onizleme['satirlar'], 0, self::ONIZLEME_TAVANI)
                : [],
            'gizlenen' => $this->onizleme !== null
                ? max(0, count($this->onizleme['satirlar']) - self::ONIZLEME_TAVANI)
                : 0,
        ]);
    }

    private function adminId(): ?string
    {
        $id = Auth::guard('admin')->id();

        return $id !== null ? (string) $id : null;
    }
}
