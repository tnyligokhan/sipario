<?php

namespace App\Console\Commands;

use App\Abonelik\PlanDeposu;
use App\Enums\TenantStatus;
use App\Eposta\BayiPostacisi;
use App\Livewire\Site\Forms\ParaBicimi;
use App\Mail\DenemeBitiyor;
use App\Mail\SureDoldu;
use App\Mail\YenilemeHatirlatmasi;
use App\Models\Tenant;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;

/**
 * ABONELİK HATIRLATMALARI — günde bir kez koşar, süresi yaklaşan ve dolmuş bayilere yazar.
 *
 * NEDEN VAR: BRIEF'in ölçtüğü en pahalı şey erken terktir ve bu depoda süre dolumu bugüne kadar
 * TAMAMEN SESSİZDİ. Bayi bir sabah uygulamayı açıyor ve kilitli buluyor — ürünü bırakmak için
 * fazlasıyla yeterli bir sürpriz. Üç hatırlatma o sürprizi bir plana çevirir.
 *
 * ALTYAPI ZATEN VARDI: `docker-compose.prod.yml:332` bir `schedule:work` konteyneri koşuyor ve
 * bugüne kadar "No scheduled commands" diyordu. Yani bu komut yeni bir servis GEREKTİRMEZ.
 *
 * ── TEK ÇIPA `valid_until` ────────────────────────────────────────────────────────────────
 * Kalan gün `trial_ends_at`ten değil `valid_until`den hesaplanır. Sebep kodda yazılı
 * (`Provisioning`: "valid_until = trial_ends_at (FAZ 5a): tek enforcement çıpası; trial_ends_at
 * yalnız 'deneme miydi' bilgisi"). Kilidi uygulayan kolon hangisiyse, hatırlatma da onu saymak
 * zorundadır; yoksa posta bir tarihi, kilit başka bir tarihi söyler.
 *
 * ── AYNI POSTA İKİ KEZ GİTMEZ ─────────────────────────────────────────────────────────────
 * Her gönderim, önbellekte `bayi + tür + eşik + hedef tarih` anahtarıyla işaretlenir
 * (`Cache::add` atomiktir: ikinci çağrı false döner). Anahtarda HEDEF TARİH bulunması şart —
 * yalnız "bugün" ile anahtarlansaydı, abonelik yenilendiğinde yeni dönemin hatırlatması eski
 * işaretle çakışmazdı ama zamanlayıcı iki kez koşarsa (konteyner yeniden başlarsa) aynı gün
 * ikinci posta giderdi. Hedef tarih, işareti aboneliğin DÖNEMİNE bağlar.
 *
 * ── NEDEN KUYRUK DEĞİL DE DOĞRUDAN ────────────────────────────────────────────────────────
 * Postaların kendisi zaten `ShouldQueue`; bu komut yalnız kimin hak ettiğini bulur ve kuyruğa
 * yazar. Bin bayide bile iş, birkaç saniyelik bir tarama artı kuyruk yazımıdır.
 */
class AbonelikHatirlatmalari extends Command
{
    use ParaBicimi;

    protected $signature = 'abonelik:hatirlat
                            {--kuru : Hiçbir posta göndermez, yalnız kimlere gideceğini yazar}';

    protected $description = 'Deneme/abonelik süresi yaklaşan ve dolmuş bayilere hatırlatma postası gönderir';

    /** Denemede kaç gün kala hatırlatılır. */
    private const DENEME_ESIKLERI = [7, 3, 1];

    /** Ödeyen bayide kaç gün kala hatırlatılır — daha erken, çünkü havale/EFT elle yapılır. */
    private const YENILEME_ESIKLERI = [15, 3];

