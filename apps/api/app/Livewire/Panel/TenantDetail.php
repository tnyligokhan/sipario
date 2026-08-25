<?php

namespace App\Livewire\Panel;

use App\Abonelik\EkPaketServisi;
use App\Abonelik\KotaDoluException;
use App\Abonelik\KuryeKotasi;
use App\Abonelik\OdemeKayitServisi;
use App\Abonelik\PlanDeposu;
use App\Abonelik\TenantNotServisi;
use App\Livewire\Panel\Concerns\BayiIsVerisi;
use App\Livewire\Panel\Concerns\Bicim;
use App\Models\Tenant;
use App\Panel\PanelStatsService;
use App\Panel\PanelTenantDataService;
use App\Panel\PanelWriteService;
use App\Panel\TenantAdminService;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Locked;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;
use RuntimeException;
use Throwable;

/**
 * ÜYE DETAYI (tasarım `07-Uyeler.jsx` · UyeDetay) — SEKMELİ:
 * Özet · Müşteriler · Siparişler · Defter · Ürünler · Denetim.
 *
 * Tasarımın iki sütunlu düzeni "Özet" sekmesidir; BRIEF md. 3'ün zorunlu yetenekleri (modül
 * aç/kapa, patron parolası, cihazlar, dışa/içe aktarım, kurye açma, kullanım istatistikleri)
 * aynı sekmenin ALTINA, aynı kart diliyle eklenmiştir.
 *
 * Abonelik/durum eylemleri TenantAdminService'e, müşteri/ürün yazımı PanelWriteService'e delege
 * edilir; iş verisi sekmeleri PanelTenantDataService ile SALT-OKUNUR okunur.
 *
 * render() YALNIZ AÇIK SEKMENİN sorgusunu koşar: altısını her turda çekmek, bir sayfalama
 * düğmesine basıldığında görünmeyen beş listeyi de yeniden sorgulamak olurdu.
 */
#[Layout('components.layouts.panel')]
#[Title('Üye Detayı')]
class TenantDetail extends Component
{
    // İŞ VERİSİ sekmelerinin süzgeçleri ve müşteri/ürün yazma yüzeyi ayrı dosyada: oradaki her
    // eylem DESTEK rolüne de açıktır, burada kalan her eylem superadmin kapılıdır. Bölme çizgisi
    // yetki sınırının aynısıdır (bkz. BayiIsVerisi belge başlığı).
    use BayiIsVerisi, WithPagination;

    /** Geçerli sekmeler — bilinmeyen değer 'ozet'e düşer (URL'den elle sekme uydurulamaz). */
    public const SEKMELER = ['ozet', 'musteriler', 'siparisler', 'defter', 'urunler', 'denetim'];

    /**
     * Bayi bazında açılıp kapanabilen opsiyonel modüller (BRIEF md. 3).
     *
     * ⚠️ `empty_tracking` BİR BAYRAKTIR, BİR ÖZELLİK DEĞİL (karar 2026-08-17): boş/emanet
     * takibi v1 kapsamından ÇIKARILDI ve mobil istemcide karşılığı YOKTUR — telefon bu alanı
     * senkron yanıtında görür ama HİÇ OKUMAZ. Etikete "(v1'de yok)" eklenmesinin sebebi tam
     * olarak budur: bayrağı açan operatör, sahada bir şeyin değişeceğini sanmamalıdır.
     *
     * Mekanizmanın kendisi KALIR çünkü BRIEF md. 3 paneliden "bayi bazında modül aç/kapa"
     * yeteneğini istiyor; kaldırılan şey o yeteneğin İLK ÖRNEĞİNİN ürün karşılığıdır. Gerçek
     * bir modül geldiğinde bu liste onu taşır ve etiket düzelir.
     */
    public const MODULLER = ['empty_tracking' => 'Boş/emanet takibi (v1\'de yok)'];

    /** Salt-okunur panel bağlantısı; yazan servisler kendi (owner) bağlantısını kullanır. */
    private const BAGLANTI = 'pgsql_panel';

    /**
     * `#[Locked]`: kilitlenmemiş her public alan İSTEMCİDEN değiştirilebilir. Bu alan yazma
     * eylemlerinin hedefini belirler — bir SINIR taşır, istemcinin değerine bağlanamaz.
     */
    #[Locked]
    public string $tenantId;

    #[Url(as: 'sekme')]
    public string $sekme = 'ozet';

    /** Şifre sıfırlama sonrası admin'e BİR KEZ gösterilir (kalıcı saklanmaz). */
    public ?string $newPassword = null;

    // --- Deneme uzatma modalı (tasarım · DenemeUzatModal) --------------------------------

    public bool $uzatAcik = false;

