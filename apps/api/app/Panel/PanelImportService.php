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
 *
 * SATIRDA MÜŞTERİ KODU VARSA DEDUP ANAHTARI KODDUR, telefon değil (2026-09-11 — gerekçe ve ölçüm
 * `AktarimDurumu`da). Kısaca: aynı numara birden çok gerçek müşteride geçebilir (aile, ev+işyeri)
 * ve telefonla tekilleştirmek onları çöpe atar; eski sistemin kodu daha güvenilir bir kimliktir.
 *
 * ÜÇ YENİ SÜTUN (2026-09-11): `kod` bayinin eski müşteri numarasını KORUR, `favoriler` ürün
 * ADLARINI taşır ve bayide olmayan ürün AKTARIM SIRASINDA AÇILIR (`AktarimUrunleri`); `telefon`
 * ile `adres` artık ':::' ayracıyla birden çok değer alabilir (`customer_phones` ve
 * `customer_addresses` zaten 1NF'dir — tek numaraya indirgemek veri atmak olurdu).
 *
 * PARTİ BAŞINA TRANSACTION — "hepsi ya da hiçbiri" BİLEREK BIRAKILDI (2026-09-11, ÖLÇÜLDÜ).
 *
 * Eskiden dosyanın tamamı TEK transaction'daydı ve bu, dosya küçükken doğru bir garantiydi.
 * 9.057 satırlık gerçek dosyada ölçüldüğünde çalışmadığı görüldü: senkron çekirdeği OLAY BAŞINA
 * SAVEPOINT açar (bir olayın reddi partiyi zehirlemesin diye) ve ~31.000 olayın savepoint'leri
 * Postgres'in kilit tablosunu taşırdı — `SQLSTATE[53200] out of shared memory / You might need to
 * increase max_locks_per_transaction`. Yani tek-transaction tasarımıyla bu dosya HİÇ aktarılamaz;
 * garanti korunmuş olmaz, aktarımın kendisi imkânsız olur.
 *
 * `max_locks_per_transaction`ı büyütmek düzeltme DEĞİL erteleme olurdu: sınır bağlantı sayısıyla
 * çarpılan bir paylaşımlı bellek tahsisidir ve 20.000 müşterili bir sonraki bayi aynı duvara
 * çarpardı. Doğru cevap, toplu aktarımın tek bir devasa transaction olmamasıdır.
 *
 * KISMİ YAZMANIN KABUL EDİLEBİLİR OLMASININ SEBEBİ DEDUP'TIR: duran bir aktarımda kullanıcı AYNI
 * dosyayı yeniden yükler; yazılmış satırlar kod (ya da telefon) çakışmasından 'atlanacak' olur ve
 * yalnız eksik kalanlar girer. Yani kurtarma yolu zaten vardır ve tek adımdır. Sonuç `eklenen`
 * alanında GERÇEKTEN yazılan sayıyı ve `yarim_kaldi` bayrağını döndürür — kullanıcıya "hiçbir şey
 * yazılmadı" demek, artık söylenebilecek en kötü yalan olurdu.
 */
class PanelImportService extends PanelSyncYazici
{
    /**
     * Tek dosyada işlenecek azami satır (bellek + tek seferde geri alınamaz yazma sınırı).
     *
     * 2000'DEN 10000'E ÇIKARILDI (2026-09-11): gerçek bir devralma ölçüldü — tek bayinin
     * rehberinde 9.057 müşteri vardı. Dosyayı beşe bölmek kullanıcıya taşımanın kendisinden
     * pahalı bir el işi yükler ve hiçbir şeyi güvenceye almaz: yazma zaten parti parti akıyor
     * (bkz. sınıf açıklaması), yani elle bölmek aynı riski daha çok adımda yaşatırdı.
     */
    public const MAX_SATIR = 10000;

    /**
     * Şablon sütunları — sıra ÖNEMLİDİR, dosya başlıksız da gelebilir.
     *
     * `kod` ve `favoriler` SONA eklendi (2026-09-11): eski şablonla doldurulmuş bir dosya beş
     * sütunlu gelir ve eksik sütunlar boş sayılır — yani eski dosyalar çalışmaya devam eder.
     * Araya eklemek, sahada duran her dosyayı sessizce yanlış sütuna kaydırırdı.
     */
    public const SUTUNLAR = ['ad', 'telefon', 'adres', 'bolge', 'not', 'kod', 'favoriler'];

    /** Boş şablon (indirilip doldurulur). */
    public function sablon(): string
    {
        $ayrac = ' '.AktarimSatiri::AYRAC.' ';

        return Csv::olustur(self::SUTUNLAR, [
            ['Ayşe Yılmaz', '0532 111 22 33'.$ayrac.'0242 333 44 55', 'Şirinyalı Mah. 1497. Sk. No: 9',
                'Muratpaşa', 'Kapıcıya bırak', '100', 'Tombul Tüp'.$ayrac.'Damacana Su'],
            ['Mehmet Demir', '0533 999 88 77', 'Kükürtlü Mah. 5. Cd. No: 12', 'Osmangazi', '', '', ''],
        ]);
    }

    /**
     * Dosyayı çözümler, her satırı doğrular ve ne olacağını söyler. HİÇBİR ŞEY YAZILMAZ.
     *
     * @return array{satirlar: list<array<string, mixed>>, ozet: array{eklenecek: int, atlanacak: int, hatali: int}}
     */
    public function onizleme(string $tenantId, string $icerik): array
    {
        $cozum = $this->cozumle($tenantId, $icerik);

        return ['satirlar' => $cozum['satirlar'], 'ozet' => $cozum['ozet']];
    }

    /**
     * Dosyayı bir kez çözümler ve ÜÇ şeyi birden döndürür: ekrana çizilecek satırlar, özet
     * sayılar ve satırların NESNE hâli.
     *
     * NEDEN NESNELER DE DÖNÜYOR: `uygula()` yazarken çoklu telefonu, çoklu adresi ve favori ürün
     * listesini ister; önizleme dizisi bunları GÖSTERİM için ayraçla birleştirilmiş metne
     * indirger. O metni tekrar ayrıştırmak, aynı kuralın ikinci bir kopyasını kurmak olurdu —
     * ve iki ayrıştırıcı bu depoda tam olarak zehirli hap kapısıdır.
     *
     * @return array{satirlar: list<array<string, mixed>>, nesneler: list<AktarimSatiri>, ozet: array{eklenecek: int, atlanacak: int, hatali: int}}
     */
    private function cozumle(string $tenantId, string $icerik): array
    {
        $ham = Csv::ayikla($icerik);
        if ($ham === []) {
            throw new RuntimeException('Dosya boş görünüyor.');
        }

        $baslikVar = $this->baslikMi($ham[0]); // yukarıdaki boşluk denetiminden sonra ilk satır kesin var
        if ($baslikVar) {
            array_shift($ham);
        }

        if (count($ham) > self::MAX_SATIR) {
            throw new RuntimeException('Dosyada '.count($ham).' satır var; en fazla '.self::MAX_SATIR.' satır aktarılabilir.');
        }

        $durumu = new AktarimDurumu(
            $this->mevcutTelefonlar($tenantId),
            $this->mevcutKodlar($tenantId),
        );

        $satirlar = [];
        $nesneler = [];
        foreach ($ham as $i => $sutunlar) {
            // Satır numarası KULLANICININ gördüğü numaradır: 1 tabanlı + varsa başlık satırı.
            $satirNo = $i + 1 + ($baslikVar ? 1 : 0);
            $nesne = new AktarimSatiri($satirNo, $sutunlar);
            $nesneler[] = $nesne;
            $satirlar[] = $durumu->degerlendir($nesne);
        }

        $say = fn (string $durum) => count(array_filter($satirlar, fn ($s) => $s['durum'] === $durum));

        return [
            'satirlar' => $satirlar,
            'nesneler' => $nesneler,
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
     * SÜRE BÜTÇESİ (`$sureButcesi`, saniye) — ZAMAN AŞIMININ ÇÖZÜMÜ (2026-09-11).
     *
     * 9.048 müşterilik gerçek dosya tek çağrıda ~7,5 dakika sürüyor (ölçüldü). Hiçbir web
     * sunucusu bu isteği beklemez: php-fpm `request_terminate_timeout`, nginx
     * `fastcgi_read_timeout` ve tarayıcı, üçü de çok daha önce keser — ve kesinti tam da
     * yazmanın ortasında gelir.
     *
     * Bütçe verildiğinde bu metot BİR ADIM koşar: bütçe dolunca durur, elindeki kuyruğu yazar
     * ve `kalan` alanında kaç satırın bekletildiğini söyler. Çağıran (panel ekranı) `kalan`
     * sıfırlanana kadar yeniden çağırır. Her adım AYNI dosyayı baştan çözümler; önceki adımda
     * yazılmış satırlar dedup'tan 'atlanacak' geldiği için kendiliğinden atlanır — yani adım
     * sayacı tutmaya, dosyada imleç saklamaya gerek yoktur ve arada tarayıcı kapansa bile
     * yazılanlar yerinde kalır.
     *
     * NEDEN KUYRUĞA (queue:work) VERİLMEDİ: üretimde kuyruk işçisi var ama `app` ile `queue`
     * container'ları arasında PAYLAŞILAN DEPOLAMA YOK — işçi, panele yüklenen geçici dosyayı
     * göremez. 1,2 MB'lık içeriği iş yüküne gömmek `jobs` tablosuna devasa bir satır yazmak
     * olurdu ve ilerlemeyi göstermek için ayrıca bir kanal gerekirdi. Adımlı yazma hiçbir
     * altyapıya bağlı değildir, dev ile üretimde aynı davranır ve ilerlemeyi zaten gösterir.
     *
     * Bütçe verilmezse (varsayılan) davranış eskisi gibidir: dosya bitene kadar yazılır.
     *
     * @return array{eklenen: int, atlanan: int, hatali: int, kalan: int, durum: string, mesaj: string|null, hatalar: list<array{satir: int, aciklama: string}>, acilan_urunler: list<string>, yarim_kaldi: bool}
     */
    public function uygula(string $tenantId, string $icerik, ?string $adminId, ?float $sureButcesi = null): array
    {
        $onizleme = $this->cozumle($tenantId, $icerik);
        $eklenecek = $this->yazmaSirasi($onizleme);

        $durum = ['durum' => 'applied', 'mesaj' => null];
        $eklenen = 0;
        $acilanUrunler = [];

        if ($eklenecek !== []) {
            $urunler = new AktarimUrunleri(
                $this->mevcutUrunler($tenantId),
                fn (array $payload) => $this->olay('product', 'upsert', $payload),
            );

            $bekleyen = [];
            $bekleyenMusteri = 0;
            $basladi = microtime(true);

            try {
                foreach ($eklenecek as $satir) {
                    // SÜRE BÜTÇESİ satır BAŞINDA bakılır: elde bekleyen kuyruk varsa döngüden
                    // çıkınca aşağıda yazılır, yani durmak hiçbir müşteriyi düşürmez.
                    //
                    // `$eklenen > 0` KOŞULU İLERLEME GARANTİSİDİR, süsleme değil: bütçe küçükse
                    // (ya da sunucu o an yavaşsa) ilk satıra gelmeden dolar, adım HİÇBİR ŞEY
                    // yazmadan döner, `kalan` azalmaz ve çağıran sonsuza kadar aynı adımı
                    // tekrarlar — ekran döner, iş ilerlemez. Bu yüzden her adım EN AZ bir parti
                    // yazar; bütçe ancak ondan sonra durdurabilir.
                    if ($sureButcesi !== null && $eklenen > 0 && microtime(true) - $basladi >= $sureButcesi) {
                        break;
                    }

                    $olaylar = $this->musteriOlaylari($satir, $urunler);
                    // Ürün olayları o ürünü İLK isteyen müşteriyle aynı partiye düşer; kuyruk her
                    // turda boşaltılır ki aynı ürün ikinci kez gönderilmesin.
                    $urunOlaylari = $urunler->kuyruguBosalt();

                    // PARTİ OLAY SAYISINA GÖRE BÖLÜNÜR, MÜŞTERİ SAYISINA GÖRE DEĞİL: bir müşteri
                    // 1 + telefon + adres kadar olay üretir (ölçülen en kalabalık kayıt 10 numara
                    // taşıyordu). Sabit "150 müşteri" ile gitmek, kalabalık bir parçada 500'lük
                    // tavanı aşıp aktarımın tamamını durdururdu.
                    if ($bekleyen !== [] && count($bekleyen) + count($urunOlaylari) + count($olaylar) > SyncService::MAX_EVENTS) {
                        $this->partiYaz($tenantId, $bekleyen);
                        $eklenen += $bekleyenMusteri;
                        $bekleyen = [];
                        $bekleyenMusteri = 0;
                    }

                    $bekleyen = array_merge($bekleyen, $urunOlaylari, $olaylar);
                    $bekleyenMusteri++;
                }

                if ($bekleyen !== []) {
                    $this->partiYaz($tenantId, $bekleyen);
                    $eklenen += $bekleyenMusteri;
                }

                $acilanUrunler = $urunler->acilanUrunler();
            } catch (AktarimDurduruldu $e) {
                // KISMİ YAZMA OLABİLİR (bkz. sınıf açıklamasındaki PARTİ BAŞINA TRANSACTION).
                // Duran parti geri sarıldı; ondan öncekiler yazıldı ve `$eklenen` onları sayar.
                return [
                    'eklenen' => $eklenen,
                    'atlanan' => $onizleme['ozet']['atlanacak'],
                    'hatali' => $onizleme['ozet']['hatali'],
                    // Duran aktarımda `kalan` YAZILAMAYANLARI sayar; çağıran bunu "devam et"
                    // diye okumamalı, o yüzden `yarim_kaldi` ile birlikte değerlendirilir.
                    'kalan' => count($eklenecek) - $eklenen,
                    'durum' => $e->durum,
                    'mesaj' => $e->getMessage(),
                    'hatalar' => $this->hatalar($onizleme),
                    'acilan_urunler' => $urunler->acilanUrunler(),
                    'yarim_kaldi' => true,
                ];
            }
        }

        if ($eklenen > 0) {
            // Denetim: ADIM başına TEK satır, adet ile. Müşteri başına kayıt günlüğü boğardı.
            // Adımlı aktarımda birden çok satır düşer ve bu DOĞRUDUR: her adım ayrı bir yazmadır
            // ve denetim kaydı "ne zaman ne kadar yazıldı" sorusunu cevaplayabilmelidir.
            $this->audit($adminId, $tenantId, 'customer_import', 'n='.$eklenen);
        }

        return [
            'eklenen' => $eklenen,
            'atlanan' => $onizleme['ozet']['atlanacak'],
            'hatali' => $onizleme['ozet']['hatali'],
            // Bu adımda sıraya gelmeyen satır sayısı. 0 ise aktarım BİTMİŞTİR; >0 ise çağıran
            // aynı dosyayla yeniden çağırmalıdır (bkz. metot açıklamasındaki SÜRE BÜTÇESİ).
            'kalan' => count($eklenecek) - $eklenen,
            'durum' => $durum['durum'],
            'mesaj' => $durum['mesaj'],
            'hatalar' => $this->hatalar($onizleme),
            // Aktarım sırasında açılan ürünler SONUÇTA SÖYLENİR: bayinin kataloğuna sessizce
            // ürün eklemek, fiyatı sıfır duran kalemleri ancak ilk siparişte fark ettirirdi.
            'acilan_urunler' => $acilanUrunler,
            'yarim_kaldi' => false,
        ];
    }

    /**
     * İlk satır BAŞLIK mı, yoksa veri mi?
     *
     * Dosya başlıksız da gelebilir (bilinçli: bayinin elindeki liste çoğu zaman çıplaktır), bu
     * yüzden sezmek zorundayız. Sezgi eskiden yalnız İLK HÜCREYE bakıyordu ve şablonun başlıklarını
     * kendi diline çeviren kullanıcıyı vuruyordu: "Müşteri Adı;Cep Telefonu;Açık Adres;Semt" satırı
     * tanınmaz, VERİ sayılır ve listede "Müşteri Adı" diye bir müşteri belirirdi — üstelik sessizce,
     * çünkü satır geçerli görünür (adı var, telefonu okunamaz ama telefon zorunlu değil).
     *
     * Bu yüzden satırın TAMAMINA bakılır: hücrelerden HERHANGİ BİRİ bilinen bir sütun adıysa satır
     * başlıktır. Yanlış pozitif riski düşüktür — gerçek bir müşteri satırının bir hücresinin tam
     * olarak "telefon" ya da "adres" olması pratikte olmaz; olsa bile kaybedilen tek bir satırdır ve
     * özet sayılarda görünür. Ters yön (başlığı müşteri sanmak) ise sessiz ve kalıcı kirlilik yaratır.
     *
     * @param  list<string>  $satir
     */
    private function baslikMi(array $satir): bool
    {
        // Şablonun kendi sütunları + kullanıcıların sık yazdığı eşanlamlılar.
        $bilinen = [
            'ad', 'ad *', 'isim', 'müşteri', 'musteri', 'müşteri adı', 'musteri adi', 'ünvan', 'unvan',
            'telefon', 'tel', 'cep', 'cep telefonu', 'gsm', 'numara',
            'adres', 'açık adres', 'acik adres',
            'bolge', 'bölge', 'semt', 'mahalle',
            'not', 'notlar', 'açıklama', 'aciklama',
            'kod', 'müşteri kodu', 'musteri kodu', 'müşteri no', 'musteri no', 'cari kod', 'id',
            'favoriler', 'favori', 'favori ürünler', 'favori urunler', 'ürünler', 'urunler',
        ];

        foreach ($satir as $hucre) {
            if (in_array(mb_strtolower(trim($hucre)), $bilinen, true)) {
                return true;
            }
        }

        return false;
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
     * Tek bir partiyi KENDİ transaction'ında yazar. Parti kabul edilmezse `AktarimDurduruldu`
     * fırlatır: o partinin transaction'ı geri sarılır, ÖNCEKİ partiler yazılmış kalır
     * (bkz. sınıf açıklaması — PARTİ BAŞINA TRANSACTION).
     *
     * @param  list<array<string, mixed>>  $olaylar
     */
    private function partiYaz(string $tenantId, array $olaylar): void
    {
        $sonuc = $this->rlsIcinde($tenantId, fn () => $this->durumOzeti($this->push($tenantId, $olaylar)));

        if ($sonuc['durum'] !== 'applied') {
            throw new AktarimDurduruldu($sonuc['durum'], $sonuc['mesaj']);
        }
    }

    /**
     * Yazılacak satırlar — KODU OLANLAR ÖNCE, kodsuzlar sonra. Grupların KENDİ İÇİNDE dosya
     * sırası korunur (kararlı bölme).
     *
     * BU SIRA BİR SÜSLEME DEĞİL, DOĞRULUK KAPISI — ve gerçek dosyada ÖLÇÜLDÜ (2026-09-11):
     * kodsuz bir satıra `Customer::booted` sıradaki numarayı verir, o da `max(code) + 1`dir.
     * Dosya karışık sırada geldiğinde (9.057 satırın 343'ü kodsuz, kodlar 2 ile 9510 arasında)
     * kodsuz bir satır henüz yazılmamış BİR SONRAKİ satırın açık kodunu kapıyordu: 1553'ü
     * sunucu atıyor, birkaç satır sonra dosyada 1553 yazan gerçek müşteri geliyor ve
     * `customers_tenant_code_uniq` ihlal ediliyordu. `23505` istemci-verisi SQLSTATE'i
     * olmadığı için tek olay reddedilmiyor — TÜM PARTİ geri alınıyor, yani 9.000 satırın
     * hiçbiri yazılmıyor ve kullanıcı yalnız "Kayıt reddedildi (geçersiz veri)" görüyordu.
     *
     * Açık kodlar önce yazılınca `max(code)` dosyadaki en büyük kodun üstüne çıkar ve kodsuzlara
     * dağıtılan numaralar hiçbir açık kodla çakışamaz. Çözüm sıradadır, kilitte değil: kodsuz
     * satırlara hangi numaranın gittiği bayi için anlamsızdır (zaten yeni numaradır), oysa açık
     * kod TAŞINMASI GEREKEN veridir.
     *
     * @param  array{satirlar: list<array<string, mixed>>, nesneler: list<AktarimSatiri>}  $onizleme
     * @return list<AktarimSatiri>
     */
    private function yazmaSirasi(array $onizleme): array
    {
        $kodlu = [];
        $kodsuz = [];
        foreach ($onizleme['satirlar'] as $i => $satir) {
            if ($satir['durum'] !== 'eklenecek') {
                continue;
            }
            $nesne = $onizleme['nesneler'][$i];
            if ($nesne->kod !== null) {
                $kodlu[] = $nesne;
            } else {
                $kodsuz[] = $nesne;
            }
        }

        return array_merge($kodlu, $kodsuz);
    }

    /**
     * İçe aktarılan satırın olayları. Hepsi YENİ kayıttır (dedup'tan geçti) → mevcut satır okuma
     * ve LWW ileri alma gerekmez, damga `now()`tur.
     *
     * @return list<array<string, mixed>>
     */
    private function musteriOlaylari(AktarimSatiri $satir, AktarimUrunleri $urunler): array
    {
        $musteriId = (string) Str::uuid7();

        $musteri = [
            'id' => $musteriId,
            'name' => $satir->ad,
            'note' => $this->bosNull($satir->not),
            'blacklisted_at' => null,
            // Boş dizi DEĞİL null: "favorisi yok" TEK bir hâldir (migration 004010).
            'favorite_product_ids' => $satir->favoriler === []
                ? null
                : $urunler->kimlikler($satir->favoriler),
        ];

        // KOD yalnız verilmişse gönderilir. Anahtar hiç yoksa `Customer::booted` sıradaki
        // numarayı atar — "anahtar yok ≠ null" (2026-08-05 dersi) burada da geçerli.
        if ($satir->kod !== null) {
            $musteri['code'] = $satir->kod;
        }

        $olaylar = [$this->olay('customer', 'upsert', $musteri)];

        // İLKİ BİRİNCİLDİR: arayan tanıma ve sipariş ekranı birincil numarayı/adresi gösterir.
        // Dosyadaki sıra bayinin sırasıdır ve onu yeniden dizmek taşıdığı bilgiyi siler.
        foreach ($satir->telefonlar as $sira => $telefon) {
            $olaylar[] = $this->olay('customer_phone', 'upsert', [
                'id' => (string) Str::uuid7(),
                'customer_id' => $musteriId,
                'phone_e164' => $telefon,
                'phone_last10' => Telefon::son10($telefon),
                'is_primary' => $sira === 0,
            ]);
        }

        foreach ($satir->adresler as $sira => $adres) {
            $olaylar[] = $this->olay('customer_address', 'upsert', [
                'id' => (string) Str::uuid7(),
                'customer_id' => $musteriId,
                'address_text' => $adres,
                // Bölge YALNIZ birincil adrese yazılır: dosyada tek bölge hücresi vardır ve
                // onu her adrese kopyalamak, ikinci adresin gerçekte başka bir semtte olduğu
                // durumda uydurma bir bilgi üretirdi.
                'region' => $sira === 0 ? $this->bosNull($satir->bolge) : null,
                'is_primary' => $sira === 0,
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

    /**
     * Bayide kullanımdaki müşteri kodları: kod → müşteri adı.
     *
     * SİLİNMİŞ MÜŞTERİLER DE SAYILIR (`deleted_at` filtresi YOK, telefonlardan farklı olarak):
     * `customers_tenant_code_uniq` kısmi indeksi yalnız `code IS NOT NULL` koşuluna bakar,
     * tombstone'a bakmaz. Silinmiş bir müşterinin kodunu yeniden kullanmaya kalkmak indeks
     * ihlali doğurur ve `23505` istemci-verisi hatası sayılmadığı için TÜM partiyi geri alır —
     * yani tek bir yeniden kullanılan kod, 9.000 satırlık aktarımın tamamını sessizce düşürür.
     *
     * @return array<int, string>
     */
    private function mevcutKodlar(string $tenantId): array
    {
        $satirlar = DB::connection($this->panelConnection)->table('customers')
            ->where('tenant_id', $tenantId)
            ->whereNotNull('code')
            ->select('code', 'name')
            ->get();

        $harita = [];
        foreach ($satirlar as $satir) {
            $harita[(int) $satir->code] = (string) $satir->name;
        }

        return $harita;
    }

    /**
     * Bayinin ürün kataloğu: ad → kimlik. Favori sütunundaki adları eşlemek için.
     *
     * PANEL BAĞLANTISIYLA ve tenant_id AÇIKÇA filtrelenerek okunur (BYPASSRLS, kırmızı çizgi #1) —
     * `mevcutTelefonlar` ile aynı desen. Aktarım artık parti başına ayrı transaction'larda yazdığı
     * için (bkz. sınıf açıklaması) bu okuma hiçbir transaction'ın içinde değildir; aktarım
     * sırasında AÇILAN ürünler zaten `AktarimUrunleri`nin bellek haritasında durur ve sonraki
     * partiler oradan çözer — veritabanına tekrar sormaya gerek yoktur.
     *
     * Silinmiş ürünler DIŞARIDA: tombstone'lu bir ürünü favoriye bağlamak, bayinin listesinde
     * çözülemeyen bir kimlik bırakır (istemci çözemediği id'yi atlar) — yenisi açılır.
     *
     * @return array<string, string>
     */
    private function mevcutUrunler(string $tenantId): array
    {
        $satirlar = DB::connection($this->panelConnection)->table('products')
            ->where('tenant_id', $tenantId)
            ->whereNull('deleted_at')
            ->select('id', 'name')
            ->get();

        $harita = [];
        foreach ($satirlar as $satir) {
            $harita[(string) $satir->name] = (string) $satir->id;
        }

        return $harita;
    }
}