    public function handle(): int
    {
        $kuru = (bool) $this->option('kuru');
        $bugun = Carbon::today();
        $sayac = ['deneme' => 0, 'yenileme' => 0, 'doldu' => 0];

        // Yıllık fiyat postalarda gösterilir. Plan satırı okunamazsa boş geçilir — postanın
        // geri kalanı fiyatsız da anlamlıdır; uydurma bir rakam basmaktansa hiç basmamak yeğdir.
        $yillik = $this->yillikTutar();

        /*
         * `pgsql_owner`: bu komut konsoldan koşar, RLS kiracı değişkeni KURULU DEĞİLDİR. Normal
         * bağlantı sessizce boş küme döndürür — komut "0 bayi" der ve kimse bir şey fark etmez.
         */
        Tenant::on('pgsql_owner')
            ->whereNotNull('valid_until')
            ->whereIn('status', [TenantStatus::Trial->value, TenantStatus::Active->value, TenantStatus::Locked->value])
            ->orderBy('id')
            ->chunkById(200, function ($bayiler) use ($bugun, $kuru, $yillik, &$sayac): void {
                /** @var Tenant $bayi */
                foreach ($bayiler as $bayi) {
                    $bitis = $bayi->valid_until;
                    if ($bitis === null) {
                        continue;
                    }

                    // Takvim GÜNÜ farkı — saat farkı değil. Bayi "3 gün kaldı" cümlesini
                    // takvimden doğrular; 2.6 günü "2 gün" diye yuvarlamak yalan gibi okunur.
                    $kalan = (int) $bugun->diffInDays($bitis->copy()->startOfDay(), false);

                    $tur = $bayi->status === TenantStatus::Trial ? 'deneme' : 'yenileme';

                    if ($kalan < 0) {
                        // Süre DOLDU. Yalnız dolduğu GÜN yazılır; her gün "süreniz doldu" demek
                        // hatırlatma değil taciz olurdu ve postalar spam'e düşer.
                        if ($kalan === -1 && $this->isaretle($bayi, 'doldu', 0, $bitis) && ! $kuru) {
                            $this->sureDoldu($bayi, $bitis);
                        }
                        if ($kalan === -1) {
                            $sayac['doldu']++;
                            $this->satir($bayi, 'süre doldu', $bitis);
                        }

                        continue;
                    }

                    $esikler = $tur === 'deneme' ? self::DENEME_ESIKLERI : self::YENILEME_ESIKLERI;

                    if (! in_array($kalan, $esikler, true)) {
                        continue;
                    }

                    if (! $this->isaretle($bayi, $tur, $kalan, $bitis)) {
                        continue;
                    }

                    $sayac[$tur]++;
                    $this->satir($bayi, $tur.' · '.$kalan.' gün kaldı', $bitis);

                    if ($kuru) {
                        continue;
                    }

                    $this->hatirlat($bayi, $tur, $kalan, $bitis, $yillik);
                }
            });

        $this->info(sprintf(
            '%s deneme, %s yenileme, %s süre dolumu hatırlatması%s.',
            $sayac['deneme'], $sayac['yenileme'], $sayac['doldu'], $kuru ? ' (KURU KOŞU — posta gitmedi)' : '',
        ));

        return self::SUCCESS;
    }

    private function hatirlat(Tenant $bayi, string $tur, int $kalan, Carbon $bitis, string $yillik): void
    {
        BayiPostacisi::gonder($bayi->id, function (Tenant $b, $patron) use ($tur, $kalan, $bitis, $yillik) {
            $ortak = [
                'isletme' => (string) $b->name,
                'yetkili' => (string) $patron->name,
                'kalanGun' => $kalan,
                'bitisTarihi' => $bitis->translatedFormat('j F Y'),
                'abonelikUrl' => route('subscription.subscribe'),
                'yillikTutar' => $yillik,
            ];

            return $tur === 'deneme' ? new DenemeBitiyor(...$ortak) : new YenilemeHatirlatmasi(...$ortak);
        });
    }

    private function sureDoldu(Tenant $bayi, Carbon $bitis): void
    {
        BayiPostacisi::gonder($bayi->id, fn (Tenant $b, $patron): SureDoldu => new SureDoldu(
            isletme: (string) $b->name,
            yetkili: (string) $patron->name,
            bitisTarihi: $bitis->translatedFormat('j F Y'),
            abonelikUrl: route('subscription.subscribe'),
            // "Deneme miydi" bilgisinin TEK kaynağı `trial_ends_at`tir (`valid_until` kilidi
            // uygular, türü söylemez). Denemesi hiç ödemeye dönmemiş bayide ikisi eşittir.
            denemeydi: $bayi->trial_ends_at !== null
                && $bayi->trial_ends_at->isSameDay($bitis),
        ));
    }

    /**
     * Bu hatırlatma bu dönem için daha önce gönderildi mi? Gönderilmediyse işaretler ve true döner.
     * `Cache::add` atomiktir — iki eşzamanlı koşudan yalnız biri true alır.
     */
    private function isaretle(Tenant $bayi, string $tur, int $esik, Carbon $bitis): bool
    {
        $anahtar = sprintf('abonelik-hatirlatma:%s:%s:%d:%s', $bayi->id, $tur, $esik, $bitis->toDateString());

        // 60 gün: en uzun eşik (15) ile en kısa dönem (1 ay) arasındaki payı rahatça kapsar,
        // ama işaretler sonsuza kadar birikmez.
        return Cache::add($anahtar, true, now()->addDays(60));
    }

    private function yillikTutar(): string
    {
        $kurus = (new PlanDeposu('pgsql_owner'))->yillikKurus();

        return $kurus > 0 ? $this->tl($kurus) : '';
    }

    private function satir(Tenant $bayi, string $ne, Carbon $bitis): void
    {
        $this->line(sprintf('  %-22s %-26s %s', $bayi->slug, $ne, $bitis->toDateString()));
    }
}