    public int $uzatGun = 7;

    /** Boşsa hızlı seçim (uzatGun) geçerlidir; doluysa özel tarih onu ezer. */
    public string $uzatOzelTarih = '';

    // --- Not ekleme (tasarım · Notlar kartı) ---------------------------------------------

    public string $yeniNot = '';

    // --- Kurye hesabı açma (BRIEF md. 3; bugün başka hiçbir yolu yok) ---------------------

    public bool $kuryeAcik = false;

    public string $kuryeAd = '';

    public string $kuryeKullanici = '';

    public string $kuryeParola = '';

    public string $kuryeTelefon = '';

    /**
     * Kullanıcıya gösterilecek sonuç.
     *
     * @var array{tur: string, mesaj: string}|null
     */
    public ?array $bildirim = null;

    /**
     * BOZUK UUID 404 VERİR, 500 DEĞİL: `tenants.id` uuid kolonudur, biçimsiz metinle sorgulamak
     * `22P02` üretir. Yanlış yapıştırılmış bir kimlik arıza değil, olmayan kayıttır.
     */
    public function mount(string $tenant): void
    {
        abort_unless(Str::isUuid($tenant), 404);
        abort_if(app(TenantAdminService::class)->tenantDetail($tenant) === null, 404);

        $this->tenantId = $tenant;
    }

    // --- Sekmeler ------------------------------------------------------------------------

    public function sekmeSec(string $sekme): void
    {
        $this->sekme = in_array($sekme, self::SEKMELER, true) ? $sekme : 'ozet';
        $this->sekmeSifirla();
    }

    /** Çipler `$set('sekme', ...)` ile yazar; o yol `sekmeSec`i çağırmaz, bu kanca çağırır. */
    public function updatedSekme(string $deger): void
    {
        $this->sekme = in_array($deger, self::SEKMELER, true) ? $deger : 'ozet';
        $this->sekmeSifirla();
    }

    private function sekmeSifirla(): void
    {
        $this->acikMusteri = null;
        $this->formlariKapat();
        foreach (['msayfa', 'ssayfa', 'dsayfa', 'usayfa', 'ksayfa'] as $sayfa) {
            $this->resetPage($sayfa);
        }
    }

    /** Açık HER katmanı kapatır — sekme değişince ekranda asılı kalan bir form/modal kalmasın. */
    public function formlariKapat(): void
    {
        $this->isVerisiFormlariniKapat();
        $this->uzatAcik = false;
        $this->kuryeAcik = false;
        $this->bildirim = null;
    }

    // --- Deneme uzatma (tasarım · DenemeUzatModal) ---------------------------------------

    public function uzatAc(): void
    {
        $this->superadminZorunlu('extend_trial');
        $this->reset(['uzatGun', 'uzatOzelTarih']);
        $this->bildirim = null;
        $this->uzatAcik = true;
    }

    public function uzatKapat(): void
    {
        $this->uzatAcik = false;
    }

    public function hizliGun(int $gun): void
    {
        $this->uzatGun = $gun;
        $this->uzatOzelTarih = '';
    }

    /**
     * Yeni bitişin ÖNİZLEMESİ. Taban `TenantAdminService::extendTrial`inkiyle BİREBİR aynıdır —
     * ekranda başka, kayıtta başka bir tarih çıkarsa modal yalan söylemiş olur.
     */
    public function uzatOnizleme(): ?Carbon
    {
        $taban = $this->uzatTabani();

        if (trim($this->uzatOzelTarih) !== '') {
            try {
                return Carbon::parse($this->uzatOzelTarih)->endOfDay();
            } catch (Throwable) {
                return null;
            }
        }

        return $taban->copy()->addDays(max($this->uzatGun, 0));
    }

    public function uzatKaydet(): void
    {
        $this->superadminZorunlu('extend_trial');

        $hedef = $this->uzatOnizleme();
        if ($hedef === null) {
            $this->bildirim = ['tur' => 'hata', 'mesaj' => 'Tarih anlaşılamadı; gün/ay/yıl seçin.'];
            $this->denetle('extend_trial', 'gecersiz_tarih');

            return;
        }

        // Servis GÜN sayısı alır; özel tarih o gün sayısına çevrilir. Geçmişe (ya da mevcut bitişin
        // gerisine) uzatma sessizce süre KISALTMAK olurdu — reddedilir ve denetime düşer.
        $gun = (int) ceil($this->uzatTabani()->diffInDays($hedef, false));
        if ($gun <= 0) {
            $this->bildirim = ['tur' => 'hata', 'mesaj' => 'Yeni tarih mevcut deneme bitişinden sonra olmalı.'];
            $this->denetle('extend_trial', 'gerileten_tarih');

            return;
        }

        $bayi = $this->service()->extendTrial($this->tenantId, $gun, $this->adminId());
        $this->uzatAcik = false;
        $this->bildirim = null;
        $this->dispatch('tost', mesaj: 'Deneme '.Bicim::tarihKisa($bayi->trial_ends_at).' tarihine uzatıldı');
    }

