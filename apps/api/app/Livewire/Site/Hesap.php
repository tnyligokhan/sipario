<?php

namespace App\Livewire\Site;

use App\Abonelik\EkPaketServisi;
use App\Abonelik\KuryeKotasi;
use App\Abonelik\OdemeBildirimServisi;
use App\Abonelik\PlanDeposu;
use App\Enums\BillingPeriod;
use App\Enums\TenantStatus;
use App\Enums\UserRole;
use App\Livewire\Site\Forms\IsletmeFormu;
use App\Livewire\Site\Forms\ParaBicimi;
use App\Livewire\Site\Forms\SirketKunyesi;
use App\Models\AddonPackage;
use App\Models\Customer;
use App\Models\Device;
use App\Models\Order;
use App\Models\PaymentNotification;
use App\Models\Product;
use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Contracts\View\View;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Locked;
use Livewire\Component;
use Throwable;

/**
 * BAYİNİN HESAP PANELİ (tasarım: 14-sw-hesap.jsx) — 6 bölüm: genel bakış · abonelik · oto-sıralama ·
 * faturalar · ödeme yöntemi · işletme bilgileri.
 *
 * KIRMIZI ÇİZGİ #1: her sorgu OTURUMDAKİ bayiye bağlıdır. `$bayiId` `#[Locked]`tır, yalnız
 * `mount()` yazar; hiçbir eylem istemciden tenant kimliği ALMAZ.
 *
 * BAĞLANTI SEÇİMİ İKİYE AYRILIR ve ayrım bilinçlidir:
 *
 *  - ABONELİK/PARA tabloları (`tenants`, `subscription_payments`, `payment_notifications`,
 *    `addon_packages`, `plans`) → `pgsql_owner`. `sipario_app`in bu tablolarda HİÇ izni yoktur
 *    (grant matrisi bilerek öyle kuruldu: public site iş verisine dokunmaz, abonelik de kiracı-üstü
 *    bir kayıttır). Burada RLS bir seçenek değil; izolasyonu kod sağlar ve filtre TEK yerde durur.
 *
 *  - BAYİNİN İŞ VERİSİ (`customers`, `products`, `orders`, `devices`, `users`) → RLS'li `pgsql`,
 *    kiracı bağlamı kurulmuş hâlde (`isVerisinde`). Bu tablolarda `sipario_app`in izni VARDIR,
 *    yani veritabanının kendi zorlaması bedava gelir: bir gün `where tenant_id` yazmayı unutan
 *    olsa bile politika yanlış satırı döndürmez. Bedava gelen bir emniyeti kullanmamak için
 *    sebep yok.
 *
 * DENEME / ABONE İKİ DURUMU GERÇEK VERİDEN GELİR (`tenants.status`). Tasarımdaki "Önizleme:
 * Deneme / Abone" anahtarı bir PROTOTİP ARACIydı — yazılmadı; hesap durumunu istemciye seçtiren
 * bir düğme, ekranın söylediği her şeyi kanıt olmaktan çıkarırdı.
 *
 * "14 gün" metinleri PLANDAN gelen gerçek süreye çevrildi (OKU-BENI kararı: 30 gün).
 */
#[Layout('components.layouts.site', ['baslik' => 'Hesabım · Sipario', 'oturum' => true])]
class Hesap extends Component
{
    use ParaBicimi, SirketKunyesi;

    /** Oturumdaki bayi — istemci DEĞİŞTİREMEZ (kirmizi çizgi #1'in runtime yarısı). */
    #[Locked]
    public string $bayiId = '';

    /** Açık bölüm: genel|abonelik|hak|fatura|odeme|isletme. */
    public string $bolum = 'genel';

    public IsletmeFormu $isletme;

    /** @var array<string, string> */
    public const BOLUMLER = [
        'genel' => 'Genel bakış',
        'abonelik' => 'Abonelik',
        'hak' => 'Oto-sıralama',
        'fatura' => 'Faturalar',
        'odeme' => 'Ödeme yöntemi',
        'isletme' => 'İşletme bilgileri',
    ];

    public function mount(): mixed
    {
        // `check()` ile sorulur: `user()` doğrudan çağrılıp null gelirse Laravel'in hata
        // yakalayıcısı uyarıyı ErrorException'a çevirir ve misafir istek 500 olurdu.
        $id = Auth::guard('web')->check()
            ? (string) Auth::guard('web')->user()->tenant_id
            : (string) session('subscription_tenant_id', '');

        if ($id === '') {
            return $this->redirect(route('subscription.login'), navigate: false);
        }

        $this->bayiId = $id;
        $this->isletme->doldur($this->bayi());

        return null;
    }

