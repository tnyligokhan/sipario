<?php

namespace App\Livewire\Panel;

use App\Abonelik\GecersizTutarException;
use App\Abonelik\OdemeKayitServisi;
use App\Abonelik\PlanDeposu;
use App\Enums\BillingPeriod;
use App\Livewire\Panel\Concerns\Bicim;
use App\Livewire\Panel\Concerns\ParaEkrani;
use App\Livewire\Panel\Forms\OdemeForm;
use App\Models\Tenant;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Locked;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * ÖDEMELER (tasarım `08-OdemeEkleModal.jsx` · Odemeler + OdemeEkleModal).
 *
 * Ay süzgeci + firma araması + liste; sağ üstte elle ödeme kaydı. Panelin EN HASSAS yetkisi
 * burada: bir satır, bir bayinin aboneliğini uzatır.
 *
 * ÇİFT TIKLAMA KALKANI ÜÇ KATLIDIR ve asıl kalkan üçüncüsüdür:
 *   1. `wire:loading.attr="disabled"` — düğme gönderim boyunca pasif (görsel/kullanıcı katmanı).
 *   2. `$gonderiliyor` bayrağı — aynı bileşenden gelen ikinci çağrı sessizce döner.
 *   3. `$odemeAnahtari` — modal AÇILIRKEN üretilen kararlı `provider_ref`. `OdemeKayitServisi`
 *      idempotensi bu referansa bağlar; anahtar null geçilirse servis HER çağRIDA benzersiz bir
 *      tane üretir, yani idempotens çağırandadır. İlk ikisi tarayıcı/istek yarışlarına karşı
 *      koruyabildikleri kadar korur; üçüncüsü iki isteğin gerçekten paralel koştuğu durumda bile
 *      TEK aktivasyon üretir (DB'deki kısmi tekil indeks son emniyet).
 *
 * Anahtar `#[Locked]`: istemci onu değiştirebilseydi kalkanı kendisi kaldırabilirdi.
 *
 * OKUMALAR `pgsql_panel` (yalnız SELECT) ile; YAZMA servisin varsayılan `pgsql_owner`ıyla — ödeme
 * satırı + tenant uzatma tek transaction olmak zorunda (005010: panel rolü buraya YAZAMAZ).
 *
 * SÜZGEÇ VE SAYFALAMA TAMAMEN SUNUCUDA: ay, firma araması ve sayfa `OdemeKayitServisi`in tek
 * sorgu kaynağından geçer. Önceden liste bellekte süzülüyordu ve servisin 500 satırlık tavanı
 * yüzünden ARAMA DA o 500 satırın içinde çalışıyordu — eski bir bayiyi aratınca ekran "kayıt yok"
 * diyordu. Başlıktaki "N kayıt · toplam X" ayrı bir özet çağrısıyla gelir; paginator tutarı
 * taşımaz ve sayfa toplamını göstermek yanıltıcı olurdu.
 *
 * Firma adı EAGER ilişkiden gelir (`->with('tenant')`); bayi adlarını ayrıca `pluck`layıp bellekte
 * eşleyen eski kod kaldırıldı — o yol tüm bayileri her turda çekiyordu.
 */
#[Layout('components.layouts.panel')]
#[Title('Ödemeler')]
class Odemeler extends Component
{
    use ParaEkrani;
    use WithPagination;

    private const SAYFA_BOY = 25;

    private const SAYFA_ADI = 'osayfa';

    /** `subscription_payments.provider` → ekran etiketi. */
    private const YONTEM_ETIKET = [
        'iban' => 'IBAN',
        'elden' => 'Elden',
        'iyzico' => 'İyzico',
        'fake' => 'Test',
    ];

    /** '' = tüm aylar, aksi hâlde 'YYYY-MM'. */
    #[Url(as: 'ay')]
    public string $ay = '';

    public string $arama = '';

    public bool $modalAcik = false;

    public OdemeForm $form;

    /** Bkz. sınıf başlığı — çift tıklamanın gerçek kalkanı. */
    #[Locked]
    public ?string $odemeAnahtari = null;

    public bool $gonderiliyor = false;

    /** @var array{tur: string, mesaj: string}|null */
    public ?array $bildirim = null;

    private ?PlanDeposu $planDeposu = null;

    public function mount(): void
    {
        $this->panelOturumu();
    }

    public function updatedAy(): void
    {
        $this->resetPage(self::SAYFA_ADI);
    }

    public function updatedArama(): void
    {
        $this->resetPage(self::SAYFA_ADI);
    }

    // --- Ödeme Ekle modalı ---------------------------------------------------------------

    public function odemeModalAc(): void
    {
        $this->paraYetkisi('payment_manual');

        $this->form->reset();
        $this->bildirim = null;
        $this->gonderiliyor = false;

        // EKRANIN günü (+03:00), sunucununki (UTC) değil: gece 00:00–03:00 arasında modal dünün
        // tarihini ve ayın ilk gecesinde ÖNCEKİ AYIN dönemini varsayılan yapardı.
        $bugun = Bicim::bugun();
        $this->form->tarih = $bugun->toDateString();
        $this->form->kapsam = $bugun->format('Y-m');
        $this->form->donem = BillingPeriod::Monthly->value;
        $this->form->tutar = Bicim::lira($this->plan()->donemKurus(BillingPeriod::Monthly));

        // Kararlı idempotens anahtarı MODAL AÇILIRKEN doğar: aynı modaldan gelen her gönderim aynı
        // referansı taşır. Kullanıcı gerçekten ikinci bir ödeme girmek isterse modalı yeniden
        // açar ve yeni anahtar üretilir.
        $this->odemeAnahtari = 'manual:'.Str::uuid7();
        $this->modalAcik = true;
    }

    public function odemeModalKapat(): void
    {
        $this->modalAcik = false;
        $this->odemeAnahtari = null;
        $this->gonderiliyor = false;
        $this->bildirim = null;
        $this->form->reset();
        $this->resetValidation();
    }

    /**
     * Firma ya da dönem değişince tutar varsayılanı tazelenir (tasarımda tutar plan ücretiyle
     * açılıyordu; artık iki fiyat var). Firma seçimi ayrıca bayinin KENDİ dönemini getirir —
     * yıllık ödeyen bir bayiye varsayılan olarak aylık teklif etmek, bir tık ihmalle
     * aboneliğini 11 ay eksik uzatırdı.
     */
    public function updated(string $ad, mixed $deger): void
    {
        if ($ad === 'form.firmaId') {
            $tenant = $this->firmaBul($this->form->firmaId);
            if ($tenant !== null) {
                $this->form->donem = ($tenant->billing_period ?? BillingPeriod::Monthly)->value;
            }
        }

        if ($ad === 'form.firmaId' || $ad === 'form.donem') {
            $this->form->tutar = Bicim::lira($this->plan()->donemKurus($this->secilenDonem()));
        }
    }

    public function odemeKaydet(): void
    {
        $this->paraYetkisi('payment_manual', $this->form->firmaId);

        // Bayrak: aynı bileşenden gelen ikinci gönderim sessizce döner (kalkan 2/3).
        if ($this->gonderiliyor) {
            return;
        }

        $this->bildirim = null;
        $this->form->validate();

        $kurus = $this->form->tutarKurus();
        if ($kurus === null || $kurus <= 0 || $kurus > Bicim::TAVAN_KURUS) {
            // Reddedilen deneme denetime düşer; SEBEP kategoriktir, girilen TUTAR yazılmaz.
            $this->redKaydet('payment_manual', self::RED_GECERSIZ_TUTAR, $this->form->firmaId);
            $this->addError('form.tutar', $kurus !== null && $kurus > Bicim::TAVAN_KURUS
                ? 'Tutar çok büyük; lütfen kontrol edin.'
                : 'Tutar sıfırdan büyük bir sayı olmalıdır.');

            return;
        }

        $tenant = $this->firmaBul($this->form->firmaId);
        if ($tenant === null) {
            $this->redKaydet('payment_manual', self::RED_FIRMA_YOK);
            $this->addError('form.firmaId', 'Firma bulunamadı; listeyi tazeleyip tekrar deneyin.');

            return;
        }

        $this->gonderiliyor = true;

        try {
            $sonuc = (new OdemeKayitServisi)->kaydet(
                tenantId: $tenant->id,
                amountKurus: $kurus,
                method: $this->form->yontem,
                coversPeriod: $this->form->kapsamEtiketi(),
                period: $this->secilenDonem(),
                note: trim($this->form->not) !== '' ? trim($this->form->not) : null,
                adminId: $this->adminId(),
                occurredAt: Carbon::parse($this->form->tarih),
                providerRef: $this->odemeAnahtari,
            );
        } catch (GecersizTutarException $e) {
            $this->gonderiliyor = false;
            // Servis reddi de bir denemedir; mesaj KULLANICIYA gider, günlüğe SEBEP KODU yazılır.
            $this->redKaydet('payment_manual', self::RED_SERVIS, $tenant->id);
            $this->bildirim = ['tur' => 'hata', 'mesaj' => $e->getMessage()];

            return;
        }

        $bitis = Bicim::tarihKisa($sonuc['tenant']->valid_until);

        $this->modalAcik = false;
        $this->odemeAnahtari = null;
        $this->gonderiliyor = false;
        $this->form->reset();
        $this->resetValidation();
        $this->resetPage(self::SAYFA_ADI);

        $this->dispatch('tost', mesaj: 'Ödeme kaydedildi · abonelik bitişi '.$bitis.' oldu');
    }

    // --- Görünüm -------------------------------------------------------------------------

    public function render(): mixed
    {
        $this->panelOturumu();

        $servis = new OdemeKayitServisi('pgsql_panel');
        $ay = $this->gecerliAy();
        $arama = trim($this->arama);

        // Üçü de AYNI süzgeci paylaşır (servisin tek sorgu kaynağı): sayfa, başlıktaki özet ve
        // ay listesi ayrışamaz. Özet AYRI çağrıdır çünkü paginator tutarı taşımaz — `total()`
        // adedi verir, "bu sayfanın toplamı"nı göstermek kullanıcıyı yanıltırdı.
        $sayfa = $servis->odemelerSayfali($ay !== '' ? $ay : null, $arama !== '' ? $arama : null, self::SAYFA_BOY, self::SAYFA_ADI);
        $ozet = $servis->odemeOzeti($ay !== '' ? $ay : null, $arama !== '' ? $arama : null);
        $aylar = $servis->aylar();

        return view('livewire.panel.odemeler', [
            // Paginator SATIRLARI DÖNÜŞTÜRÜLMEDEN geçirilir: servisin dönüş tipi
            // `Contracts\Pagination\LengthAwarePaginator` arayüzüdür ve o arayüz `through()`
            // vaat etmez. Sunumu view yapar (Paketler'de olduğu gibi, model üzerinden).
            'sayfa' => $sayfa,
            'yontemEtiket' => self::YONTEM_ETIKET,
            'kayitSayisi' => $ozet['adet'],
            'toplamKurus' => $ozet['toplam_kurus'],
            'aylar' => $this->aySecenekleri($aylar),
            // Hiç ödeme yoksa ay listesi de boştur — ayrı bir sayım sorgusu gerekmiyor.
            'hicKayitYok' => $aylar === [],
            // Firma listesi YALNIZ modal açıkken üretilir: kombo tüm bayileri JSON olarak sayfaya
            // gömer ve kapalı bir modal için her turda o listeyi basmanın anlamı yok.
            'firmalar' => $this->modalAcik ? $this->firmaListesi() : [],
            'donemler' => Bicim::donemSecenekleri(),
            'superadmin' => $this->superadminMi(),
        ]);
    }

    /** URL'den gelen ay 'YYYY-MM' değilse süzgeç yok sayılır (uydurma değer sorguya girmez). */
    private function gecerliAy(): string
    {
        return preg_match('/^\d{4}-\d{2}$/', $this->ay) === 1 ? $this->ay : '';
    }

    private function secilenDonem(): BillingPeriod
    {
        return BillingPeriod::tryFrom($this->form->donem) ?? BillingPeriod::Monthly;
    }

    /**
     * Ay süzgecinin seçenekleri. Liste `OdemeKayitServisi::aylar()`dan gelir — ÖDEME görmüş aylar.
     * Eskiden `GelirGiderRaporu::aylikOzet()` çıktısı `gelir_kurus > 0` ile süzülüyordu; o rapor
     * gelir VE gideri birleştirdiği için masraf girilmiş ama ödeme alınmamış ayları da taşıyordu.
     * Süzgeç ödemelerin üzerinde olduğuna göre listesi de orada durmalı.
     *
     * @param  list<string>  $aylar
     * @return array<string, string>
     */
    private function aySecenekleri(array $aylar): array
    {
        $liste = [];
        foreach ($aylar as $ay) {
            $liste[$ay] = Bicim::ayAdi($ay);
        }

        return $liste;
    }

    /** @return list<array{id: string, ad: string, il: string}> */
    private function firmaListesi(): array
    {
        return Tenant::on('pgsql_panel')
            ->orderBy('name')
            ->get(['id', 'name', 'city'])
            ->map(fn (Tenant $t) => [
                'id' => (string) $t->id,
                'ad' => (string) $t->name,
                'il' => (string) ($t->city ?? ''),
            ])
            ->all();
    }

    private function firmaBul(?string $id): ?Tenant
    {
        if ($id === null || ! Str::isUuid($id)) {
            return null;
        }

        return Tenant::on('pgsql_panel')->find($id);
    }

    /** İstek başına tek örnek: PlanDeposu kendi içinde önbelleklidir, yenisini kurmak onu boşa çıkarır. */
    private function plan(): PlanDeposu
    {
        return $this->planDeposu ??= new PlanDeposu('pgsql_panel');
    }
}
