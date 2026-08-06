<?php

namespace App\Livewire\Site;

use App\Abonelik\EkPaketServisi;
use App\Abonelik\GecersizTutarException;
use App\Abonelik\OdemeBildirimServisi;
use App\Abonelik\PlanDeposu;
use App\Enums\BillingPeriod;
use App\Livewire\Site\Forms\ParaBicimi;
use App\Livewire\Site\Forms\SirketKunyesi;
use App\Models\AddonPackage;
use App\Models\Tenant;
use App\Payment\ConsentRequiredException;
use App\Payment\SubscriptionService;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Route;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Locked;
use Livewire\Component;
use Throwable;

/**
 * ÖDEME AKIŞI (tasarım: 13-sw-odeme.jsx). Havale/EFT + elden. Menüsüz `site-ciplak` kabuğu.
 *
 * KART FORMU VE 3D SECURE EKRANI BİLEREK YAZILMADI. Tasarımın kendisi kart seçeneğini tıklanamaz
 * bir `div`e ("Yakında" rozetli) koymuş, yani `yol` değişkeni hiçbir zaman 'kart' olamıyor — kart
 * formu tasarımda da ÖLÜ koddu. Ayrıca `IyzicoPaymentGateway::assertConfigured()` anahtarsız
 * RuntimeException atar; iyzico ERTELENDİ (OKU-BENI kararı). Yazılmayan kod sızdırmaz.
 *
 * `SubscriptionService::startCheckout()` BU AKIŞTA ÇAĞRILAMAZ: ilk işi `gateway->initiate()`tir ve
 * anahtarsız iyzico orada patlar — üstelik onay kaydı o çağrıdan SONRA düşer, yani hiçbir şey
 * kaydedilmeden hata alırdık. Bu yüzden onun İKİ SÖZLEŞMESİ burada aynen korunuyor:
 *   1. ÜÇ hukuk onayı da (mesafeli satış + ön bilgilendirme + KVKK) ZORUNLU — biri eksikse akış
 *      başlamaz ve mesaj birebir servisinkidir.
 *   2. Kabul edilen SÜRÜMLER kaydedilir. `payment_notifications`ta onay kolonu olmadığı için
 *      `note` alanına yazılır (raporlandı: doğru çözüm servise elle-tahsilat checkout'u eklemektir).
 *
 * BEYAN ABONELİĞİ UZATMAZ: `OdemeBildirimServisi::olustur()` yalnız BEKLEYEN bir iddia yazar.
 * Abonelik ancak panel operatörü ekstrede parayı görüp `eslestir()` dediğinde uzar. Ekran bunu
 * bayiye dürüstçe söyler ("Dekont ulaştığı gün hesabınız açılır" — tasarımın kendi metni).
 */
#[Layout('components.layouts.site-ciplak', ['baslik' => 'Ödeme · Sipario'])]
class Subscribe extends Component
{
    use ParaBicimi, SirketKunyesi;

    /** 'plan' (abonelik) | 'paket' (ek oto-sıralama hakkı). İstemci DEĞİŞTİREMEZ. */
    #[Locked]
    public string $tur = 'plan';

    /** Abonelik dönemi (yalnız $tur='plan'). */
    #[Locked]
    public string $donem = BillingPeriod::Yearly->value;

    /** Satın alınan ek paket kimliği (yalnız $tur='paket'). */
    #[Locked]
    public ?string $paketId = null;

    /**
     * "Vazgeç"in döneceği yerin ANAHTARI (URL değil). `mount()`ta kapalı listeye karşı doğrulanır;
     * tanınmayan/eksik değer '' kalır ve varsayılana düşer. `#[Locked]`: istemci sonradan
     * çeviremesin.
     *
     * ÖZELLİKLE BİR SORGU PARAMETRESİDİR, `Referer` DEĞİL. `Referer`e bakıp oraya dönmek, ödeme
     * sayfasına bağlantı kurabilen herkese "bayiyi ödemeden sonra istediğim adrese göndereyim"
     * demek olurdu (açık yönlendirme → oltalama). Anahtar taşımanın gücü tam da şu: taşınan şey
     * bir adres değil, bizim tanıdığımız bir kelime.
     *
     * `mount()`ta ÇÖZÜLÜR, `render()`ta değil: Livewire'ın sonraki istekleri (ör. `$set('yol',…)`)
     * kendi uç noktasına gider ve orijinal querystring ORADA YOKTUR — `render()`ta okusaydık ilk
     * tıklamadan sonra hedef sessizce varsayılana düşerdi.
     */
    #[Locked]
    public string $geri = '';