    public function bolumSec(string $bolum): void
    {
        if (isset(self::BOLUMLER[$bolum])) {
            $this->bolum = $bolum;
        }
    }

    /** İşletme + fatura bilgilerini kaydeder. Yetki kapısı formun kendi içindedir. */
    public function isletmeKaydet(): void
    {
        $sonuc = $this->isletme->kaydet($this->bayi());

        $this->bayiNesnesi = null; // ad/kod değişmiş olabilir; bir sonraki okuma tazesini alsın
        $this->dispatch('bildir', detail: $sonuc);
    }

    /**
     * "Verilerimi dışa aktar" — BRIEF kırmızı çizgisi: uygulamada/sitede İNDİRME DÜĞMESİ YOK,
     * dışa aktarım yönetim panelinde BİZDE. Bayi bir TALEP bırakır.
     *
     * Talep gerçekten bir yere gider: destek kutusuna e-posta. Yalnız bir toast basıp hiçbir şey
     * yapmamak, tasarımın "e-posta ile göndereceğiz" cümlesini yalana çevirirdi. Kayıt tutan bir
     * talep kuyruğu tablosu yok (raporlandı) — o gelene kadar meşru kanal destek kutusudur.
     */
    public function disaAktarTalep(): void
    {
        $bayi = $this->bayi();
        $hedef = (string) config('subscription.company.support_email', 'destek@sipario.com.tr');

        try {
            Mail::raw(
                "Veri dışa aktarma talebi\n\nBayi : {$bayi->name}\nKod  : {$bayi->slug}\n"
                ."Bayi id: {$bayi->id}\nYetkili: {$this->isletme->yetkili}\nE-posta: {$this->isletme->eposta}",
                fn ($m) => $m->to($hedef)->subject('Sipario · veri dışa aktarma talebi · '.$bayi->slug),
            );
        } catch (Throwable $e) {
            report($e);
            $this->dispatch('bildir', detail: 'Talep iletilemedi, destek hattından ulaşın');

            return;
        }

        $this->dispatch('bildir', detail: 'Dışa aktarma hazırlanıyor, e-posta ile göndereceğiz');
    }

    public function cikis(): mixed
    {
        Auth::guard('web')->logout();
        session()->invalidate();
        session()->regenerateToken();

        return $this->redirect(route('site.ana'), navigate: false);
    }

    public function render(): View
    {
        return view('livewire.site.hesap');
    }

    // ── Bayi ve durum ────────────────────────────────────────────────────────

    /** İstek içi bellek — bir sayfa çiziminde bayi satırı bir kez okunur. */
    private ?Tenant $bayiNesnesi = null;

    public function bayi(): Tenant
    {
        return $this->bayiNesnesi ??= Tenant::on('pgsql_owner')->findOrFail($this->bayiId);
    }

    public function deneme(): bool
    {
        return $this->bayi()->status === TenantStatus::Trial;
    }

    /** Dönem sonuna kalan gün (negatife düşmez — süresi dolmuşsa 0). */
    public function kalanGun(): int
    {
        $bitis = $this->bayi()->valid_until;

        return $bitis === null ? 0 : max(0, (int) floor(now()->diffInDays($bitis, false)));
    }

    /**
     * Çubuğun paydası. Denemede plandaki deneme süresi; abonelikte GERÇEK dönem uzunluğu
     * (yıllık 365/366, aylık 28–31) — sabit 30/365 yazmak şubatta çubuğu yalancı yapardı.
     */
    public function toplamGun(): int
    {
        if ($this->deneme()) {
            return max(1, $this->plan()->denemeGun());
        }

        $bitis = $this->bayi()->valid_until ?? now();
        $baslangic = $this->donem() === BillingPeriod::Yearly
            ? $bitis->copy()->subYear()
            : $bitis->copy()->subMonthNoOverflow();

        return max(1, (int) $baslangic->diffInDays($bitis));
    }

    public function donem(): BillingPeriod
    {
        return $this->bayi()->billing_period ?? BillingPeriod::Yearly;
    }

    public function sonrakiTutar(): int
    {
        return $this->plan()->donemKurus($this->donem());
    }

    public function tarih(?Carbon $t): string
    {
        return $t === null ? '—' : $t->locale('tr')->translatedFormat('j F Y');
    }

    // ── Kotalar ──────────────────────────────────────────────────────────────

