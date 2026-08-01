<?php

namespace App\Panel;

use App\Support\Sync\SyncService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Müşteri CSV TOPLU AKTARIMI (5c-3 · D4) — yeni bayinin elindeki müşteri listesini ürüne taşımak
 * onboarding'in en pahalı adımıdır; tek tek girmek saatler alır.
 *
 * ÜÇ ADIM: şablon indir → dosya yükle (ÖNİZLEME) → onayla. Önizleme adımı pazarlıksızdır: 300
 * satırlık bir dosyayı görmeden uygulamak, geri alınamayacak bir toplu yazma demektir.
 *
 * ÖNİZLEME OTORİTE DEĞİLDİR: `uygula()` dosyayı YENİDEN çözümler ve dedup'ı YENİDEN koşar. Ekrandan
 * dönen önizleme dizisine güvenip yazmak, arada eklenen bir müşteriyi (ya da kurcalanmış bir istemci
 * durumunu) görmezden gelmek olurdu. Kullanıcının gördüğü liste bilgilendirmedir; kararı sunucu
 * yazma anında yeniden verir.
 *
 * DEDUP TELEFONUN SON 10 HANESİYLE yapılır — hem DOSYA İÇİNDE hem MEVCUT KAYITLARLA. Neden son 10
 * hane: aynı numara "0532…", "+90532…", "532…" biçimlerinde yazılır ve arayan tanıma da bu anahtarla
 * eşleşir (customer_phones.phone_last10). Veritabanında telefon TEKİLLİĞİ ZORLANMAZ (barkodla aynı
 * gerekçe: çevrimdışı iki cihazın aynı numarayı girmesi olayı reddedip veri kaybettirirdi) —
 * dolayısıyla çift kaydı önlemek bu servisin işidir, DB'nin değil.
 */
class PanelImportService extends PanelSyncYazici
{
    /** Tek dosyada işlenecek azami satır (bellek + tek seferde geri alınamaz yazma sınırı). */
    public const MAX_SATIR = 2000;

    /** Şablon sütunları — sıra ÖNEMLİDİR, dosya başlıksız da gelebilir. */
    public const SUTUNLAR = ['ad', 'telefon', 'adres', 'bolge', 'not'];

    /** Boş şablon (indirilip doldurulur). */
    public function sablon(): string
    {
        return Csv::olustur(self::SUTUNLAR, [
            ['Ayşe Yılmaz', '0532 111 22 33', 'Şirinyalı Mah. 1497. Sk. No: 9', 'Muratpaşa', 'Kapıcıya bırak'],
            ['Mehmet Demir', '0533 999 88 77', 'Kükürtlü Mah. 5. Cd. No: 12', 'Osmangazi', ''],
        ]);
    }

    /**
     * Dosyayı çözümler, her satırı doğrular ve ne olacağını söyler. HİÇBİR ŞEY YAZILMAZ.
     *
     * @return array{satirlar: list<array<string, mixed>>, ozet: array{eklenecek: int, atlanacak: int, hatali: int}}
     */
    public function onizleme(string $tenantId, string $icerik): array
    {
        $ham = Csv::ayikla($icerik);
        if ($ham === []) {
            throw new RuntimeException('Dosya boş görünüyor.');
        }

        // Başlık satırı varsa atlanır: ilk hücre şablon başlığıysa (büyük/küçük harf duyarsız).
        $ilkHucre = mb_strtolower($ham[0][0] ?? '');
        $baslikVar = in_array($ilkHucre, ['ad', 'ad *', 'isim', 'müşteri', 'musteri'], true);
        if ($baslikVar) {
            array_shift($ham);
        }

        if (count($ham) > self::MAX_SATIR) {
            throw new RuntimeException('Dosyada '.count($ham).' satır var; en fazla '.self::MAX_SATIR.' satır aktarılabilir.');
        }

        $mevcutTelefonlar = $this->mevcutTelefonlar($tenantId);
        $dosyadakiTelefonlar = [];

        $satirlar = [];
        foreach ($ham as $i => $sutunlar) {
            // Satır numarası KULLANICININ gördüğü numaradır: 1 tabanlı + varsa başlık satırı.
            $satirNo = $i + 1 + ($baslikVar ? 1 : 0);
            $satirlar[] = $this->satiriDegerlendir($satirNo, $sutunlar, $mevcutTelefonlar, $dosyadakiTelefonlar);
        }

        $say = fn (string $durum) => count(array_filter($satirlar, fn ($s) => $s['durum'] === $durum));

        return [
            'satirlar' => $satirlar,
            'ozet' => [
                'eklenecek' => $say('eklenecek'),
                'atlanacak' => $say('atlanacak'),
                'hatali' => $say('hatali'),
            ],
        ];
    }

