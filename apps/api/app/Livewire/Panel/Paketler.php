<?php

namespace App\Livewire\Panel;

use App\Abonelik\EkPaketServisi;
use App\Abonelik\GecersizTutarException;
use App\Abonelik\PlanDeposu;
use App\Livewire\Panel\Concerns\Bicim;
use App\Livewire\Panel\Concerns\ParaEkrani;
use App\Livewire\Panel\Forms\PaketForm;
use App\Livewire\Panel\Forms\PlanForm;
use App\Livewire\Panel\Forms\TanimlaForm;
use App\Models\AddonPackage;
use App\Models\Tenant;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Locked;
use Livewire\Attributes\Title;
use Livewire\Component;

/**
 * PAKETLER (tasarım `09-PlanDuzenleModal.jsx` · Paketler + PlanDuzenleModal + EkPaketModal + TanimlaModal).
 *
 * Üç kart: abonelik planı · ek paket kataloğu · son tanımlamalar. Üç modal.
 *
 * PLAN DÜZENLEME GEÇMİŞE DOKUNMAZ — tasarımın modal notu ("Yeni ücret bundan sonra girilecek
 * ödemelerde varsayılan olur; geçmiş kayıtlar değişmez") sunucuda GERÇEKTİR: `PlanDeposu::guncelle`
 * mevcut bayilerin `route_credits_monthly`/`courier_limit` kolonlarına dokunmaz. Metin bu yüzden
 * birebir taşındı.
 *
 * TANIMLAMA SÜRE DEĞİL KAPASİTE SATIŞIDIR: `valid_until` DEĞİŞMEZ (EkPaketServisi). Bedelsiz
 * tanımlamada tutar sıfıra kilitlenir — ekran, servis ve DB CHECK'i aynı şeyi ayrı ayrı söyler.
 *
 * ÇİFT GÖNDERİM ÜÇ KATLI KORUNUR (tanımlamada): `wire:loading.attr` + `$gonderiliyor` bayrağı +
 * `$tanimlamaAnahtari` (kararlı `addon_grants.id`). Üçüncüsü asıl kalkandır ve Ödemeler'dekiyle
 * aynı desendir — bkz. o alanın belgesi. Plan/paket düzenleme idempotens anahtarı İSTEMEZ: ikisi
 * de aynı satırı aynı değerlerle günceller, tekrarı yeni bir şey doğurmaz.
 */
#[Layout('components.layouts.panel')]
#[Title('Paketler')]
class Paketler extends Component
{
    use ParaEkrani;

    /** Ekranda görünen tür etiketleri tasarımdaki gibi; DB değerleri credits/courier. */
    private const TUR_ETIKET = [
        AddonPackage::TYPE_CREDITS => 'hak',
        AddonPackage::TYPE_COURIER => 'kurye',
    ];

    private const TAHSIL_ETIKET = [
        'iban' => 'IBAN',
        'elden' => 'Elden',
        'bedelsiz' => 'Bedelsiz',
    ];

    public bool $planModalAcik = false;

    public bool $paketModalAcik = false;

    public bool $tanimlaModalAcik = false;

    public PlanForm $planForm;

    public PaketForm $paketForm;

    public TanimlaForm $tanimlaForm;

    public bool $gonderiliyor = false;

    /**
     * ÇİFT TIKLAMA KALKANININ ÜÇÜNCÜ KATI — tanımlamanın kararlı kimliği.
     *
     * `EkPaketServisi::tanimla()` bu anahtarı `addon_grants.id` olarak kullanır ve kilidi
     * ALDIKTAN SONRA varlığını sorar; ikinci çağrı birincinin satırını görüp onu döndürür (birincil
     * anahtar çakışması da son emniyet). Anahtar null geçilirse servis her çağrıda yenisini üretir
     * ve idempotens KAYBOLUR.
     *
     * Burada ödemeden DAHA kritiktir: grant append-only'dir ve kota artışı (`route_credits` /
     * `courier_limit`) geri alınamaz — iki kez işlenmiş bir tanımlama elle düzeltme ister.
     *
     * `#[Locked]`: istemci değiştirebilseydi kalkanı kendisi kaldırabilirdi.
     */
    #[Locked]
    public ?string $tanimlamaAnahtari = null;

    /** @var array{tur: string, mesaj: string}|null */
    public ?array $bildirim = null;

    private ?PlanDeposu $planDeposu = null;

    public function mount(): void
    {
        $this->panelOturumu();
    }

    // --- Planı Düzenle -------------------------------------------------------------------