    private function uzatTabani(): Carbon
    {
        $bitis = $this->bayi()->trial_ends_at;

        return ($bitis !== null && $bitis->greaterThan(now())) ? $bitis->copy() : now();
    }

    // --- Notlar (tasarım · Notlar kartı) -------------------------------------------------

    public function notEkle(): void
    {
        $metin = trim($this->yeniNot);
        if ($metin === '') {
            return;
        }

        // Not YAZMA eylemidir ama abonelik kararı değildir: destek ekibi de not düşebilmeli
        // (telefonda konuşan kişi odur). Yetki ayrımı parasal/erişimsel eylemlerdedir.
        app(TenantNotServisi::class)->ekle($this->tenantId, $metin, $this->adminId());
        $this->yeniNot = '';
        $this->dispatch('tost', mesaj: 'Not eklendi');
    }

    // --- Abonelik / durum eylemleri ------------------------------------------------------
    // HEPSİ YALNIZ SUPERADMIN ve kapı her eylemin İÇİNDEDİR: düğmeyi gizlemek yetki denetimi
    // değildir, Livewire eylemi doğrudan da çağrılabilir. Deneme uzatma burada YOK, modaldadır
    // (`uzatKaydet`) — tek giriş noktası önizlemeli olandır.

    public function activate(): void
    {
        $this->superadminZorunlu('activate');
        $this->service()->activateSubscription($this->tenantId, 365, $this->adminId());
        $this->dispatch('tost', mesaj: 'Abonelik 1 yıl kaydedildi');
    }

    public function lock(): void
    {
        $this->superadminZorunlu('lock');
        $this->service()->lock($this->tenantId, $this->adminId());
        $this->dispatch('tost', mesaj: 'Bayi kilitlendi');
    }

    public function unlock(): void
    {
        $this->superadminZorunlu('unlock');
        $this->service()->unlock($this->tenantId, $this->adminId());
        $this->dispatch('tost', mesaj: 'Üyelik aktifleştirildi');
    }

    public function suspend(): void
    {
        $this->superadminZorunlu('suspend');
        $this->service()->suspend($this->tenantId, $this->adminId());
        $this->dispatch('tost', mesaj: 'Üyelik askıya alındı');
    }

    /**
     * İPTAL (BAYİ BIRAKTI) — `suspended` ile bilerek ayrıdır: askıdaki bayi hâlâ müşteridir,
     * iptal churn sayacına girer (bkz. TenantStatus). Panelde `cancelled`a geçmenin tek yolu.
     */
    public function iptalEt(): void
    {
        $this->superadminZorunlu('cancel');
        $this->service()->cancel($this->tenantId, $this->adminId());
        $this->dispatch('tost', mesaj: 'Üyelik iptal edildi');
    }

    /** Opsiyonel modül aç/kapa (BRIEF md. 3). Mevcut durumu tersine çevirir. */
    public function toggleModule(string $module): void
    {
        $this->superadminZorunlu('set_module');

        if (! array_key_exists($module, self::MODULLER)) {
            $this->denetle('set_module', 'bilinmeyen_modul');

            return;
        }

        $mevcut = (bool) ($this->bayi()->modules[$module] ?? false);
        $this->service()->setModule($this->tenantId, $module, ! $mevcut, $this->adminId());
    }

    /** Patron şifre sıfırlama (BRIEF md. 3). Yeni parola BİR KEZ gösterilir. */
    public function resetPassword(): void
    {
        $this->superadminZorunlu('reset_password');
        $this->newPassword = $this->service()->resetPatronPassword($this->tenantId, $this->adminId());
    }

    // --- Kurye hesabı açma ---------------------------------------------------------------

    public function kuryeAc(): void
    {
        $this->superadminZorunlu('create_courier');
        $this->reset(['kuryeAd', 'kuryeKullanici', 'kuryeParola', 'kuryeTelefon']);
        $this->bildirim = null;
        $this->kuryeAcik = true;
    }

    public function kuryeKapat(): void
    {
        $this->kuryeAcik = false;
    }

