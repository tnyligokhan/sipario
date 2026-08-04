<?php

namespace App\Livewire\Panel;

use App\Abonelik\GecersizTutarException;
use App\Abonelik\OdemeBildirimServisi;
use App\Enums\BillingPeriod;
use App\Livewire\Panel\Concerns\Bicim;
use App\Livewire\Panel\Concerns\ParaEkrani;
use App\Models\PaymentNotification;
use App\Models\Tenant;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Locked;
use Livewire\Attributes\Title;
use Livewire\Component;

/**
 * HAVALE BİLDİRİMLERİ — tasarımda YOKTUR, sunucu tarafında vardır ve olmadan sistem eksiktir.
 *
 * Bayi siteden "havale gönderdim" der; beyan `payment_notifications`ta BEKLER ve aboneliği UZATMAZ
 * (uzatsaydı "gönderdim" yazan herkes bedava abone olurdu). Bu ekran o kuyruğu yönetir: biz banka
 * ekstresinde parayı görünce EŞLEŞTİRİRİZ, gerçek ödeme kaydı o an doğar. Kuyruk olmadan bayi para
 * gönderir ve kimse görmez.
 *
 * EN ESKİ ÖNCE (servisin sıralaması): beklemede kalan bildirim en acil olandır.
 *
 * GERÇEK TUTAR ALANI: ekstredeki tutar beyandan farklı olabilir (eksik/fazla havale). Kayıt beyanı
 * değil PARAYI yansıtmalıdır, bu yüzden eşleştirme modalında tutar düzenlenebilir ve beyanla
 * ön doldurulur.
 *
 * ÇİFT TIKLAMA: `OdemeBildirimServisi::eslestir()` kararlı `notify:<id>` referansı kullanır ve
 * kapanmış bildirimi sessizce geçer — idempotens SERVİSTE. Bileşendeki `$gonderiliyor` bayrağı ve
 * `wire:loading.attr` yalnız kullanıcı deneyimi katmanıdır.
 */
#[Layout('components.layouts.panel')]
#[Title('Havale Bildirimleri')]
class Bildirimler extends Component
{
    use ParaEkrani;

    private const YONTEM_ETIKET = ['iban' => 'IBAN', 'elden' => 'Elden'];

    /**
     * Üzerinde çalışılan bildirim. `#[Locked]`: bu alan hangi bayinin aboneliğinin uzayacağını
     * belirler, yani bir SINIR taşır ve istemcinin serbestçe yazabildiği bir değere bağlanamaz —
     * `eslestirAc`/`reddetAc` eylemleri onu doğrulayarak yazar.
     */
    #[Locked]
    public ?string $acikId = null;

    /** 'eslestir' | 'reddet' | null */
    #[Locked]
    public ?string $kip = null;

    /**
     * Ekstredeki GERÇEK tutar (lira metni); beyanla ön dolar.
     *
     * Modal iki KİPLİ olduğu için aşağıdaki alanların doğrulaması `#[Validate]` özniteliğiyle
     * DEĞİL, eylemin içinde açıkça yapılır: "eşleştir" tutar/dönem ister, "reddet" gerekçe ister.
     * Öznitelikle yazılsaydı reddetme kipinde boş duran tutar alanı da doğrulanır ve kullanıcı
     * ilgisiz bir hata görürdü.
     */
    public string $tutar = '';

    public string $kapsam = '';

    public string $donem = 'monthly';

    public string $gerekce = '';

    public bool $gonderiliyor = false;

    /** @var array{tur: string, mesaj: string}|null */
    public ?array $bildirim = null;

    public function mount(): void
    {
        $this->panelOturumu();
    }

    // --- Eşleştir ------------------------------------------------------------------------

    public function eslestirAc(string $id): void
    {
        $this->paraYetkisi('payment_notification_match');

        $kayit = $this->bekleyenBul($id, 'payment_notification_match');
        $tenant = Tenant::on('pgsql_panel')->find($kayit->tenant_id);

        $this->acikId = (string) $kayit->id;
        $this->kip = 'eslestir';
        $this->tutar = Bicim::lira($kayit->amount_kurus);
        $this->kapsam = Carbon::parse($kayit->declared_on)->format('Y-m');
        $this->donem = ($tenant->billing_period ?? BillingPeriod::Monthly)->value;
        $this->gerekce = '';
        $this->bildirim = null;
        $this->gonderiliyor = false;
        $this->resetValidation();
    }