    /**
     * "Vazgeç"in dönebileceği yerlerin TAMAMI: anahtar → [route adı, parametreler].
     *
     * Hesap paneline dönerken `?bolum=` de taşınır; `Hesap::mount()` bu değeri kendi kapalı
     * listesine karşı doğrulayıp açılış sekmesini kurar. Yoksa "Abonelik sekmesinden geldim,
     * Genel bakış'a düştüm" olurdu.
     *
     * @var array<string, array{0: string, 1: array<string, string>}>
     */
    private const GERI_HEDEFLERI = [
        'abonelik' => ['site.hesap', ['bolum' => 'abonelik']],
        'hak' => ['site.hesap', ['bolum' => 'hak']],
        'hesap' => ['site.hesap', []],
        'fiyatlar' => ['site.fiyatlar', []],
    ];

    /** Tahsil edilecek tutar — SUNUCUDA hesaplanır, istemciden ASLA alınmaz. */
    #[Locked]
    public int $tutarKurus = 0;

    /** Havale açıklamasına yazılacak referans kodu; ekranda gösterilen ile kaydedilen AYNI olmalı. */
    #[Locked]
    public string $referans = '';

    #[Locked]
    public bool $tesekkur = false;

    #[Locked]
    public string $tesekkurYol = 'iban';

    public string $yol = 'havale';

    public bool $mesafeliSatis = false;

    public bool $onBilgilendirme = false;

    public bool $kvkk = false;

    private ?Tenant $bayi = null;

    public function mount(): mixed
    {
        $tenantId = $this->bayiKimligi();
        if ($tenantId === null) {
            // 403 yerine girişe yönlendirme: ödeme ekranına fiyat sayfasından gelen misafir
            // bir hata değil, henüz giriş yapmamış bir müşteridir.
            return $this->redirect(route('subscription.login'), navigate: false);
        }

        $istek = request();
        $this->tur = $istek->query('tur') === 'paket' ? 'paket' : 'plan';
        $this->donem = (BillingPeriod::tryFrom((string) $istek->query('donem')) ?? BillingPeriod::Yearly)->value;

        $geri = (string) $istek->query('geri', '');
        $this->geri = isset(self::GERI_HEDEFLERI[$geri]) ? $geri : '';

        if ($this->tur === 'paket') {
            $paket = $this->paketBul((string) $istek->query('paket', ''));
            // Satışta olmayan/bilinmeyen paket → sepet abonelie düşer; uydurma tutar oluşmaz.
            $this->tur = $paket === null ? 'plan' : 'paket';
            $this->paketId = $paket?->id;
        }

        $this->tutarKurus = $this->tutarHesapla();
        $this->referans = OdemeBildirimServisi::referansUret($this->tenant()->slug);

        return null;
    }

    /** "Havale yaptım" — BEYAN kaydı. Aboneliği UZATMAZ. */
    public function havaleBildir(): void
    {
        $this->beyanYaz('iban');
    }

    /** "Beni arayın" — elden tahsilat talebi; yine bir beyandır. */
    public function eldenBildir(): void
    {
        $this->beyanYaz('elden');
    }

