<?php

namespace Tests\Feature\Api;

use App\Models\AdminUser;
use App\Models\Customer;
use App\Models\CustomerAddress;
use App\Models\CustomerPhone;
use App\Panel\PanelImportService;
use App\Support\Provisioning;
use PHPUnit\Framework\Attributes\Test;
use RuntimeException;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5c-3 · D4 — müşteri CSV aktarımının KENAR DURUMLARI.
 *
 * PanelCsvTest mutlu yolu ve başlıca dedup senaryolarını kapsıyor. Buradaki testler dosyanın
 * BOZUK gelebileceği yolları sınar. Gerekçe: bu dosyayı bizim yazdığımız şablondan üreten kullanıcı
 * azınlıktır — çoğu bayi elindeki listeyi kendi Excel'inden verir; sütunlar kayar, başlık yeniden
 * adlandırılır, hücrelere sınırsız uzunlukta metin yapıştırılır.
 *
 * ORTAK BEKLENTİ: bozuk bir SATIR, dosyanın TAMAMINI düşürmemeli. Aktarımın sözleşmesi satır satır
 * rapordur ("12. satır: telefon okunamadı"); bir satır yüzünden 500 almak kullanıcıyı 300 satırlık
 * dosyada kör bırakır.
 */
class PanelImportEdgeTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private function servis(): PanelImportService
    {
        return new PanelImportService('pgsql_panel');
    }

    private function makeAdmin(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Aktarım', 'email' => 'aktarim@sipario.test', 'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    /** @param list<string> $satirlar */
    private function csv(array $satirlar): string
    {
        return implode("\n", $satirlar)."\n";
    }

    #[Test]
    public function bos_ve_yalnizca_bosluk_iceren_dosya_anlasilir_hatayla_reddedilir(): void
    {
        $a = $this->makeTenant('a');

        foreach (['', "\n\n\n", ";;;;\n;;;;\n", "\xEF\xBB\xBF"] as $icerik) {
            try {
                $this->servis()->onizleme($a['tenant']->id, $icerik);
                $this->fail('Boş dosya reddedilmeliydi.');
            } catch (RuntimeException $e) {
                $this->assertStringContainsString('boş', mb_strtolower($e->getMessage()),
                    'Kullanıcı dosyanın boş olduğunu anlamalı.');
            }
        }

        $this->assertSame(0, $this->asOwner(fn () => Customer::query()->count()), 'Hiçbir kayıt oluşmamalı.');
    }

    #[Test]
    public function taninmayan_baslik_satiri_musteri_olarak_yazilmaz(): void
    {
        // Kullanıcı şablonun başlıklarını kendi diline çevirir ("Müşteri Adı;Cep;..."). Başlık
        // tanınmazsa VERİ satırı sayılır ve listede "Müşteri Adı" diye bir müşteri belirir —
        // sessiz, çünkü hata da vermez. Başlık sezgisi bu yüzden tek hücreye değil satırın
        // TAMAMINA bakmalı.
        $a = $this->makeTenant('a');

        $icerik = $this->csv([
            'Müşteri Adı;Cep Telefonu;Açık Adres;Semt;Açıklama',
            'Ayşe Yılmaz;0532 111 22 33;Şirinyalı Mah.;Muratpaşa;',
        ]);

        $onizleme = $this->servis()->onizleme($a['tenant']->id, $icerik);

        $this->assertSame(1, $onizleme['ozet']['eklenecek'], 'Yalnız gerçek veri satırı eklenmeli.');
        $adlar = array_column($onizleme['satirlar'], 'ad');
        $this->assertNotContains('Müşteri Adı', $adlar, 'Başlık satırı müşteri olarak okunmamalı.');
        $this->assertContains('Ayşe Yılmaz', $adlar);
    }

    #[Test]
    public function hatali_ve_gecerli_satir_karisiminda_gecerliler_yazilir_hatalilar_raporlanir(): void
    {
        // KISMİ BAŞARI: 300 satırlık bir dosyada 3 satır bozuksa 297'si yazılmalı ve kullanıcı
        // hangi 3'ü düzelteceğini SATIR NUMARASIYLA öğrenmeli. "Hepsi ya da hiçbiri" davranışı
        // onboarding'i durdururdu.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $icerik = $this->csv([
            'ad;telefon;adres;bolge;not',
            'Geçerli Bir;0532 111 22 33;Adres 1;Muratpaşa;',   // 2. satır — yazılır
            ';0533 222 33 44;Adres 2;Kepez;',                   // 3. satır — ad boş
            'Geçerli İki;0534 333 44 55;Adres 3;Konyaaltı;',    // 4. satır — yazılır
            'X;0535 444 55 66;Adres 4;Lara;',                   // 5. satır — ad çok kısa
            'Geçerli Üç;bu telefon değil;Adres 5;Döşemealtı;',  // 6. satır — telefon okunamadı
        ]);

        $sonuc = $this->servis()->uygula($a['tenant']->id, $icerik, $admin->id);

        $this->assertSame('applied', $sonuc['durum']);
        $this->assertSame(2, $sonuc['eklenen'], 'Geçerli satırlar yazılmalı.');
        $this->assertSame(3, $sonuc['hatali'], 'Bozuk satırlar sayılmalı.');

        // Rapor satır NUMARASI vermeli (kullanıcı dosyada o satırı bulabilmeli).
        $satirNolar = array_column($sonuc['hatalar'], 'satir');
        $this->assertSame([3, 5, 6], $satirNolar, 'Hata satır numaraları kullanıcının gördüğü numaralar olmalı.');
        $this->assertStringContainsString('Ad boş', $sonuc['hatalar'][0]['aciklama']);
        $this->assertStringContainsString('kısa', $sonuc['hatalar'][1]['aciklama']);
        $this->assertStringContainsString('Telefon', $sonuc['hatalar'][2]['aciklama']);

        // Gerçekten yazılanlar: yalnız iki geçerli satır.
        $adlar = $this->asOwner(fn () => Customer::query()->orderBy('name')->pluck('name')->all());
        $this->assertSame(['Geçerli Bir', 'Geçerli İki'], $adlar);
    }

    #[Test]
    public function cok_uzun_alan_degerleri_satir_hatasi_olur_dosyayi_dusurmez(): void
    {
        // KOLON SINIRLARI: `customer_addresses.region` varchar(80), `customer_phones.phone_e164`
        // varchar(32). Kullanıcı hücreye sınırsız metin yapıştırabilir; sınır aşılırsa Postgres
        // 22001 atar. Bu, aktarımın SARILDIĞI transaction'ın içinde olduğu için yalnız o satırı
        // değil DOSYANIN TAMAMINI geri alır ve kullanıcı hangi satırın suçlu olduğunu göremez.
        // Doğru davranış: uzunluk satır doğrulamasında yakalanır, satır 'hatalı' işaretlenir,
        // dosyanın geri kalanı yazılır.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $icerik = $this->csv([
            'ad;telefon;adres;bolge;not',
            'Normal Müşteri;0532 111 22 33;Normal Adres;Muratpaşa;',
            'Uzun Bölge;0533 222 33 44;Adres;'.str_repeat('B', 200).';',
            'Uzun Telefon;+'.str_repeat('9', 40).';Adres;Kepez;',
            'Uzun Adres;0535 444 55 66;'.str_repeat('A', 3000).';Kepez;',
            'Uzun Not;0536 555 66 77;Adres;Kepez;'.str_repeat('N', 3000),
        ]);

        $sonuc = $this->servis()->uygula($a['tenant']->id, $icerik, $admin->id);

        $this->assertSame('applied', $sonuc['durum'], 'Tek bir uzun hücre dosyanın tamamını düşürmemeli.');
        $this->assertGreaterThanOrEqual(1, $sonuc['eklenen'], 'Normal satır her hâlükârda yazılmalı.');

        $adlar = $this->asOwner(fn () => Customer::query()->pluck('name')->all());
        $this->assertContains('Normal Müşteri', $adlar);

        // Sınırı aşan satırlar kullanıcıya SATIR NUMARASIYLA bildirilmeli (sessizce kırpılmamalı).
        $this->assertSame($sonuc['hatali'], count($sonuc['hatalar']), 'Her hatalı satırın açıklaması olmalı.');
        foreach ($sonuc['hatalar'] as $hata) {
            $this->assertGreaterThan(1, $hata['satir']);
            $this->assertNotSame('', $hata['aciklama']);
        }

        // Yazılan hiçbir değer kolon sınırını aşmamış olmalı (sessiz kırpma da kabul edilebilir bir
        // sonuçtur; kabul EDİLEMEZ olan, dosyanın tamamının çökmesidir).
        $this->asOwner(function () {
            foreach (CustomerAddress::query()->get() as $adres) {
                $this->assertLessThanOrEqual(80, mb_strlen((string) $adres->region));
            }
            foreach (CustomerPhone::query()->get() as $telefon) {
                $this->assertLessThanOrEqual(32, mb_strlen((string) $telefon->phone_e164));
            }
        });
    }

    #[Test]
    public function turkce_karakterler_utf8_bom_ile_bozulmadan_yazilir(): void
    {
        // Excel'in kaydettiği dosya BOM'lu gelir. BOM temizlenmezse ilk hücre "\xEF\xBB\xBFad"
        // olur, başlık tanınmaz ve ilk müşterinin adı görünmez bir karakterle başlar.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $icerik = "\xEF\xBB\xBF".$this->csv([
            'ad;telefon;adres;bolge;not',
            'Şükrü Çağlayangil;0532 111 22 33;Güzeloba Mah. İğneada Sk.;Muratpaşa;Öğlen götür',
            'Ayşegül Öztürk;0533 222 33 44;Çığlık Sk. No: 3;Döşemealtı;',
        ]);

        $sonuc = $this->servis()->uygula($a['tenant']->id, $icerik, $admin->id);

        $this->assertSame(2, $sonuc['eklenen']);
        $this->assertSame(0, $sonuc['hatali']);

        $adlar = $this->asOwner(fn () => Customer::query()->orderBy('name')->pluck('name')->all());
        $this->assertContains('Şükrü Çağlayangil', $adlar, 'Türkçe karakterler bozulmadan yazılmalı.');
        $this->assertContains('Ayşegül Öztürk', $adlar);

        $notlar = $this->asOwner(fn () => Customer::query()->whereNotNull('note')->pluck('note')->all());
        $this->assertContains('Öğlen götür', $notlar);

        $adresler = $this->asOwner(fn () => CustomerAddress::query()->pluck('address_text')->all());
        $this->assertContains('Güzeloba Mah. İğneada Sk.', $adresler);
    }

    #[Test]
    public function sutunu_eksik_ve_fazla_satirlar_okunabildigi_kadar_okunur(): void
    {
        // Elden gelen dosyada satırların sütun sayısı tutmaz: kimi satırda yalnız ad+telefon,
        // kiminde fazladan sütun vardır. Eksik sütun hata DEĞİLDİR (adres opsiyoneldir); fazlası
        // yok sayılmalıdır. İkisi de dosyayı düşürmemeli.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();

        $icerik = $this->csv([
            'ad;telefon;adres;bolge;not',
            'Yalnız Ad',
            'Ad Ve Telefon;0532 111 22 33',
            'Fazla Sutun;0533 222 33 44;Adres;Kepez;Not;FAZLA;DAHA FAZLA',
        ]);

        $sonuc = $this->servis()->uygula($a['tenant']->id, $icerik, $admin->id);

        $this->assertSame(3, $sonuc['eklenen'], 'Üçü de yazılabilmeli.');
        $this->assertSame(0, $sonuc['hatali']);

        $adlar = $this->asOwner(fn () => Customer::query()->orderBy('name')->pluck('name')->all());
        $this->assertSame(['Ad Ve Telefon', 'Fazla Sutun', 'Yalnız Ad'], $adlar);
    }
}