    /**
     * Kota kapısı `KuryeKotasi`dir ve burada TEKRARLANMAZ — yalnız istisnası anlaşılır bir cümleye
     * çevrilir; iki yerde denetlemek ikisinin ayrı düşmesi riskini yaratırdı.
     *
     * `max:` tavanları DB şemasıyla birebir (users.name 120 · username 60 + CHECK
     * `^[a-z0-9._-]{3,60}$` · phone 20): formda durmayan sınır Postgres'te `22001`e dönüşür.
     */
    public function kuryeKaydet(): void
    {
        $this->superadminZorunlu('create_courier');

        $this->validate([
            'kuryeAd' => ['required', 'string', 'min:2', 'max:120'],
            'kuryeKullanici' => ['required', 'string', 'regex:/^[a-z0-9._-]{3,60}$/'],
            'kuryeParola' => ['required', 'string', 'min:8', 'max:72'],
            'kuryeTelefon' => ['nullable', 'string', 'max:20'],
        ], [
            'kuryeKullanici.regex' => 'Kullanıcı adı yalnız küçük harf, rakam, nokta, tire ve alt çizgi içerebilir (3-60 karakter).',
        ]);

        try {
            $this->service()->createCourier(
                $this->tenantId,
                trim($this->kuryeAd),
                trim($this->kuryeKullanici),
                $this->kuryeParola,
                trim($this->kuryeTelefon) !== '' ? trim($this->kuryeTelefon) : null,
                $this->adminId(),
            );
        } catch (KotaDoluException $e) {
            $this->bildirim = ['tur' => 'hata', 'mesaj' => 'Kurye hesabı kotası dolu ('
                .$e->kullanilan.'/'.$e->limit.'). Ek kurye paketi tanımlayarak kotayı büyütebilirsiniz.'];
            $this->denetle('create_courier', 'kota_dolu');

            return;
        } catch (RuntimeException $e) {
            $this->bildirim = ['tur' => 'hata', 'mesaj' => $e->getMessage()];
            $this->denetle('create_courier', 'hata');

            return;
        }

        $this->kuryeAcik = false;
        $this->reset(['kuryeAd', 'kuryeKullanici', 'kuryeParola', 'kuryeTelefon']);
        $this->dispatch('tost', mesaj: 'Kurye hesabı açıldı');
    }

    // --- Görüntüleme ---------------------------------------------------------------------

    public function superadminMi(): bool
    {
        return Auth::guard('admin')->user()?->isSuperadmin() === true;
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
            'moduller' => self::MODULLER,
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
        $plan = new PlanDeposu(self::BAGLANTI);
        $bayi = $this->bayi();

        return [
            'plan' => $plan->plan(),
            'aylikKurus' => $plan->aylikKurus(),
            'yillikKurus' => $plan->yillikKurus(),
            'odemeler' => (new OdemeKayitServisi(self::BAGLANTI))->bayiOdemeleri($this->tenantId),
            'notlar' => (new TenantNotServisi(self::BAGLANTI))->liste($this->tenantId),
            'tanimlamalar' => (new EkPaketServisi(self::BAGLANTI))->tanimlamalar($this->tenantId),
            'kuryeKota' => (new KuryeKotasi(self::BAGLANTI))->kullanim($bayi),
            'gunlukSiparis' => $stats->dailyOrders($this->tenantId),
            'saatDagilimi' => $stats->orderHourDistribution($this->tenantId),
            'ilkSiparisDakika' => $stats->minutesToFirstOrder($this->tenantId),
            'aktifCihaz' => $stats->activeDeviceCount($this->tenantId),
            'cihazlar' => $stats->devices($this->tenantId),
        ];
    }

    // --- Ortak ---------------------------------------------------------------------------

    /**
     * REDDEDİLEN DENEMENİN denetim kaydı (`<eylem>_denied`) — `BayiIsVerisi` de bunu kullanır.
     * Sebep KISA ve KATEGORİKtir ('yetkisiz', 'kota_dolu', 'stale'); kullanıcı girdisi ya da tutar
     * GEÇMEZ, panel_audit KVKK-nötr kalır (kırmızı çizgi #4).
     */
    protected function denetle(string $eylem, string $sebep): void
    {
        $this->service()->auditRed($eylem, $this->tenantId, $sebep, $this->adminId());
    }

    private function bayi(): Tenant
    {
        return Tenant::on(self::BAGLANTI)->findOrFail($this->tenantId);
    }

    /** Yetki reddi de iz bırakır: 403 sessizse "kim neyi denedi" görünmez olur. */
    private function superadminZorunlu(string $eylem): void
    {
        if ($this->superadminMi()) {
            return;
        }

        $this->denetle($eylem, 'yetkisiz');
        abort(403);
    }

    private function service(): TenantAdminService
    {
        return app(TenantAdminService::class);
    }

    protected function adminId(): ?string
    {
        $id = Auth::guard('admin')->id();

        return $id !== null ? (string) $id : null;
    }
}