    /**
     * Önizlemede "eklenecek" işaretli satırları GERÇEKTEN yazar. Dosya yeniden çözümlenir
     * (bkz. sınıf açıklaması) — bu yüzden imza önizleme dizisini değil DOSYA İÇERİĞİNİ alır.
     *
     * @return array{eklenen: int, atlanan: int, hatali: int, durum: string, mesaj: string|null, hatalar: list<array{satir: int, aciklama: string}>}
     */
    public function uygula(string $tenantId, string $icerik, ?string $adminId): array
    {
        $onizleme = $this->onizleme($tenantId, $icerik);
        $eklenecek = array_values(array_filter($onizleme['satirlar'], fn ($s) => $s['durum'] === 'eklenecek'));

        $durum = ['durum' => 'applied', 'mesaj' => null];
        $eklenen = 0;

        if ($eklenecek !== []) {
            try {
                $durum = $this->rlsIcinde($tenantId, function () use ($tenantId, $eklenecek) {
                    // Her müşteri en fazla 3 olay üretir (müşteri + telefon + adres); push'un olay
                    // tavanı 500'dür, bu yüzden 150'şerlik kümelerle gidilir.
                    $sonDurum = ['durum' => 'applied', 'mesaj' => null];

                    foreach (array_chunk($eklenecek, 150) as $kume) {
                        $olaylar = [];
                        foreach ($kume as $satir) {
                            $olaylar = array_merge($olaylar, $this->musteriOlaylari($satir));
                        }

                        if (count($olaylar) > SyncService::MAX_EVENTS) {
                            throw new RuntimeException('Küme olay tavanını aştı; parça boyutu küçültülmeli.');
                        }

                        $sonuc = $this->durumOzeti($this->push($tenantId, $olaylar));
                        if ($sonuc['durum'] !== 'applied') {
                            // Kilitli bayi / reddedilen parti: transaction geri alınır, kısmi yazma kalmaz.
                            throw new AktarimDurduruldu($sonuc['durum'], $sonuc['mesaj']);
                        }
                        $sonDurum = $sonuc;
                    }

                    return $sonDurum;
                });

                $eklenen = count($eklenecek);
            } catch (AktarimDurduruldu $e) {
                // Transaction geri sarıldı: hiçbir satır yazılmadı. Kullanıcıya bunu SÖYLE.
                return [
                    'eklenen' => 0,
                    'atlanan' => $onizleme['ozet']['atlanacak'],
                    'hatali' => $onizleme['ozet']['hatali'],
                    'durum' => $e->durum,
                    'mesaj' => $e->getMessage(),
                    'hatalar' => $this->hatalar($onizleme),
                ];
            }
        }

        if ($eklenen > 0) {
            // Denetim: TEK satır, adet ile. Müşteri başına kayıt günlüğü boğardı; eylem "içe aktarım".
            $this->audit($adminId, $tenantId, 'customer_import', 'n='.$eklenen);
        }

        return [
            'eklenen' => $eklenen,
            'atlanan' => $onizleme['ozet']['atlanacak'],
            'hatali' => $onizleme['ozet']['hatali'],
            'durum' => $durum['durum'],
            'mesaj' => $durum['mesaj'],
            'hatalar' => $this->hatalar($onizleme),
        ];
    }

    /**
     * Sonuç raporundaki SATIR NUMARALI hata listesi — "12 satır hatalı" tek başına işe yaramaz,
     * kullanıcı dosyayı düzeltmek için hangi satır olduğunu bilmelidir.
     *
     * @param  array{satirlar: list<array<string, mixed>>, ozet: array<string, int>}  $onizleme
     * @return list<array{satir: int, aciklama: string}>
     */
    private function hatalar(array $onizleme): array
    {
        return array_values(array_map(
            fn ($s) => ['satir' => (int) $s['satir'], 'aciklama' => (string) $s['aciklama']],
            array_filter($onizleme['satirlar'], fn ($s) => $s['durum'] === 'hatali'),
        ));
    }

    // ------------------------------------------------------------------------------------

