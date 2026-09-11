<?php

namespace App\Livewire\Panel;

use App\Panel\PanelImportService;
use App\Panel\PanelTenantDataService;
use App\Panel\TenantAdminService;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Locked;
use Livewire\Attributes\Title;
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
#[Layout('components.layouts.panel')]
#[Title('Müşteri Toplu Aktarım')]
class CustomerImport extends Component
{
    use WithFileUploads;

    /** Önizlemede ekrana çizilen azami satır (özet sayılar TÜM dosyayı kapsar). */
    private const ONIZLEME_TAVANI = 200;

    /**
     * Bir adımın yazma bütçesi (saniye). Adım bu süreyi aşınca durur, elindeki partiyi yazar
     * ve döner; kalan satırlar bir sonraki tura kalır.
     *
     * 8 SANİYE NEDEN: bütçe yalnız YENİ bir satıra başlarken bakılır, elde bekleyen parti yine
     * de yazılır — yani en kötü durumda adım 8 saniye + bir parti süresi (ölçüldü: ~150 müşteri
     * ≈ 7 sn) ≈ 15 saniye sürer. Bu, karşılaşılan tüm varsayılan tavanların (php-fpm 30 sn,
     * nginx `fastcgi_read_timeout` 60 sn) rahatça altındadır. Daha büyük bir bütçe payı yer,
     * daha küçüğü ise dosya başına tur sayısını ve dolayısıyla yeniden çözümleme masrafını
     * gereksiz büyütür (her tur dosyanın tamamını yeniden ayrıştırır).
     */
    private const ADIM_SANIYE = 8.0;

    /** Durumda taşınan azami hata satırı (Livewire yük sınırı — bkz. onizle()). */
    private const HATA_TAVANI = 100;

    /** Kilitli: toplu yazmanın hedef bayisi route'tan gelir, istemciden değiştirilemez. */
    #[Locked]
    public string $tenantId;

    /**
     * 2 MB → 8 MB (2026-09-11): satır tavanı 10.000'e çıktı ve gerçek bir devralma ölçüldü —
     * 9.057 müşteri, çoklu telefon ve adresle birlikte 1,2 MB tutuyor. Sınırı satır tavanıyla
     * birlikte büyütmezsek kullanıcı "10.000 satır aktarılabilir" yazısını okuyup dosyasını
     * yükleyemez ve nedenini anlamaz (hata "dosya çok büyük" der, satır sayısını değil).
     */
    #[Validate('required|file|max:8192|mimes:csv,txt')]
    public mixed $dosya = null;

    /**
     * Önizleme — YALNIZ ekrana çizilen satırlar (bkz. onizle(): Livewire yük sınırı).
     * `toplam` dosyadaki gerçek satır sayısıdır; `satirlar` en fazla ONIZLEME_TAVANI tanedir.
     *
     * @var array{ozet: array<string, int>, satirlar: list<array<string, mixed>>, toplam: int}|null
     */
    public ?array $onizleme = null;

    /** @var array<string, mixed>|null */
    public ?array $sonuc = null;

    public ?string $hata = null;

    /**
     * Aktarım SÜRÜYOR mu? true ise ekran `wire:poll` ile `adim()`ı çağırmaya devam eder.
     *
     * NEDEN ADIMLI (2026-09-11): 9.048 müşterilik gerçek dosya tek istekte ~7,5 dakika sürüyor
     * (ölçüldü) ve hiçbir web sunucusu o isteği beklemez — php-fpm, nginx ve tarayıcı çok daha
     * önce keser, üstelik tam yazmanın ortasında. Servis artık süre bütçesiyle BİR ADIM koşuyor
     * (bkz. PanelImportService::uygula); burada yapılan iş, bitene kadar adımları sürdürmek ve
     * kullanıcıya nerede olduğunu göstermek.
     *
     * KULLANICIYA "DOSYAYI BÖL" DEMEK ÇÖZÜM DEĞİLDİR: bölmek işi kullanıcıya yıkar, her parça
     * ayrı bir onay adımı doğurur ve sayılar parça parça dağılır.
     */
    public bool $devam = false;

    /**
     * İlerleme sayaçları. `atlanan`/`hatali` İLK önizlemeden alınır ve BİR DAHA GÜNCELLENMEZ:
     * ikinci adımda, birinci adımda yazılmış satırlar dedup'tan 'atlanacak' gelir ve sayaç
     * şişerdi — kullanıcı "9.000 satır atlandı" görüp aktarımın başarısız olduğunu sanırdı.
     *
     * @var array<string, mixed>
     */
    public array $ilerleme = [];

