<?php

namespace App\Livewire\Panel\Concerns;

use App\Livewire\Panel\Forms\MusteriForm;
use App\Livewire\Panel\Forms\UrunForm;
use App\Panel\PanelTenantDataService;
use App\Panel\PanelWriteService;
use RuntimeException;

/**
 * BAYİNİN İŞ VERİSİ SEKMELERİ — süzgeçler + müşteri/ürün yazma yüzeyi (`TenantDetail`in parçası).
 *
 * BÖLME ÖLÇÜTÜ SATIR SAYISI DEĞİL, YETKİ SINIRIDIR. Buradaki HER eylem DESTEK rolüne de açıktır:
 * hepsi `PanelWriteService`ten geçer, geri alınabilir ve denetlenir — destek ekibi bayinin işini
 * yapmasına yardım edebilmelidir. `TenantDetail`de KALAN her eylem (abonelik, kilit, iptal, modül,
 * patron parolası, kurye) superadmin kapılıdır; onlar parasal ve erişimsel kararlardır.
 *
 * BU YÜZDEN BURADA `superadminZorunlu()` ÇAĞRISI YOKTUR VE OLMAMALIDIR. Trait'e taşımanın klasik
 * tuzağı kapının "çağıran hallediyordur" varsayımına kaymasıdır; burada kapı YOK çünkü bu eylemler
 * kapıya TABİ DEĞİL — kural bu dosyada yazılı olsun ki bir gün buraya superadmin işi bir eylem
 * eklenmek istendiğinde yanlış yere eklendiği görülsün.
 *
 * SINIR HÂLÂ KORUNUYOR: yazmanın hedefi `$this->tenantId`dir ve o alan `TenantDetail`de
 * `#[Locked]`tır — istemci değiştiremez.
 *
 * @property string $tenantId
 * @property array{tur: string, mesaj: string}|null $bildirim
 */
trait BayiIsVerisi
{
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

    public MusteriForm $musteriForm;

    public UrunForm $urunForm;

    public bool $musteriFormAcik = false;

    public bool $urunFormAcik = false;

    /** Reddedilen yazma denemesinin denetim kaydı — kullanan sınıf sağlar. */
    abstract protected function denetle(string $eylem, string $sebep): void;

    abstract protected function adminId(): ?string;

    // --- Süzgeçler -----------------------------------------------------------------------

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

    // --- Müşteri ------------------------------------------------------------------------

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
        }, 'Müşteri kaydedildi.', 'customer_save');
    }

    public function musteriKaraListe(string $id, bool $karaListe): void
    {
        $this->yazmayiCalistir(
            fn () => app(PanelWriteService::class)->musteriKaraListe($this->tenantId, $id, $karaListe, $this->adminId()),
            $karaListe ? 'Müşteri kara listeye alındı.' : 'Müşteri kara listeden çıkarıldı.',
            'customer_blacklist',
        );
    }

    // --- Ürün ---------------------------------------------------------------------------

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
        }, 'Ürün kaydedildi.', 'product_save');
    }

    public function urunAktiflik(string $id, bool $aktif): void
    {
        $this->yazmayiCalistir(
            fn () => app(PanelWriteService::class)->urunAktiflik($this->tenantId, $id, $aktif, $this->adminId()),
            $aktif ? 'Ürün etkinleştirildi.' : 'Ürün pasifleştirildi.',
            'product_activity',
        );
    }

    /** Yalnız İŞ VERİSİ formlarını kapatır; modalları kullanan sınıfın `formlariKapat`ı kapatır. */
    protected function isVerisiFormlariniKapat(): void
    {
        $this->musteriFormAcik = false;
        $this->urunFormAcik = false;
    }

    /**
     * Yazma eylemlerinin ortak kabuğu: sonucu KULLANICIYA DÜRÜSTÇE bildirir.
     *
     * Kritik nokta 'applied' dışındaki durumlardır — kilitli bayi ('locked') ve daha yeni bir
     * yazımın üstüne yazma ('stale') sessiz kalırsa panel "kaydettim" der ama hiçbir şey yazılmaz.
     * REDDEDİLEN DENEME DE DENETİME DÜŞER: başarılı yazma günlüğe girip reddedilen girmezse,
     * "kim neyi denedi" sorusunun cevabı yalnız başarılı yarısını gösterir.
     *
     * @param  callable():array{durum: string, mesaj: string|null}  $is
     */
    private function yazmayiCalistir(callable $is, string $basariMesaji, string $eylem): void
    {
        try {
            $sonuc = $is();
        } catch (RuntimeException $e) {
            $this->bildirim = ['tur' => 'hata', 'mesaj' => $e->getMessage()];
            $this->denetle($eylem, 'hata');

            return;
        }

        if ($sonuc['durum'] === 'applied') {
            $this->bildirim = ['tur' => 'ok', 'mesaj' => $basariMesaji];

            return;
        }

        $this->bildirim = ['tur' => 'hata', 'mesaj' => $sonuc['mesaj'] ?? 'Kayıt uygulanamadı ('.$sonuc['durum'].').'];
        $this->denetle($eylem, $sonuc['durum']);
    }
}