    public function planModalAc(): void
    {
        $this->paraYetkisi('plan_update');

        $depo = $this->plan();
        $this->planForm->doldur(
            $depo->plan(),
            $depo->aylikKurus(),
            $depo->yillikKurus(),
            $depo->denemeGun(),
            $depo->rotaKontoruAylik(),
            $depo->kuryeLimiti(),
        );

        $this->bildirim = null;
        $this->gonderiliyor = false;
        $this->planModalAcik = true;
    }

    public function planModalKapat(): void
    {
        $this->planModalAcik = false;
        $this->gonderiliyor = false;
        $this->bildirim = null;
        $this->planForm->reset();
        $this->resetValidation();
    }

    public function planKaydet(): void
    {
        $this->paraYetkisi('plan_update');

        if ($this->gonderiliyor) {
            return;
        }

        $this->bildirim = null;
        $this->planForm->validate();

        // Plan ücreti 0 OLABİLİR (ücretsiz plan meşru bir iş kararıdır); negatif olamaz.
        $aylik = $this->tutarDogrula($this->planForm->aylikKurus(), 'planForm.aylik', 'plan_update', sifirSerbest: true);
        $yillik = $this->tutarDogrula($this->planForm->yillikKurus(), 'planForm.yillik', 'plan_update', sifirSerbest: true);
        if ($aylik === null || $yillik === null) {
            return;
        }

        $this->gonderiliyor = true;

        try {
            (new PlanDeposu)->guncelle([
                'name' => trim($this->planForm->ad),
                'price_monthly_kurus' => $aylik,
                'price_yearly_kurus' => $yillik,
                'trial_days' => $this->planForm->denemeGun,
                'route_credits_monthly' => $this->planForm->hakAy,
                'courier_limit' => $this->planForm->kurye,
            ], $this->adminId());
        } catch (GecersizTutarException $e) {
            $this->gonderiliyor = false;
            // Servis reddi de bir denemedir; mesaj KULLANICIYA gider, günlüğe SEBEP KODU yazılır.
            $this->redKaydet('plan_update', self::RED_SERVIS);
            $this->bildirim = ['tur' => 'hata', 'mesaj' => $e->getMessage()];

            return;
        }

        $this->planModalAcik = false;
        $this->gonderiliyor = false;
        $this->planForm->reset();
        $this->resetValidation();
        $this->dispatch('tost', mesaj: 'Plan güncellendi');
    }

    // --- Ek Paket Ekle / Düzenle ---------------------------------------------------------

    public function paketModalAc(?string $id = null): void
    {
        $this->paraYetkisi('addon_package_edit');

        $this->paketForm->reset();
        $this->bildirim = null;
        $this->gonderiliyor = false;

        if ($id !== null) {
            $paket = AddonPackage::on('pgsql_panel')->find($this->uuidZorunlu($id, 'addon_package_edit'));
            if ($paket === null) {
                $this->redKaydet('addon_package_edit', self::RED_PAKET_YOK);
                abort(404);
            }
            $this->paketForm->doldur($paket);
        }

        $this->paketModalAcik = true;
    }

    public function paketModalKapat(): void
    {
        $this->paketModalAcik = false;
        $this->gonderiliyor = false;
        $this->bildirim = null;
        $this->paketForm->reset();
        $this->resetValidation();
    }

    public function paketKaydet(): void
    {
        $this->paraYetkisi('addon_package_edit');

        if ($this->gonderiliyor) {
            return;
        }

        $this->bildirim = null;
        $this->paketForm->validate();

        $ucret = $this->tutarDogrula($this->paketForm->ucretKurus(), 'paketForm.ucret', 'addon_package_edit', sifirSerbest: true);
        if ($ucret === null) {
            return;
        }

        $this->gonderiliyor = true;

        try {
            (new EkPaketServisi)->paketKaydet([
                'id' => $this->paketForm->paketId,
                'type' => $this->paketForm->tur,
                'name' => trim($this->paketForm->ad),
                'quantity' => $this->paketForm->adet,
                'price_kurus' => $ucret,
                'active' => $this->paketForm->aktifMi(),
            ], $this->adminId());
        } catch (GecersizTutarException $e) {
            $this->gonderiliyor = false;
            // "Düzenlenecek paket bulunamadı" da buradan çıkar (servis upsert YAPMAZ).
            $this->redKaydet('addon_package_edit', self::RED_SERVIS);
            $this->bildirim = ['tur' => 'hata', 'mesaj' => $e->getMessage()];

            return;
        }

        $yeni = $this->paketForm->paketId === null;

        $this->paketModalAcik = false;
        $this->gonderiliyor = false;
        $this->paketForm->reset();
        $this->resetValidation();
        $this->dispatch('tost', mesaj: $yeni ? 'Ek paket eklendi' : 'Paket güncellendi');
    }