    /**
     * Var olmayan bayide 404 (lead kararı). Kapı olmadan uydurma bir UUID ile sayfa açılıyor,
     * sayılar sıfır görünüyor ve kullanıcı boş bir bayiye bakıyorum sanıyordu; hata ancak
     * aktarımı deneyince ("bu bayide kullanıcı yok") ortaya çıkıyordu. Bayi detayı zaten
     * aynı kuralı uyguluyor — iki panel sayfası aynı adrese farklı cevap vermemeli.
     */
    public function mount(string $tenant): void
    {
        // BOZUK UUID DE 404: `tenants.id` uuid kolonudur, biçimsiz metinle sorgulamak `22P02`
        // üretir ve kullanıcıya 500 döner. Yanlış yapıştırılmış bir kimlik arıza değil, olmayan
        // kayıttır — bayi detayı da aynı cevabı verir.
        abort_unless(Str::isUuid($tenant), 404);
        abort_if(app(TenantAdminService::class)->tenantDetail($tenant) === null, 404);

        $this->tenantId = $tenant;
    }

    /** Dosyayı çözümler ve ne olacağını gösterir — HİÇBİR ŞEY YAZMAZ. */
    public function onizle(): void
    {
        $this->validate();
        $this->sonuc = null;
        $this->hata = null;

        try {
            $tam = app(PanelImportService::class)
                ->onizleme($this->tenantId, (string) $this->dosya->get());

            /**
             * BİLEŞEN DURUMUNDA YALNIZ EKRANA ÇİZİLEN SATIRLAR TUTULUR — ÜRETİMDE ÖLÇÜLDÜ
             * (2026-09-11): 9.048 satırlık gerçek dosyada tam önizlemeyi durumda tutmak
             * Livewire yükünü **2.997 KB**'a çıkardı ve "Aktar" düğmesi 500 verdi
             * (`PayloadTooLargeException`, tavan 1.024 KB).
             *
             * Livewire HER tur BÜTÜN public özellikleri isteğe koyar. Tam önizleme yalnız 500
             * hatası değil, çok daha kötüsü demekti: adımlı aktarım iki saniyede bir yoklama
             * yapıyor, yani 8 dakikalık bir aktarımda ~240 turda yüzlerce megabayt gidip
             * gelirdi. Sınırı büyütmek (config/livewire.php `payload.max_size`) belirtiyi
             * susturur, maliyeti kaldırmaz.
             *
             * Ekran zaten yalnız ilk ONIZLEME_TAVANI satırı çiziyordu; geri kalanı taşımanın
             * hiçbir karşılığı yoktu. Kararlar dosyadan YENİDEN türetilir (`uygula()` servisi
             * dosyayı baştan çözümler), bu yüzden kesilen satırların kaybı yoktur.
             *
             * TESTLER BUNU GÖREMEDİ: Livewire'ın test koşumu HTTP yük sınırını uygulamıyor.
             * Bu yüzden aşağıdaki `toplam` alanı bir gerileme bekçisiyle kilitlendi
             * (PanelImportAdimliUiTest: durum boyutu dosya boyutuyla BÜYÜMEMELİ).
             */
            $this->onizleme = [
                'ozet' => $tam['ozet'],
                'satirlar' => array_slice($tam['satirlar'], 0, self::ONIZLEME_TAVANI),
                'toplam' => count($tam['satirlar']),
            ];
        } catch (RuntimeException $e) {
            $this->onizleme = null;
            $this->hata = $e->getMessage();
        }
    }

    /**
     * Onay. HİÇBİR ŞEY YAZMAZ — yalnız adımlı aktarımı başlatır ve ilerleme kartını açar.
     * İlk adımı ekran çizildikten SONRA `wire:poll` tetikler; böylece kullanıcı düğmeye
     * bastığında tarayıcı onlarca saniye taş gibi durmaz, ilerlemeyi görür.
     */
    public function uygula(): void
    {
        if ($this->onizleme === null) {
            $this->hata = 'Önce dosyayı yükleyip önizleyin.';

            return;
        }

        $this->hata = null;
        $this->sonuc = null;
        $this->ilerleme = [
            'toplam' => (int) $this->onizleme['ozet']['eklenecek'],
            'yazilan' => 0,
            'atlanan' => (int) $this->onizleme['ozet']['atlanacak'],
            'hatali' => (int) $this->onizleme['ozet']['hatali'],
            'acilan_urunler' => [],
            'hatalar' => [],
        ];
        $this->devam = $this->ilerleme['toplam'] > 0;

        // Önizleme durumu BURADA BIRAKILIR: ilerleme kartı onun yerini aldı ve aktarım boyunca
        // iki saniyede bir yoklama var — 200 satırlık tabloyu yüzlerce turda taşımanın hiçbir
        // karşılığı yok (aynı yük gerekçesi: bkz. onizle()).
        $this->onizleme = null;

        if (! $this->devam) {
            $this->bitir('applied', null);
        }
    }