    /**
     * Oto-sıralama kotası. `route_credits` KALAN bakiyedir, `route_credits_monthly` aylık yenileme
     * miktarı; kullanım ayrı bir yerde tutulmuyor. Payda bu yüzden ikisinin BÜYÜĞÜdür — satın
     * alınan ek paket bakiyeyi aylık kotanın üstüne çıkarır ve payda sabit kalsaydı çubuk %100'ü
     * aşardı. "Kalan" her hâlde gerçektir; ekranda asla abartılmaz.
     *
     * @return array{kullanilan: int, toplam: int, kalan: int}
     */
    public function hakKotasi(): array
    {
        $bayi = $this->bayi();
        $toplam = max($bayi->route_credits_monthly, $bayi->route_credits, 1);

        return [
            'kullanilan' => max(0, $toplam - $bayi->route_credits),
            'toplam' => $toplam,
            'kalan' => max(0, $bayi->route_credits),
        ];
    }

    /**
     * Kurye kotası. Sayım `users` üzerindedir ve o tabloya `sipario_app`in izni vardır → RLS'li
     * bağlantı. Servis zaten `tenant_id` ile açıkça filtreler; politika ikinci kilittir.
     *
     * @return array{limit: int, kullanilan: int, kalan: int}
     */
    public function kuryeKotasi(): array
    {
        return $this->isVerisinde(fn (): array => (new KuryeKotasi('pgsql'))->kullanim($this->bayi()));
    }

    // ── Para hareketleri ─────────────────────────────────────────────────────

    /**
     * Ödenmiş abonelik/ek paket kayıtları — tasarımın "Fatura geçmişi" tablosu.
     *
     * @return Collection<int, SubscriptionPayment>
     */
    #[Computed]
    public function odemeler(): Collection
    {
        return SubscriptionPayment::on('pgsql_owner')
            ->where('tenant_id', $this->bayiId)
            ->where('status', 'success')
            ->orderByDesc('occurred_at')
            ->limit(50)
            ->get();
    }

    /**
     * Bayinin kendi beyanları. Tasarımda YOK ama olmak zorunda: "Havale yaptım" diyen bayi,
     * beyanının bize ulaştığını ve henüz eşleşmediğini görebilmeli — yoksa ekran, tıkladığı
     * düğmenin hiçbir izini göstermez.
     *
     * @return Collection<int, PaymentNotification>
     */
    #[Computed]
    public function bildirimler(): Collection
    {
        return (new OdemeBildirimServisi)->bayiBildirimleri($this->bayiId, 10);
    }

    public function bekleyenBildirim(): ?PaymentNotification
    {
        return $this->bildirimler()->firstWhere('status', PaymentNotification::STATUS_PENDING);
    }

    /** Ödeme yönteminin insan okunur adı (subscription_payments.provider). */
    public function yontemAdi(?string $provider): string
    {
        return match ($provider) {
            'iban' => 'Havale / EFT',
            'elden' => 'Elden',
            'bedelsiz' => 'Bedelsiz',
            'iyzico' => 'Kart',
            default => '—',
        };
    }

    /** Bir ödeme satırının kalem adı (period kolonundan). */
    public function kalemAdi(SubscriptionPayment $odeme): string
    {
        if ($odeme->period === SubscriptionPayment::PERIOD_ADDON) {
            return $odeme->covers_period ?: 'Ek paket';
        }

        $donem = BillingPeriod::tryFrom((string) $odeme->period)?->etiket() ?? 'Abonelik';

        return 'Sipario · '.$donem.($odeme->covers_period ? ' ('.$odeme->covers_period.')' : '');
    }

    // ── Ek paketler ──────────────────────────────────────────────────────────

    /**
     * Satıştaki oto-sıralama paketleri. FİYATLAR SABİT YAZILMAZ — katalog panelden yönetilir.
     *
     * @return Collection<int, AddonPackage>
     */
    #[Computed]
    public function hakPaketleri(): Collection
    {
        return (new EkPaketServisi)->paketler(true)
            ->where('type', AddonPackage::TYPE_CREDITS)
            ->values();
    }

    // ── Kurulum kontrol listesi (deneme) ─────────────────────────────────────

