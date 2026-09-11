<?php

namespace Tests\Feature\Api;

use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\CustomerAddress;
use App\Models\CustomerPhone;
use App\Models\Product;
use App\Panel\PanelImportService;
use App\Support\Provisioning;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * MÜŞTERİ AKTARIMININ GENİŞ SÜTUNLARI (2026-09-11) — `kod`, `favoriler` ve çok değerli
 * `telefon`/`adres` hücreleri.
 *
 * NEDEN YAZILDI: gerçek bir devralma ölçüldü (tek bayide 9.057 kayıt, 13.276 numara, 8.865 adres).
 * O dosyada eski aktarıcının sessizce KAYBETTİĞİ üç şey vardı ve üçü de sahada ancak aylar sonra
 * fark edilirdi:
 *
 *   1. Bayinin eski müşteri numarası (telefonla aradığı numara) — yeniden numaralanıyordu.
 *   2. İkinci ve sonraki telefonlar — arayan tanıma o numaralarda kör kalırdı.
 *   3. Favori ürünler — sipariş ekranındaki hızlı seçim boş açılırdı.
 *
 * Buradaki testler o üç kaybın geri gelmediğini kilitler. Dosyanın BOZUK gelme yolları
 * `PanelImportEdgeTest`te; bu dosya DOLU ve DOĞRU bir dosyanın eksiksiz yazıldığını sınar.
 */
class PanelImportGenisSutunTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private function servis(): PanelImportService
    {
        return new PanelImportService('pgsql_panel');
    }

    private function makeAdmin(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Aktarım', 'email' => 'genis@sipario.test', 'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    /** @param list<string> $satirlar */
    private function csv(array $satirlar): string
    {
        return implode("\n", $satirlar)."\n";
    }

    #[Test]
    public function eski_musteri_kodu_aynen_korunur(): void
    {
        // Bayi bu numarayı kâğıda yazdı, müşteriye söyledi, telefonda onunla arıyor. Yeniden
        // numaralamak taşımanın kendisini işe yaramaz kılardı.
        $a = $this->makeTenant('a');

        $sonuc = $this->servis()->uygula($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Kodlu Müşteri;0532 111 22 33;Adres 1;Muratpaşa;;4207;',
        ]), $this->makeAdmin()->id);

        $this->assertSame('applied', $sonuc['durum']);
        $this->assertSame(1, $sonuc['eklenen']);

        $musteri = $this->asOwner(fn () => Customer::query()->firstOrFail());
        $this->assertSame(4207, $musteri->code, 'Dosyadaki kod aynen yazılmalı.');
    }

    #[Test]
    public function kod_bos_birakilirsa_sunucu_sirayi_atar(): void
    {
        // Geriye uyum: kodsuz satır eski davranışı sürdürmeli (SiraKodu 100'den başlar).
        $a = $this->makeTenant('a');

        $this->servis()->uygula($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Kodsuz Müşteri;0532 111 22 33;Adres 1;Muratpaşa;;;',
        ]), $this->makeAdmin()->id);

        $musteri = $this->asOwner(fn () => Customer::query()->firstOrFail());
        $this->assertSame(100, $musteri->code, 'Kod boşsa sunucu sıradaki numarayı atamalı.');
    }

    #[Test]
    public function bes_sutunlu_eski_dosya_calismaya_devam_eder(): void
    {
        // Sahada duran her şablon beş sütunludur. `kod` ve `favoriler` SONA eklendiği için eksik
        // sütunlar boş sayılmalı — araya eklemek bu dosyaları sessizce yanlış sütuna kaydırırdı.
        $a = $this->makeTenant('a');

        $sonuc = $this->servis()->uygula($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not',
            'Eski Şablon;0532 111 22 33;Adres 1;Muratpaşa;Not burada',
        ]), $this->makeAdmin()->id);

        $this->assertSame('applied', $sonuc['durum']);
        $this->assertSame(1, $sonuc['eklenen']);

        $musteri = $this->asOwner(fn () => Customer::query()->firstOrFail());
        $this->assertSame('Eski Şablon', $musteri->name);
        $this->assertSame('Not burada', $musteri->note);
        $this->assertNull($musteri->favorite_product_ids, 'Favori sütunu yoksa liste null kalmalı.');
    }

    #[Test]
    public function coklu_telefon_ve_adres_eksiksiz_yazilir_ilki_birincildir(): void
    {
        // Ölçülen dosyada bir kayıtta 10 numaraya kadar çıkıyordu. Tek numaraya indirgemek,
        // arayan tanımanın geri kalan numaralarda kör kalması demektir.
        $a = $this->makeTenant('a');

        $this->servis()->uygula($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Çok Numaralı;0532 111 22 33 ::: 0533 999 88 77 ::: 0242 323 37 01;'
                .'Ev Adresi ::: İşyeri Adresi;Muratpaşa;;500;',
        ]), $this->makeAdmin()->id);

        [$telefonlar, $adresler] = $this->asOwner(fn () => [
            CustomerPhone::query()->orderBy('created_at')->get(),
            CustomerAddress::query()->orderBy('created_at')->get(),
        ]);

        $this->assertCount(3, $telefonlar, 'Üç numaranın üçü de yazılmalı.');
        $this->assertSame(['+905321112233', '+905339998877', '+902423233701'],
            $telefonlar->pluck('phone_e164')->all(), 'Dosyadaki sıra korunmalı.');
        $this->assertTrue((bool) $telefonlar[0]->is_primary, 'İlk numara birincil olmalı.');
        $this->assertSame(1, $telefonlar->where('is_primary', true)->count(), 'Tek birincil numara olmalı.');

        $this->assertCount(2, $adresler);
        $this->assertSame('Ev Adresi', $adresler[0]->address_text);
        $this->assertTrue((bool) $adresler[0]->is_primary);
        $this->assertSame('Muratpaşa', $adresler[0]->region);
        // Bölge hücresi tektir; ikinci adrese kopyalamak uydurma bilgi üretirdi.
        $this->assertNull($adresler[1]->region, 'Bölge yalnız birincil adrese yazılmalı.');
    }

    #[Test]
    public function ayni_numara_iki_farkli_kodlu_musteride_ikisi_de_yazilir(): void
    {
        // EN KRİTİK GERİLEME TESTİ: ölçülen dosyada 269 numara birden çok müşteride geçiyordu
        // (aile, ev + işyeri). Telefonla tekilleştirmek 442 GERÇEK müşteriyi atardı ve bayi bunu
        // ancak o müşteri arayınca fark ederdi. Kod varsa dedup anahtarı KODDUR.
        $a = $this->makeTenant('a');

        $sonuc = $this->servis()->uygula($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Baba;0532 111 22 33;Ev;Muratpaşa;;700;',
            'Oğul;0532 111 22 33;Ev;Muratpaşa;;701;',
        ]), $this->makeAdmin()->id);

        $this->assertSame(2, $sonuc['eklenen'], 'Aynı numarayı paylaşan iki kodlu müşteri de yazılmalı.');
        $this->assertSame([700, 701], $this->asOwner(
            fn () => Customer::query()->orderBy('code')->pluck('code')->all()
        ));
    }

    #[Test]
    public function ayni_kod_dosyada_iki_kez_gecerse_ikincisi_atlanir(): void
    {
        $a = $this->makeTenant('a');

        $onizleme = $this->servis()->onizleme($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Birinci;0532 111 22 33;Ev;Muratpaşa;;900;',
            'İkinci;0533 999 88 77;Ev;Muratpaşa;;900;',
        ]));

        $this->assertSame(1, $onizleme['ozet']['eklenecek']);
        $this->assertSame(1, $onizleme['ozet']['atlanacak']);
        $this->assertStringContainsString('dosyada', $onizleme['satirlar'][1]['aciklama']);
    }

    #[Test]
    public function bayide_kullanimda_olan_kod_satiri_hatali_yapar(): void
    {
        // FARKLI müşteri: gerçek çakışma. Kodu sessizce düşürüp müşteriyi yine de yazmak, bayinin telefonda aradığı numarayı
        // başka birine bırakırdı. `customers_tenant_code_uniq` zaten yazmaya izin vermez ve
        // 23505 istemci-verisi sayılmadığı için TÜM parti geri alınırdı — önden yakalanmalı.
        $a = $this->makeTenant('a');

        $this->servis()->uygula($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Önce Gelen;0532 111 22 33;Ev;Muratpaşa;;1234;',
        ]), $this->makeAdmin()->id);

        $onizleme = $this->servis()->onizleme($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Sonra Gelen;0533 999 88 77;Ev;Muratpaşa;;1234;',
        ]));

        $this->assertSame(1, $onizleme['ozet']['hatali']);
        $this->assertStringContainsString('Önce Gelen', $onizleme['satirlar'][0]['aciklama'],
            'Kullanıcı kodun KİMDE olduğunu görmeli.');
    }

    #[Test]
    public function ayni_dosya_yeniden_yuklenirse_yazilanlar_atlanir_hatali_sayilmaz(): void
    {
        // KURTARMA YOLU: yarıda kalmış bir aktarım, AYNI dosya yeniden yüklenerek sürdürülür.
        // Yazılmış satırların kodu artık bayide kayıtlıdır — bunları 'hatali' saymak kurtarmayı
        // imkânsız kılardı: kullanıcı 9.000 satırlık dosyayı sürdürmek isterken "9.000 satır
        // hatalı" görür ve aktarımın çöktüğünü sanardı. Aynı müşteri → 'atlanacak'.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $icerik = $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Sürdürülen;0532 111 22 33;Ev;Muratpaşa;;1500;',
        ]);

        $this->servis()->uygula($a['tenant']->id, $icerik, $admin->id);
        $ikinci = $this->servis()->uygula($a['tenant']->id, $icerik, $admin->id);

        $this->assertSame(0, $ikinci['eklenen'], 'Aynı müşteri ikinci kez yazılmamalı.');
        $this->assertSame(1, $ikinci['atlanan'], 'Zaten aktarılmış satır ATLANMALI.');
        $this->assertSame(0, $ikinci['hatali'], 'Kurtarma yolu "hatalı" üretmemeli.');
        $this->assertSame(1, $this->asOwner(fn () => Customer::query()->count()));
    }

    #[Test]
    public function favori_urunler_bayide_yoksa_acilir_ve_musteriye_baglanir(): void
    {
        $a = $this->makeTenant('a');

        $sonuc = $this->servis()->uygula($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Tüpçü Müşteri;0532 111 22 33;Ev;Muratpaşa;;300;Tombul Tüp ::: Madran Su',
        ]), $this->makeAdmin()->id);

        $this->assertSame('applied', $sonuc['durum']);
        $this->assertEqualsCanonicalizing(['Tombul Tüp', 'Madran Su'], $sonuc['acilan_urunler'],
            'Açılan ürünler kullanıcıya SÖYLENMELİ — sessizce katalog büyümemeli.');

        [$urunler, $musteri] = $this->asOwner(fn () => [
            Product::query()->get(), Customer::query()->firstOrFail(),
        ]);

        $this->assertCount(2, $urunler);
        $this->assertSame([0, 0], $urunler->pluck('unit_price_kurus')->all(),
            'Fiyat uydurulmaz; bayi kendi fiyatını girer.');

        $favoriler = $musteri->favorite_product_ids;
        $this->assertIsArray($favoriler);
        $this->assertCount(2, $favoriler);
        $this->assertEqualsCanonicalizing($urunler->pluck('id')->all(), $favoriler,
            'Favori listesi açılan ürünlerin KİMLİKLERİNİ taşımalı.');
        // Sıra bayinin tercihidir: dosyadaki sıra korunmalı.
        $tombul = $urunler->firstWhere('name', 'Tombul Tüp');
        $this->assertSame((string) $tombul->id, $favoriler[0], 'Dosyadaki sıra korunmalı.');
    }

    #[Test]
    public function var_olan_urun_yeniden_acilmaz_buyuk_kucuk_harf_onemsiz(): void
    {
        // Aynı dosyada "Tombul Tüp" ve "TOMBUL TÜP" geçebilir; iki ürün açmak bayinin kataloğunu
        // ilk günden ikiye bölerdi.
        $a = $this->makeTenant('a');

        $this->servis()->uygula($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Bir;0532 111 22 33;Ev;Muratpaşa;;301;Tombul Tüp',
            'İki;0533 999 88 77;Ev;Muratpaşa;;302;TOMBUL TÜP',
            'Üç;0534 777 66 55;Ev;Muratpaşa;;303;tombul tüp',
        ]), $this->makeAdmin()->id);

        $urunler = $this->asOwner(fn () => Product::query()->get());
        $this->assertCount(1, $urunler, 'Yazımı farklı olan aynı ürün tek kalemdir.');

        $favoriler = $this->asOwner(fn () => Customer::query()->orderBy('code')->get())
            ->pluck('favorite_product_ids');
        foreach ($favoriler as $liste) {
            $this->assertSame([(string) $urunler[0]->id], $liste, 'Üçü de aynı ürüne bağlanmalı.');
        }
    }

    #[Test]
    public function bayide_kayitli_urun_kataloga_ikinci_kez_eklenmez(): void
    {
        $a = $this->makeTenant('a');

        $mevcut = $this->asOwner(fn () => Product::query()->create([
            'id' => (string) Str::uuid7(),
            'tenant_id' => $a['tenant']->id,
            'name' => 'Tombul Tüp',
            'unit_price_kurus' => 45000,
        ]));

        $sonuc = $this->servis()->uygula($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Müşteri;0532 111 22 33;Ev;Muratpaşa;;304;Tombul Tüp',
        ]), $this->makeAdmin()->id);

        $this->assertSame([], $sonuc['acilan_urunler'], 'Kayıtlı ürün yeniden açılmamalı.');
        $this->assertSame(1, $this->asOwner(fn () => Product::query()->count()));
        $this->assertSame(45000, $this->asOwner(fn () => Product::query()->firstOrFail())->unit_price_kurus,
            'Mevcut ürünün fiyatı sıfırlanmamalı.');

        $musteri = $this->asOwner(fn () => Customer::query()->firstOrFail());
        $this->assertSame([(string) $mevcut->id], $musteri->favorite_product_ids);
    }

    #[Test]
    public function gecersiz_kod_satiri_partiyi_dusurmez_hata_olarak_raporlanir(): void
    {
        // `customers.code` int4'tür; tavanı aşan değer `22003` üretir ve o SQLSTATE istemci-verisi
        // sayılmadığı için TÜM parti geri alınırdı. Sınır satır bazında, numarasıyla yakalanmalı.
        $a = $this->makeTenant('a');

        $sonuc = $this->servis()->uygula($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Geçerli;0532 111 22 33;Ev;Muratpaşa;;400;',
            'Taşan Kod;0533 999 88 77;Ev;Muratpaşa;;99999999999;',
            'Harfli Kod;0534 777 66 55;Ev;Muratpaşa;;A12;',
        ]), $this->makeAdmin()->id);

        $this->assertSame('applied', $sonuc['durum'], 'Bozuk kod dosyanın tamamını düşürmemeli.');
        $this->assertSame(1, $sonuc['eklenen']);
        $this->assertSame(2, $sonuc['hatali']);
        $this->assertSame([3, 4], array_column($sonuc['hatalar'], 'satir'),
            'Kullanıcı hangi satırı düzelteceğini bilmeli.');
    }

    #[Test]
    public function adimli_aktarim_bolunse_de_ayni_sonucu_verir(): void
    {
        // ZAMAN AŞIMI ÇÖZÜMÜ: 9.000 satırlık dosya tek istekte ~7,5 dakika sürüyor ve hiçbir web
        // sunucusu o isteği beklemez. Servis süre bütçesiyle BİR ADIM koşar, `kalan` ile kaç
        // satırın beklediğini söyler ve panel bitene kadar yeniden çağırır.
        //
        // SINANAN ŞEY: bölmek sonucu DEĞİŞTİRMEMELİ. Sıfır saniyelik bütçe her turda yalnız bir
        // parti yazdırır — yani en agresif bölünme; toplam yine de tam ve tekrarsız olmalı.
        //
        // 200 SATIR ŞART: parti olay sayısına göre kapanır (MAX_EVENTS = 500) ve buradaki her
        // müşteri 3 olay üretir (müşteri + telefon + adres). Daha küçük bir küme tek partiye
        // sığar, hiç bölünmez ve test bölünmeyi SINAMADAN yeşil görünürdü.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $adet = 200;
        $satirlar = ['ad;telefon;adres;bolge;not;kod;favoriler'];
        for ($i = 0; $i < $adet; $i++) {
            $satirlar[] = 'Müşteri '.$i.';053'.str_pad((string) $i, 9, '0', STR_PAD_LEFT)
                .';Adres '.$i.';Muratpaşa;;'.(2000 + $i).';Tombul Tüp';
        }
        $icerik = $this->csv($satirlar);

        $servis = $this->servis();
        $toplamYazilan = 0;
        $tur = 0;

        do {
            $sonuc = $servis->uygula($a['tenant']->id, $icerik, $admin->id, 0.0);
            $this->assertSame('applied', $sonuc['durum']);
            $toplamYazilan += $sonuc['eklenen'];
            $this->assertLessThan(20, ++$tur, 'Adımlar ilerlemiyor — sonsuz döngü riski.');
        } while ($sonuc['kalan'] > 0);

        $this->assertGreaterThan(1, $tur, 'Sıfır bütçeyle aktarım gerçekten bölünmeliydi.');
        $this->assertSame($adet, $toplamYazilan, 'Bölünme hiçbir müşteriyi düşürmemeli.');
        $this->assertSame($adet, $this->asOwner(fn () => Customer::query()->count()),
            'Bölünme hiçbir müşteriyi İKİ KEZ yazmamalı.');

        // Ürün de tek kalem olmalı: her adım kendi AktarimUrunleri'ni kurar ama bayide zaten
        // açılmış ürünü veritabanından okur — yoksa her turda bir "Tombul Tüp" daha açılırdı.
        $this->assertSame(1, $this->asOwner(fn () => Product::query()->count()),
            'Her adım aynı ürünü yeniden açmamalı.');

        $kodlar = $this->asOwner(fn () => Customer::query()->orderBy('code')->pluck('code')->all());
        $this->assertSame(range(2000, 2000 + $adet - 1), $kodlar, 'Kodlar bölünmeden etkilenmemeli.');
    }

    #[Test]
    public function sure_butcesi_verilmezse_dosya_tek_cagrida_biter(): void
    {
        // Geriye uyum: bütçesiz çağrı (mevcut testler ve konsol kullanımı) eskisi gibi
        // dosyayı sonuna kadar yazar ve `kalan` sıfır döner.
        $a = $this->makeTenant('a');

        $sonuc = $this->servis()->uygula($a['tenant']->id, $this->csv([
            'ad;telefon;adres;bolge;not;kod;favoriler',
            'Bir;0532 111 22 33;Ev;Muratpaşa;;601;',
            'İki;0533 999 88 77;Ev;Muratpaşa;;602;',
            'Üç;0534 777 66 55;Ev;Muratpaşa;;603;',
        ]), $this->makeAdmin()->id);

        $this->assertSame(3, $sonuc['eklenen']);
        $this->assertSame(0, $sonuc['kalan'], 'Bütçesiz çağrıda hiçbir satır beklemede kalmamalı.');
    }

    #[Test]
    public function mobil_push_musteri_kodunu_ezemez(): void
    {
        // KOD SUNUCUDA ATANIR (migration 801). Panelin sentetik cihazı istisnadır; gerçek bir
        // cihazın gönderdiği `code` YOK SAYILMALI — yoksa çevrimdışı iki cihaz aynı numarayı
        // üretir ve biri kısmi unique indekse çarpıp 'rejected' olurdu (kayıt kaybolur gibi).
        $a = $this->makeTenant('a');

        $this->pushEvents($this->tokenFor($a['patron']), [
            $this->customerUpsert(['name' => 'Cihazdan Gelen', 'code' => 7777]),
        ])->assertOk();

        $musteri = $this->asOwner(fn () => Customer::query()->firstOrFail());
        $this->assertNotSame(7777, $musteri->code, 'Cihazın gönderdiği kod yok sayılmalı.');
        $this->assertSame(100, $musteri->code, 'Sunucu kendi sırasını atamalı.');
    }
}