    /**
     * TEK ADIM. Servis süre bütçesi kadar yazar ve `kalan` ile kaç satırın beklediğini söyler;
     * sıfırlanana kadar `wire:poll` buraya geri gelir.
     *
     * Her adım dosyayı YENİDEN çözümler ve dedup'ı yeniden koşar — önceki adımda yazılanlar
     * 'atlanacak' geldiği için kendiliğinden atlanır. Bu yüzden imleç/ofset saklanmaz: saklanan
     * bir imleç, arada eklenen bir müşteriyle ya da tazelenen bir sayfayla bayatlardı.
     */
    public function adim(): void
    {
        if (! $this->devam) {
            return;
        }

        /**
         * TEK ADIM AYNI ANDA — kilit pazarlıksız. `wire:poll` bir adım uçarken yenisini
         * tetikleyebilir (adım ~8-15 sn sürüyor, tur 2 sn) ve iki adım AYNI ANDA koşarsa ikisi de
         * dedup'ı yazmadan ÖNCE okur: aynı müşteri iki kez yazılır. Tarayıcı tarafındaki istek
         * sıralamasına güvenmek yetmez — kullanıcı sayfayı ikinci bir sekmede de açabilir.
         *
         * Kilit alınamazsa adım SESSİZCE atlanır (hata değil): zaten koşan adım işi ilerletiyor,
         * bir sonraki tur devam eder.
         */
        $kilit = Cache::lock('musteri-aktarim:'.$this->tenantId, 120);
        if (! $kilit->get()) {
            return;
        }

        try {
            $sonuc = app(PanelImportService::class)->uygula(
                $this->tenantId,
                (string) $this->dosya->get(),
                $this->adminId(),
                self::ADIM_SANIYE,
            );
        } catch (RuntimeException $e) {
            $this->devam = false;
            $this->hata = $e->getMessage();

            return;
        } finally {
            $kilit->release();
        }

        $this->ilerleme['yazilan'] += (int) $sonuc['eklenen'];
        $this->ilerleme['acilan_urunler'] = array_values(array_unique(array_merge(
            $this->ilerleme['acilan_urunler'], $sonuc['acilan_urunler'],
        )));
        if ($sonuc['hatalar'] !== []) {
            // Önizleme satırlarıyla AYNI gerekçe: liste durumda taşınır ve her turda isteğe
            // girer. Bozuk bir dosyada binlerce hata satırı yükü yine 1 MB tavanının üstüne
            // çıkarırdı. Kullanıcı ilk yüz satırı düzeltip yeniden yükler.
            $this->ilerleme['hatalar'] = array_slice($sonuc['hatalar'], 0, self::HATA_TAVANI);
            $this->ilerleme['hata_toplam'] = count($sonuc['hatalar']);
        }

        // Durum 'applied' değilse (kilitli bayi / reddedilen parti) DEVAM ETME: aynı hata her
        // adımda tekrarlanır ve ekran sonsuza kadar dönerdi.
        if ($sonuc['durum'] !== 'applied') {
            $this->bitir($sonuc['durum'], $sonuc['mesaj']);

            return;
        }

        if ((int) $sonuc['kalan'] === 0) {
            $this->bitir('applied', null);
        }
    }

    public function sifirla(): void
    {
        $this->reset(['dosya', 'onizleme', 'sonuc', 'hata', 'devam', 'ilerleme']);
    }

    public function render(): mixed
    {
        $detay = app(PanelTenantDataService::class);

        return view('livewire.panel.customer-import', [
            'sayilar' => $detay->sayilar($this->tenantId),
            // Kesme `onizle()`de yapıldı (yük sınırı gerekçesi orada); burada yalnız çizilir.
            'gosterilecek' => $this->onizleme['satirlar'] ?? [],
            'gizlenen' => $this->onizleme !== null
                ? max(0, $this->onizleme['toplam'] - count($this->onizleme['satirlar']))
                : 0,
        ]);
    }

    /** Adımı kapat: ilerleme kartı sonuç kartına döner, `wire:poll` susar. */
    private function bitir(string $durum, ?string $mesaj): void
    {
        $this->devam = false;
        $this->sonuc = [
            'eklenen' => $this->ilerleme['yazilan'],
            'atlanan' => $this->ilerleme['atlanan'],
            'hatali' => $this->ilerleme['hatali'],
            'durum' => $durum,
            'mesaj' => $mesaj,
            'hatalar' => $this->ilerleme['hatalar'],
            'acilan_urunler' => $this->ilerleme['acilan_urunler'],
        ];
        $this->onizleme = null;
    }

    private function adminId(): ?string
    {
        $id = Auth::guard('admin')->id();

        return $id !== null ? (string) $id : null;
    }
}
