<?php

namespace App\Livewire\Panel;

use App\Abonelik\GecersizTutarException;
use App\Abonelik\GelirGiderRaporu;
use App\Abonelik\MasrafServisi;
use App\Livewire\Panel\Concerns\Bicim;
use App\Livewire\Panel\Concerns\ParaEkrani;
use App\Livewire\Panel\Forms\MasrafForm;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Locked;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;

/**
 * GELİR-GİDER (tasarım `10-MasrafEkleModal.jsx` · GelirGider + MasrafEkleModal).
 *
 * Sol: aylık özet tablosu (satıra tıklayınca o ay seçilir). Sağ: seçili ayın masraf kalemleri.
 * Üstte aylık net trendi (kit `x-panel.grafik-cizgi`, negatif destekli).
 *
 * AY SINIRI BURADA HESAPLANMAZ. Gelirin ayı `GelirGiderRaporu`da sabit +03:00 ile,
 * giderin ayı `expenses.spent_on` (DATE) üzerinden belirlenir; bu ekran yalnız gelen
 * 'YYYY-MM' anahtarlarını ETİKETE çevirir. İkinci bir gün/ay sınırı kopyası, bu depoda daha önce
 * iki ekranın farklı sayı göstermesine yol açtı.
 *
 * MASRAFTA DÜZENLEME/SİLME YOK: `expenses` üzerinde panel rolüne UPDATE/DELETE verilmedi (005004)
 * ve tasarımda da böyle bir akış yok. Yalnız "Masraf Ekle". Çift gönderim kalkanının üçüncü katı
 * (`$masrafAnahtari`) tam da bu yüzden burada daha çok işe yarar: yanlışlıkla iki kez yazılan bir
 * kalem ekrandan SİLİNEMEZ.
 */
#[Layout('components.layouts.panel')]
#[Title('Gelir-Gider')]
class GelirGider extends Component
{
    use ParaEkrani;

    /** Seçili ay 'YYYY-MM'; boşsa listenin ilk (en yeni) ayı seçilir. */
    #[Url(as: 'ay')]
    public string $seciliAy = '';

    public bool $modalAcik = false;

    public MasrafForm $form;

    /**
     * ÇİFT TIKLAMA KALKANININ ÜÇÜNCÜ KATI — masrafın kararlı kimliği.
     *
     * `MasrafServisi::ekle()` bunu `expenses.id` olarak kullanır; ikinci çağrı mevcut satırı
     * döndürür ve İKİNCİ DENETİM KAYDI DA yazılmaz (tekrar eden çağrı yeni bir eylem değildir).
     * Anahtar null geçilirse servis her çağrıda yenisini üretir ve idempotens kaybolur.
     *
     * Burada telafi ayrıca zordur: `expenses` üzerinde panel rolüne UPDATE/DELETE verilmedi
     * (005004), yani yanlışlıkla iki kez yazılan bir kalem ekrandan silinemez.
     *
     * `#[Locked]`: istemci değiştirebilseydi kalkanı kendisi kaldırabilirdi.
     */
    #[Locked]
    public ?string $masrafAnahtari = null;

    public bool $gonderiliyor = false;

    /** @var array{tur: string, mesaj: string}|null */
    public ?array $bildirim = null;

    public function mount(): void
    {
        $this->panelOturumu();
    }

    public function ayaGec(string $ay): void
    {
        $this->seciliAy = preg_match('/^\d{4}-\d{2}$/', $ay) === 1 ? $ay : '';
    }

    // --- Masraf Ekle modalı --------------------------------------------------------------

    public function masrafModalAc(): void
    {
        $this->paraYetkisi('expense_create');

        $this->form->reset();
        // EKRANIN günü (+03:00), sunucununki (UTC) değil — bkz. Bicim::bugun().
        $this->form->tarih = Bicim::bugun()->toDateString();
        $this->bildirim = null;
        $this->gonderiliyor = false;

        // Kararlı anahtar MODAL AÇILIRKEN doğar — Ödemeler ve Paketler'deki desenin aynısı.
        $this->masrafAnahtari = (string) Str::uuid7();
        $this->modalAcik = true;
    }

    public function masrafModalKapat(): void
    {
        $this->modalAcik = false;
        $this->masrafAnahtari = null;
        $this->gonderiliyor = false;
        $this->bildirim = null;
        $this->form->reset();
        $this->resetValidation();
    }