    // --- Ek Paket Tanımla ----------------------------------------------------------------

    public function tanimlaModalAc(): void
    {
        $this->paraYetkisi('addon_grant');

        $this->tanimlaForm->reset();
        $this->bildirim = null;
        $this->gonderiliyor = false;
        // EKRANIN günü (+03:00), sunucununki (UTC) değil — bkz. Bicim::bugun().
        $this->tanimlaForm->tarih = Bicim::bugun()->toDateString();

        $ilk = $this->satistakiPaketler()->first();
        if ($ilk !== null) {
            $this->tanimlaForm->paketId = (string) $ilk->id;
            $this->tanimlaForm->tutar = Bicim::lira($ilk->price_kurus);
        }

        // Kararlı anahtar MODAL AÇILIRKEN doğar: aynı modaldan gelen her gönderim aynı grant
        // kimliğini taşır. Gerçekten ikinci bir tanımlama yapılacaksa modal yeniden açılır.
        $this->tanimlamaAnahtari = (string) Str::uuid7();
        $this->tanimlaModalAcik = true;
    }

    public function tanimlaModalKapat(): void
    {
        $this->tanimlaModalAcik = false;
        $this->tanimlamaAnahtari = null;
        $this->gonderiliyor = false;
        $this->bildirim = null;
        $this->tanimlaForm->reset();
        $this->resetValidation();
    }

    /**
     * Paket ya da tahsilat değişince tutar tazelenir: bedelsizde 0'a KİLİTLENİR (tasarımın
     * davranışı), aksi hâlde paketin liste fiyatı gelir.
     */
    public function updated(string $ad, mixed $deger): void
    {
        if ($ad !== 'tanimlaForm.paketId' && $ad !== 'tanimlaForm.tahsil') {
            return;
        }

        if ($this->tanimlaForm->bedelsizMi()) {
            $this->tanimlaForm->tutar = Bicim::lira(0);

            return;
        }

        $paket = $this->paketBul($this->tanimlaForm->paketId);
        if ($paket !== null) {
            $this->tanimlaForm->tutar = Bicim::lira($paket->price_kurus);
        }
    }

    public function tanimla(): void
    {
        $this->paraYetkisi('addon_grant', $this->tanimlaForm->firmaId);

        if ($this->gonderiliyor) {
            return;
        }

        $this->bildirim = null;
        $this->tanimlaForm->validate();

        $paket = $this->paketBul($this->tanimlaForm->paketId);
        if ($paket === null) {
            $this->redKaydet('addon_grant', self::RED_PAKET_YOK, $this->tanimlaForm->firmaId);
            $this->addError('tanimlaForm.paketId', 'Paket bulunamadı; sayfayı tazeleyip tekrar deneyin.');

            return;
        }

        $tenant = $this->firmaBul($this->tanimlaForm->firmaId);
        if ($tenant === null) {
            $this->redKaydet('addon_grant', self::RED_FIRMA_YOK);
            $this->addError('tanimlaForm.firmaId', 'Firma bulunamadı; listeyi tazeleyip tekrar deneyin.');

            return;
        }

        // Tutar kararı SUNUCUDA yeniden verilir: bedelsizde ekrandaki alan pasiftir ama istemci
        // yine de bir değer gönderebilir.
        if ($this->tanimlaForm->bedelsizMi()) {
            $tutar = 0;
        } elseif ($this->tanimlaForm->tutarBos()) {
            $tutar = null; // servis paketin liste fiyatını uygular
        } else {
            $tutar = $this->tutarDogrula($this->tanimlaForm->tutarKurus(), 'tanimlaForm.tutar', 'addon_grant', sifirSerbest: true);
            if ($tutar === null) {
                return;
            }
        }

        $this->gonderiliyor = true;

        try {
            (new EkPaketServisi)->tanimla(
                tenantId: $tenant->id,
                paketId: (string) $paket->id,
                collectionMethod: $this->tanimlaForm->tahsil,
                amountKurus: $tutar,
                grantedOn: Carbon::parse($this->tanimlaForm->tarih),
                note: trim($this->tanimlaForm->not) !== '' ? trim($this->tanimlaForm->not) : null,
                adminId: $this->adminId(),
                grantId: $this->tanimlamaAnahtari,
            );
        } catch (GecersizTutarException $e) {
            $this->gonderiliyor = false;
            $this->redKaydet('addon_grant', self::RED_SERVIS, $tenant->id);
            $this->bildirim = ['tur' => 'hata', 'mesaj' => $e->getMessage()];

            return;
        }

        $this->tanimlaModalAcik = false;
        $this->tanimlamaAnahtari = null;
        $this->gonderiliyor = false;
        $this->tanimlaForm->reset();
        $this->resetValidation();
        $this->dispatch('tost', mesaj: $paket->name.' → '.$tenant->name.' tanımlandı');
    }