    /** Havale bilgilerini bayinin kendi e-postasına gönderir (tasarımın "E-posta ile gönder"i). */
    public function bilgileriPostala(): void
    {
        $adres = Auth::guard('web')->check()
            ? (string) Auth::guard('web')->user()->email
            : (string) session('subscription_email', '');

        if ($adres === '') {
            $this->dispatch('bildir', detail: 'Kayıtlı bir e-posta adresi bulunamadı');

            return;
        }

        $govde = implode("\n", [
            'Sipario abonelik ödemesi — havale/EFT bilgileri',
            '',
            'Alıcı ünvanı : '.$this->sirket()['unvan'],
            'Banka        : '.$this->sirket()['banka'],
            'IBAN         : '.$this->sirket()['iban'],
            'Tutar        : '.$this->tl($this->tutarKurus),
            'Referans kodu: '.$this->referans,
            '',
            'Açıklama alanına referans kodunu yazmayı unutmayın; dekont ulaştığı gün hesabınız açılır.',
        ]);

        try {
            Mail::raw($govde, fn ($m) => $m->to($adres)->subject('Sipario · havale bilgileri'));
            $this->dispatch('bildir', detail: 'Talimat e-postanıza gönderildi');
        } catch (Throwable $e) {
            report($e);
            $this->dispatch('bildir', detail: 'E-posta gönderilemedi, bilgileri kopyalayabilirsiniz');
        }
    }

    public function render(): mixed
    {
        $bayi = $this->tenant();
        $aylik = $this->plan()->aylikKurus();
        $yillik = $this->plan()->yillikKurus();

        return view('livewire.site.subscribe', [
            'bayi' => $bayi,
            'sirket' => $this->sirket(),
            // Tasarımın "2 ay hediye" rozeti SABİT yazılmadı: fiyatlar panelden değişebilir ve
            // hediye ay sayısı o değişimle birlikte yalan olurdu.
            'hediyeAy' => $aylik > 0 ? (int) round(($aylik * 12 - $yillik) / $aylik) : 0,
            'donemAralik' => $this->donemAralik(),
            'paket' => $this->tur === 'paket' ? $this->paketBul((string) $this->paketId) : null,
            'iptalUrl' => $this->iptalUrl(),
        ]);
    }

    /**
     * "Vazgeç" hedefi. Anahtar → rota çevirisi BURADA ve yalnız burada olur.
     *
     * VARSAYILAN `site.hesap` (eskiden abonelikte `site.fiyatlar`di). Gerekçe: Fiyatlandırma
     * sayfası üst menüden kalkıyor ve zaten ödeme ekranına hiç bağlantı vermiyor — vazgeçen bayiyi
     * oraya bırakmak onu menüsü olmayan bir pazarlama sayfasında yalnız bırakmak olurdu. Ödeme
     * ekranına misafir giremez (`mount()` girişe atar), yani "hesabı olmayana hesap sayfası
     * gösterme" diye bir durum yok. 'fiyatlar' anahtarı listede DURUYOR: o sayfadan bir gün
     * bağlantı verilirse dönüş yine doğru yere olsun.
     *
     * `Route::has()` kontrolü süs değil: rota adları bu dosyanın DIŞINDA (routes/web.php) yaşıyor.
     * Kaldırılan bir rota, ödeme sayfasını komple 500'e düşüren bir istisnaya dönüşürdü — ödeme
     * yüzeyinde ödenecek bedel bu değil.
     */
    private function iptalUrl(): string
    {
        [$ad, $parametre] = self::GERI_HEDEFLERI[$this->geri] ?? [null, []];

        return $ad !== null && Route::has($ad) ? route($ad, $parametre) : route('site.hesap');
    }

    /** KDV %20 DAHİL fiyattan ayrıştırılır (tasarımın `OdemeOzet`i ile aynı hesap). */
    public function kdvKurus(): int
    {
        return (int) round($this->tutarKurus - $this->tutarKurus / 1.2);
    }