    /**
     * @param  array<string, string>  $mevcutTelefonlar  son10 → kayıtlı müşterinin adı
     * @param  array<string, int>  $dosyadakiTelefonlar  son10 → ilk görüldüğü satır
     * @param  list<string>  $sutunlar
     * @return array<string, mixed>
     */
    private function satiriDegerlendir(int $satirNo, array $sutunlar, array $mevcutTelefonlar, array &$dosyadakiTelefonlar): array
    {
        $ad = trim($sutunlar[0] ?? '');
        $telefonHam = trim($sutunlar[1] ?? '');
        $telefon = Telefon::e164($telefonHam);
        $son10 = Telefon::son10($telefon);

        $temel = [
            'satir' => $satirNo,
            'ad' => $ad,
            'telefon' => $telefon ?? $telefonHam,
            'adres' => trim($sutunlar[2] ?? ''),
            'bolge' => trim($sutunlar[3] ?? ''),
            'not' => trim($sutunlar[4] ?? ''),
        ];

        $hata = $this->satirHatasi($ad, $telefonHam, $telefon);
        if ($hata !== null) {
            return $temel + ['durum' => 'hatali', 'aciklama' => $hata];
        }

        if ($son10 !== null && isset($dosyadakiTelefonlar[$son10])) {
            return $temel + ['durum' => 'atlanacak',
                'aciklama' => 'Bu numara dosyada '.$dosyadakiTelefonlar[$son10].'. satırda da var.'];
        }

        if ($son10 !== null && isset($mevcutTelefonlar[$son10])) {
            return $temel + ['durum' => 'atlanacak',
                'aciklama' => 'Bu numara bayide kayıtlı: '.$mevcutTelefonlar[$son10]];
        }

        if ($son10 !== null) {
            $dosyadakiTelefonlar[$son10] = $satirNo;
        }

        return $temel + [
            'durum' => 'eklenecek',
            // Telefonsuz satır eklenir ama uyarılır: dedup anahtarı yoktur, dosya ikinci kez
            // aktarılırsa aynı müşteri tekrar doğar ve bunu kimse fark etmez.
            'aciklama' => $son10 === null ? 'Telefon yok — tekrar aktarımda çift kayıt riski.' : '',
        ];
    }

    private function satirHatasi(string $ad, string $telefonHam, ?string $telefon): ?string
    {
        if ($ad === '') {
            return 'Ad boş.';
        }
        if (mb_strlen($ad) < 2) {
            return 'Ad çok kısa (en az 2 karakter).';
        }
        if (mb_strlen($ad) > 120) {
            return 'Ad çok uzun (en fazla 120 karakter).';
        }
        if ($telefonHam !== '' && $telefon === null) {
            return 'Telefon okunamadı: "'.$telefonHam.'"';
        }

        return null;
    }

    /**
     * İçe aktarılan satırın olayları. Hepsi YENİ kayıttır (dedup'tan geçti) → mevcut satır okuma
     * ve LWW ileri alma gerekmez, damga `now()`tur.
     *
     * @param  array<string, mixed>  $satir
     * @return list<array<string, mixed>>
     */
    private function musteriOlaylari(array $satir): array
    {
        $musteriId = (string) Str::uuid7();

        $olaylar = [$this->olay('customer', 'upsert', [
            'id' => $musteriId,
            'name' => $satir['ad'],
            'note' => $this->bosNull($satir['not']),
            'blacklisted_at' => null,
        ])];

        $telefon = Telefon::e164($satir['telefon']);
        if ($telefon !== null) {
            $olaylar[] = $this->olay('customer_phone', 'upsert', [
                'id' => (string) Str::uuid7(),
                'customer_id' => $musteriId,
                'phone_e164' => $telefon,
                'phone_last10' => Telefon::son10($telefon),
                'is_primary' => true,
            ]);
        }

        if ($this->bosNull($satir['adres']) !== null) {
            $olaylar[] = $this->olay('customer_address', 'upsert', [
                'id' => (string) Str::uuid7(),
                'customer_id' => $musteriId,
                'address_text' => $satir['adres'],
                'region' => $this->bosNull($satir['bolge']),
                'is_primary' => true,
            ]);
        }

        return $olaylar;
    }

    /**
     * Bayide kayıtlı telefonlar: son10 → müşteri adı (önizlemede "kimle çakıştı" yazabilmek için).
     * Panel bağlantısıyla OKUNUR ve tenant_id AÇIKÇA filtrelenir (BYPASSRLS, kırmızı çizgi #1).
     *
     * @return array<string, string>
     */
    private function mevcutTelefonlar(string $tenantId): array
    {
        $satirlar = DB::connection($this->panelConnection)->table('customer_phones as p')
            ->join('customers as c', function ($j) {
                $j->on('c.id', '=', 'p.customer_id')->on('c.tenant_id', '=', 'p.tenant_id');
            })
            ->where('p.tenant_id', $tenantId)
            ->whereNull('p.deleted_at')
            ->whereNull('c.deleted_at')
            ->select('p.phone_last10', 'c.name')
            ->get();

        $harita = [];
        foreach ($satirlar as $satir) {
            $harita[(string) $satir->phone_last10] = (string) $satir->name;
        }

        return $harita;
    }
}