    // --- Görünüm -------------------------------------------------------------------------

    public function render(): mixed
    {
        $this->panelOturumu();

        $depo = $this->plan();
        $servis = new EkPaketServisi('pgsql_panel');
        $paketler = $servis->paketler();

        /** @var Collection<string, string> $adlar */
        $adlar = Tenant::on('pgsql_panel')->pluck('name', 'id');

        $tanimlamalar = collect($servis->tanimlamalar()->all())->map(fn ($t) => [
            'id' => (string) $t->id,
            'tenant_id' => (string) $t->tenant_id,
            'firma' => (string) $adlar->get((string) $t->tenant_id, '?'),
            'tarih' => Bicim::tarihKisa($t->granted_on),
            'paket' => (string) $t->package_name,
            'tutar_kurus' => (int) $t->amount_kurus,
            'bedelsiz' => $t->collection_method === 'bedelsiz',
            'tahsil' => self::TAHSIL_ETIKET[$t->collection_method] ?? $t->collection_method,
            'not' => $t->note !== null && $t->note !== '' ? $t->note : '—',
        ])->all();

        return view('livewire.panel.paketler', [
            'planAdi' => $depo->plan()->name ?? 'Sipario',
            'aylikKurus' => $depo->aylikKurus(),
            'yillikKurus' => $depo->yillikKurus(),
            'denemeGun' => $depo->denemeGun(),
            'hakAy' => $depo->rotaKontoruAylik(),
            'kuryeLimiti' => $depo->kuryeLimiti(),
            'paketler' => $paketler,
            'satistaSayisi' => $paketler->where('active', true)->count(),
            'tanimlamalar' => $tanimlamalar,
            'turEtiket' => self::TUR_ETIKET,
            'satistakiler' => $this->tanimlaModalAcik ? $this->satistakiPaketler() : new EloquentCollection,
            'firmalar' => $this->tanimlaModalAcik ? $this->firmaListesi() : [],
            'seciliPaket' => $this->tanimlaModalAcik ? $this->paketBul($this->tanimlaForm->paketId) : null,
            'superadmin' => $this->superadminMi(),
        ]);
    }

    /**
     * Ortak tutar kapısı: çözülemeyen/aşırı/negatif değer alanın altına hata basar ve null döner.
     * `$sifirSerbest` — paket ücreti ve bedelsiz tanımlama 0 olabilir, plan ücreti olabilir ama
     * ödeme tutarı olamaz.
     *
     * Her ret `<eylem>_denied` + `gecersiz_tutar` olarak günlüğe düşer; GİRİLEN DEĞER yazılmaz.
     */
    private function tutarDogrula(?int $kurus, string $alan, string $eylem, bool $sifirSerbest = false): ?int
    {
        if ($kurus === null || $kurus < 0 || (! $sifirSerbest && $kurus <= 0)) {
            $this->redKaydet($eylem, self::RED_GECERSIZ_TUTAR);
            $this->addError($alan, $sifirSerbest
                ? 'Tutar negatif olmayan bir sayı olmalıdır.'
                : 'Tutar sıfırdan büyük bir sayı olmalıdır.');

            return null;
        }

        if ($kurus > Bicim::TAVAN_KURUS) {
            $this->redKaydet($eylem, self::RED_GECERSIZ_TUTAR);
            $this->addError($alan, 'Tutar çok büyük; lütfen kontrol edin.');

            return null;
        }

        return $kurus;
    }

    /** @return EloquentCollection<int, AddonPackage> */
    private function satistakiPaketler(): EloquentCollection
    {
        return (new EkPaketServisi('pgsql_panel'))->paketler(true);
    }

    private function paketBul(?string $id): ?AddonPackage
    {
        if ($id === null || ! Str::isUuid($id)) {
            return null;
        }

        return AddonPackage::on('pgsql_panel')->find($id);
    }

    private function firmaBul(?string $id): ?Tenant
    {
        if ($id === null || ! Str::isUuid($id)) {
            return null;
        }

        return Tenant::on('pgsql_panel')->find($id);
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

    private function plan(): PlanDeposu
    {
        return $this->planDeposu ??= new PlanDeposu('pgsql_panel');
    }
}