    public function eslestir(): void
    {
        $this->paraYetkisi('payment_notification_match');

        if ($this->gonderiliyor || $this->kip !== 'eslestir' || $this->acikId === null) {
            return;
        }

        $this->bildirim = null;
        $this->validate([
            'tutar' => ['required', 'string', 'max:24'],
            'kapsam' => ['required', 'date_format:Y-m'],
            'donem' => ['required', 'in:monthly,yearly'],
        ], [
            'tutar.required' => 'Tutar zorunludur.',
            'kapsam.required' => 'Kapsadığı dönemi seçin.',
            'kapsam.date_format' => 'Kapsadığı dönemi seçin.',
            'donem.in' => 'Abonelik dönemi aylık veya yıllık olmalıdır.',
        ]);

        $kurus = Bicim::kurus($this->tutar);
        if ($kurus === null || $kurus <= 0 || $kurus > Bicim::TAVAN_KURUS) {
            // Girilen TUTAR günlüğe yazılmaz — yalnız kategorik sebep.
            $this->redKaydet('payment_notification_match', self::RED_GECERSIZ_TUTAR);
            $this->addError('tutar', $kurus !== null && $kurus > Bicim::TAVAN_KURUS
                ? 'Tutar çok büyük; lütfen kontrol edin.'
                : 'Tutar sıfırdan büyük bir sayı olmalıdır.');

            return;
        }

        $kayit = $this->bekleyenBul($this->acikId, 'payment_notification_match');
        $this->gonderiliyor = true;

        try {
            (new OdemeBildirimServisi)->eslestir(
                bildirimId: (string) $kayit->id,
                coversPeriod: Bicim::ayAdi($this->kapsam),
                period: BillingPeriod::tryFrom($this->donem) ?? BillingPeriod::Monthly,
                amountKurus: $kurus,
                adminId: $this->adminId(),
            );
        } catch (GecersizTutarException $e) {
            $this->gonderiliyor = false;
            $this->redKaydet('payment_notification_match', self::RED_SERVIS, $kayit->tenant_id);
            $this->bildirim = ['tur' => 'hata', 'mesaj' => $e->getMessage()];

            return;
        }

        $this->kapat();
        $this->dispatch('tost', mesaj: 'Bildirim eşleştirildi · ödeme kaydedildi');
    }

    // --- Reddet --------------------------------------------------------------------------

    public function reddetAc(string $id): void
    {
        $this->paraYetkisi('payment_notification_reject');

        $kayit = $this->bekleyenBul($id, 'payment_notification_reject');

        $this->acikId = (string) $kayit->id;
        $this->kip = 'reddet';
        $this->gerekce = '';
        $this->bildirim = null;
        $this->gonderiliyor = false;
        $this->resetValidation();
    }

    public function reddet(): void
    {
        $this->paraYetkisi('payment_notification_reject');

        if ($this->gonderiliyor || $this->kip !== 'reddet' || $this->acikId === null) {
            return;
        }

        $this->bildirim = null;
        $this->validate(['gerekce' => ['required', 'string', 'min:3', 'max:500']], [
            'gerekce.required' => 'Reddetme gerekçesi zorunludur.',
            'gerekce.min' => 'Gerekçe en az 3 karakter olmalıdır.',
        ]);

        $kayit = $this->bekleyenBul($this->acikId, 'payment_notification_reject');
        $this->gonderiliyor = true;

        (new OdemeBildirimServisi)->reddet(
            bildirimId: (string) $kayit->id,
            adminId: $this->adminId(),
            note: trim($this->gerekce),
        );

        $this->kapat();
        $this->dispatch('tost', mesaj: 'Bildirim reddedildi');
    }

    public function kapat(): void
    {
        $this->acikId = null;
        $this->kip = null;
        $this->tutar = '';
        $this->kapsam = '';
        $this->donem = 'monthly';
        $this->gerekce = '';
        $this->gonderiliyor = false;
        $this->bildirim = null;
        $this->resetValidation();
    }

    // --- Görünüm -------------------------------------------------------------------------

    public function render(): mixed
    {
        $this->panelOturumu();

        $bekleyenler = (new OdemeBildirimServisi('pgsql_panel'))->bekleyenler();

        /** @var Collection<string, string> $adlar */
        $adlar = Tenant::on('pgsql_panel')->pluck('name', 'id');

        $satirlar = collect($bekleyenler->all())->map(fn (PaymentNotification $b) => [
            'id' => (string) $b->id,
            'tenant_id' => (string) $b->tenant_id,
            'firma' => (string) $adlar->get((string) $b->tenant_id, '?'),
            'tutar_kurus' => (int) $b->amount_kurus,
            'yontem' => self::YONTEM_ETIKET[$b->method] ?? $b->method,
            'referans' => (string) $b->reference_code,
            'tarih' => Bicim::tarihKisa($b->declared_on),
            'not' => $b->note !== null && $b->note !== '' ? $b->note : '—',
        ])->all();

        $acik = null;
        foreach ($satirlar as $satir) {
            if ($satir['id'] === $this->acikId) {
                $acik = $satir;
                break;
            }
        }

        return view('livewire.panel.bildirimler', [
            'satirlar' => $satirlar,
            'acik' => $acik,
            'donemler' => Bicim::donemSecenekleri(),
            'superadmin' => $this->superadminMi(),
        ]);
    }

    /**
     * Bekleyen bildirimi getirir. Bozuk/olmayan kimlik → 404 (500 DEĞİL); kapanmış bir bildirim de
     * bu kuyruğun konusu değildir ve 404 döner — durum makinesi tek yönlüdür.
     *
     * KAPANMIŞ BİLDİRİMİ İŞLEME DENEMESİ DENETİME DÜŞER (`<eylem>_denied` · `kapali_bildirim`):
     * iki operatörün aynı beyanı aynı anda kapatması ya da eski bir sekmeden gelen tıklama
     * masumdur, ama kapanmış bir para kaydını yeniden açmaya çalışan bir istek masum değildir —
     * ikisini ayırmanın tek yolu denemenin iz bırakmasıdır.
     */
    private function bekleyenBul(string $id, string $eylem): PaymentNotification
    {
        $kayit = PaymentNotification::on('pgsql_panel')
            ->where('status', PaymentNotification::STATUS_PENDING)
            ->find($this->uuidZorunlu($id, $eylem));

        if ($kayit === null) {
            $this->redKaydet($eylem, self::RED_KAPALI_BILDIRIM);
            abort(404);
        }

        return $kayit;
    }
}