    private function beyanYaz(string $yontem): void
    {
        /*
         * ÜÇ ONAY DA ZORUNLU. Kural BURADA TEKRARLANMAZ: `manuelCheckout` onları
         * `startCheckout` ile AYNI private yardımcıdan okur (`assertConsents`), yani hukuk metni
         * listesi değişince tek yerden değişir. Burada bir kopya tutmak, iki kuralın sessizce
         * ayrışacağı gün için bekleyen bir tuzak olurdu.
         *
         * Kabul edilen SÜRÜMLER de artık `note` metnine gömülmüyor: `payment_notifications`ta
         * `consent_version` + `consented_at` kolonları var (ikisi DB CHECK'le birlikte yolculuk
         * ediyor — "sürüm var, zaman yok" satırı doğamıyor).
         */
        try {
            app(SubscriptionService::class)->manuelCheckout(
                tenantId: $this->tenant()->id,
                amountKurus: $this->tutarKurus,
                method: $yontem,
                consents: [
                    'distance_sales' => $this->mesafeliSatis,
                    'preinfo' => $this->onBilgilendirme,
                    'kvkk' => $this->kvkk,
                ],
                referenceCode: $this->referans,
                note: $this->kalemAdi(),
            );
        } catch (ConsentRequiredException|GecersizTutarException $e) {
            $this->addError('onaylar', $e->getMessage());

            return;
        }

        $this->tesekkurYol = $yontem;
        $this->tesekkur = true;
    }

    public function kalemAdi(): string
    {
        if ($this->tur === 'paket') {
            $paket = $this->paketBul((string) $this->paketId);

            return 'Oto-sıralama · '.($paket === null ? 0 : $paket->quantity).' hak';
        }

        return 'Sipario · '.$this->donemEnum()->etiket().' abonelik';
    }

    /** Yıllıkta "12 ay", aylıkta "1 ay" + gerçek tarih aralığı. */
    private function donemAralik(): string
    {
        if ($this->tur === 'paket') {
            return 'Tek seferlik · süresi dolmaz';
        }

        $taban = $this->taban();
        $bitis = $this->donemEnum()->uzat($taban);
        $ay = $this->donemEnum() === BillingPeriod::Yearly ? '12 ay' : '1 ay';

        return $this->kisaTarih($taban).' – '.$this->kisaTarih($bitis).' · '.$ay;
    }

    /**
     * Dönem tabanı `valid_until > now ? valid_until : now` — `SubscriptionService::activate()` ve
     * `OdemeKayitServisi` ile AYNI kural. Süresi dolmadan yenileyen bayinin kalan günleri yanmaz;
     * ekranda başka bir tarih göstermek de sunucuyla çelişmek olurdu.
     */
    private function taban(): Carbon
    {
        $gecerli = $this->tenant()->valid_until;

        return ($gecerli !== null && $gecerli->greaterThan(now())) ? $gecerli->copy() : now();
    }

    private function kisaTarih(Carbon $t): string
    {
        return $t->locale('tr')->translatedFormat('j M Y');
    }

    private function tutarHesapla(): int
    {
        if ($this->tur === 'paket') {
            $paket = $this->paketBul((string) $this->paketId);

            return $paket === null ? 0 : $paket->price_kurus;
        }

        return $this->plan()->donemKurus($this->donemEnum());
    }

    private function paketBul(string $id): ?AddonPackage
    {
        if ($id === '') {
            return null;
        }

        return (new EkPaketServisi)->paketler(true)->firstWhere('id', $id);
    }

    private function donemEnum(): BillingPeriod
    {
        return BillingPeriod::tryFrom($this->donem) ?? BillingPeriod::Yearly;
    }

    private function plan(): PlanDeposu
    {
        return new PlanDeposu('pgsql_owner');
    }

    private function tenant(): Tenant
    {
        // Owner bağlantısı: web isteğinde `app.tenant_id` kurulmadığı için RLS'li varsayılan
        // bağlantı `tenants`ta sıfır satır görür.
        return $this->bayi ??= Tenant::on('pgsql_owner')->findOrFail((string) $this->bayiKimligi());
    }

    /**
     * Oturumdaki bayi — `auth:web` kullanıcısı ya da (Faz 5b'den kalan) oturum anahtarı.
     *
     * `check()` ile sorulur: `user()` doğrudan çağrılıp null gelirse Laravel'in hata yakalayıcısı
     * uyarıyı ErrorException'a çevirir ve misafir istek 500 olurdu.
     */
    private function bayiKimligi(): ?string
    {
        $id = Auth::guard('web')->check()
            ? (string) Auth::guard('web')->user()->tenant_id
            : (string) session('subscription_tenant_id', '');

        return $id === '' ? null : $id;
    }
}