    public function masrafKaydet(): void
    {
        $this->paraYetkisi('expense_create');

        if ($this->gonderiliyor) {
            return;
        }

        $this->bildirim = null;
        $this->form->validate();

        $kurus = $this->form->tutarKurus();
        if ($kurus === null || $kurus <= 0 || $kurus > Bicim::TAVAN_KURUS) {
            // Reddedilen deneme denetime düşer; SEBEP kategoriktir, girilen TUTAR yazılmaz.
            $this->redKaydet('expense_create', self::RED_GECERSIZ_TUTAR);
            $this->addError('form.tutar', $kurus !== null && $kurus > Bicim::TAVAN_KURUS
                ? 'Tutar çok büyük; lütfen kontrol edin.'
                : 'Tutar sıfırdan büyük bir sayı olmalıdır.');

            return;
        }

        $this->gonderiliyor = true;
        $tarih = Carbon::parse($this->form->tarih);

        try {
            (new MasrafServisi)->ekle(
                category: $this->form->kategori,
                amountKurus: $kurus,
                spentOn: $tarih,
                note: trim($this->form->not) !== '' ? trim($this->form->not) : null,
                adminId: $this->adminId(),
                expenseId: $this->masrafAnahtari,
            );
        } catch (GecersizTutarException $e) {
            $this->gonderiliyor = false;
            // Katalog dışı kategori de buradan çıkar; günlüğe SEBEP KODU yazılır, girdi değil.
            $this->redKaydet('expense_create', self::RED_SERVIS);
            $this->bildirim = ['tur' => 'hata', 'mesaj' => $e->getMessage()];

            return;
        }

        // Kaydedilen masrafın ayına geç: kullanıcı girdiği kalemi ANINDA görsün, seçili ay
        // başka bir aya bakıyorsa "kaydettim ama listede yok" yanılgısı doğmasın.
        $this->seciliAy = $tarih->format('Y-m');

        $this->modalAcik = false;
        $this->masrafAnahtari = null;
        $this->gonderiliyor = false;
        $this->form->reset();
        $this->resetValidation();
        $this->dispatch('tost', mesaj: 'Masraf kaydedildi');
    }

    // --- Görünüm -------------------------------------------------------------------------

    public function render(): mixed
    {
        $this->panelOturumu();

        $rapor = new GelirGiderRaporu('pgsql_panel');
        $ozet = $rapor->aylikOzet();

        $secili = $this->gecerliSeciliAy($ozet);

        $kalemler = $secili === '' ? collect() : $rapor->ayKalemleri($secili);

        return view('livewire.panel.gelir-gider', [
            'ozet' => $ozet,
            'seciliAy' => $secili,
            'seciliAyAdi' => Bicim::ayAdi($secili === '' ? Bicim::bugun()->format('Y-m') : $secili),
            'kalemler' => $kalemler,
            'kalemToplami' => (int) $kalemler->sum('amount_kurus'),
            'trend' => $this->trend($ozet),
            'trendOzeti' => $this->trendOzeti($ozet),
            'kategoriler' => MasrafServisi::KATEGORILER,
            'superadmin' => $this->superadminMi(),
        ]);
    }

    /**
     * Seçili ay: URL'den geçerli bir 'YYYY-MM' geldiyse o, yoksa listenin ilk (en yeni) ayı.
     * Hiç kayıt yoksa '' — sağdaki kart boş durumla açılır.
     *
     * @param  list<array{ay: string, gelir_kurus: int, gider_kurus: int, net_kurus: int}>  $ozet
     */
    private function gecerliSeciliAy(array $ozet): string
    {
        if (preg_match('/^\d{4}-\d{2}$/', $this->seciliAy) === 1) {
            return $this->seciliAy;
        }

        return $ozet === [] ? '' : $ozet[0]['ay'];
    }

    /**
     * Aylık net trendi — ESKİDEN YENİYE (aylikOzet yeniden eskiye döner, çizgi soldan sağa akar).
     * Değerler LİRA: grafik ipuçlarında kuruş göstermek okunmaz bir sayı üretirdi.
     *
     * @param  list<array{ay: string, gelir_kurus: int, gider_kurus: int, net_kurus: int}>  $ozet
     * @return list<array{etiket: string, deger: int}>
     */
    private function trend(array $ozet): array
    {
        $son = array_reverse(array_slice($ozet, 0, 12));

        return array_map(fn (array $s) => [
            'etiket' => Bicim::ayKisa($s['ay']),
            'deger' => (int) round($s['net_kurus'] / 100),
        ], $son);
    }

    /** @param  list<array{ay: string, gelir_kurus: int, gider_kurus: int, net_kurus: int}>  $ozet */
    private function trendOzeti(array $ozet): ?string
    {
        $son = array_slice($ozet, 0, 12);
        if ($son === []) {
            return null;
        }

        $enDusuk = $son[0];
        foreach ($son as $satir) {
            if ($satir['net_kurus'] < $enDusuk['net_kurus']) {
                $enDusuk = $satir;
            }
        }

        return 'En düşük: '.Bicim::tlNet($enDusuk['net_kurus']).' · '.Bicim::ayAdi($enDusuk['ay']);
    }
}