    /**
     * Tasarımın kurulum listesi — DURUMLAR GERÇEK. Sabit `bitti: true/false` yazmak, hiçbir şey
     * yapmamış bayiye "üç adımı tamamladın" demek olurdu.
     *
     * Bu blok bayinin İŞ VERİSİNİ okur ve bu yüzden `tenants`/`subscription_payments`tan FARKLI
     * davranır: o tablolarda `sipario_app`in hiç izni yoktur (owner zorunlu), burada VARDIR — yani
     * veritabanının kendi zorlaması bedava gelir ve kullanılmaması için sebep yok. `where tenant_id`
     * yine yazılıyor ama artık tek savunma değil: politika, unutulsa bile yanlış satırı döndürmez
     * (kırmızı çizgi #1).
     *
     * @return list<array{ad: string, alt: string, bitti: bool}>
     */
    #[Computed]
    public function kurulum(): array
    {
        $bayi = $this->bayi();

        [$musteri, $urun, $siparis, $cihaz, $kurye] = $this->isVerisinde(function (): array {
            $say = fn (string $sinif): int => $sinif::query()
                ->where('tenant_id', $this->bayiId)->whereNull('deleted_at')->count();

            return [
                $say(Customer::class),
                $say(Product::class),
                $say(Order::class),
                Device::query()->where('tenant_id', $this->bayiId)->count(),
                User::query()->where('tenant_id', $this->bayiId)
                    ->where('role', UserRole::Kurye->value)->where('status', 'active')->count(),
            ];
        });

        return [
            ['ad' => 'İşletme hesabı açıldı', 'alt' => $this->tarih($bayi->created_at), 'bitti' => true],
            ['ad' => 'Uygulamayı telefonunuza kurdunuz',
                'alt' => $cihaz > 0 ? $cihaz.' cihaz bağlı' : 'Henüz cihaz bağlanmadı', 'bitti' => $cihaz > 0],
            ['ad' => 'İlk müşterinizi ekleyin',
                'alt' => $musteri > 0 ? 'Şu an '.$musteri.' müşteri kayıtlı' : 'Henüz müşteri yok', 'bitti' => $musteri > 0],
            ['ad' => 'Ürün ve fiyatlarınızı girin',
                'alt' => $urun > 0 ? 'Şu an '.$urun.' ürün kayıtlı' : 'Damacana, pet su, tüp…', 'bitti' => $urun > 0],
            ['ad' => 'Kurye hesabı oluşturun',
                'alt' => $kurye > 0 ? $kurye.' kurye hesabı açık' : 'Kurye telefonundan siparişleri görür', 'bitti' => $kurye > 0],
            ['ad' => 'İlk siparişi kaydedin',
                'alt' => $siparis > 0 ? 'Şu an '.$siparis.' sipariş kayıtlı' : 'Telefon çaldığında müşteri ekranda', 'bitti' => $siparis > 0],
        ];
    }

    // ── Yardımcılar ──────────────────────────────────────────────────────────

    /**
     * Bayinin İŞ VERİSİNDEN okuma — RLS'li `pgsql` bağlantısında, kiracı bağlamı kurulmuş hâlde.
     *
     * BAĞLAM BURADA KURULUR, middleware'e bel bağlanmaz. `ResolveTenantContext` istek yolunda
     * çalışır ama bileşen HTTP dışı bağlamlardan da (test, konsol) çağrılabilir; orada bağlamsız
     * bir sorgu politika gereği SIFIR satır döndürür ve bu hata SESSİZDİR — kurulum listesindeki
     * her adım "yapılmamış" görünür, kimse de bunu bir arıza sanmaz. Bağlamı kendimiz kurunca hem
     * veritabanının zorlaması kazanılır hem de bu sessiz arıza kapanır.
     *
     * `set_config(..., true)` LOCAL'dir → transaction ömrü kadar yaşar, sonra kendiliğinden
     * sıfırlanır (PanelSyncYazici::rlsIcinde deseni).
     *
     * @template T
     *
     * @param  callable():T  $is
     * @return T
     */
    private function isVerisinde(callable $is): mixed
    {
        $onceki = DB::getDefaultConnection();
        DB::setDefaultConnection('pgsql');

        try {
            return DB::connection('pgsql')->transaction(function () use ($is) {
                DB::connection('pgsql')->statement(
                    "SELECT set_config('app.tenant_id', ?, true)", [$this->bayiId]
                );

                return $is();
            });
        } finally {
            DB::setDefaultConnection($onceki);
        }
    }

    public function plan(): PlanDeposu
    {
        return new PlanDeposu('pgsql_owner');
    }

    /** Ödeme ekranına giden bağlantı (dönem ya da ek paket seçili). */
    public function odemeUrl(?string $donem = null, ?string $paketId = null): string
    {
        return $paketId !== null
            ? route('subscription.subscribe', ['tur' => 'paket', 'paket' => $paketId])
            : route('subscription.subscribe', ['tur' => 'plan', 'donem' => $donem ?? $this->donem()->value]);
    }
}
