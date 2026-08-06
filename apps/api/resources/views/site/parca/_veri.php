<?php

/*
 * GENEL SİTE İÇERİĞİ — tek kaynak.
 *
 * Kaynak: design_handoff_web_and_yonetim_paneli/_kaynak/web/05-sw-veri.jsx (+ 10-sw-ozellik.jsx,
 * 11-sw-fiyat.jsx, 15-sw-destek.jsx içindeki yerel diziler). Metinler TASARIM KARARIDIR ve birebir
 * taşınmıştır — kopya iyileştirmesi yapılmaz (bkz. _kaynak/OKU-BENI.md).
 *
 * NEDEN BLADE PARTIAL DEĞİL DE DÜZ PHP: Blade `@include` çağrılan görünümde tanımlanan değişkenleri
 * ÇAĞIRANA geri vermez; ortak içeriği tek yerde tutmanın yolu `require` ile dizi döndürmektir.
 * `php artisan view:cache` yalnız `*.blade.php` derler, bu dosyaya dokunmaz.
 *
 * SAYI YOK: fiyat, deneme süresi, kota gibi SUNUCU SAHİPLİ değerler burada SABİT YAZILMAZ. Dosya bir
 * closure döndürür; çağıran taraf güncel değerleri (PlanDeposu + EkPaketServisi) $d ile geçirir.
 *
 * TEMSİLİ (uydurma) kanıt/yorum verisi burada DEĞİL — bkz. _temsili-veri.php.
 *
 * TEK PLAN: "Kurumsal" diye bir plan `plans` tablosunda YOKTUR (tablo tek satırlıdır) ve satılmaz.
 * Tasarımdaki ikinci kart uydurma bir vitrindi — kaldırıldı (hesap panelindeki abonelik ekranı aynı
 * kararı zaten vermişti; site artık onunla tutarlı). Plan dizisi bilerek tek anahtarlıdır.
 *
 * @param array{deneme:int, kontor:int, kurye:int, ekKuryeTl:string, ekKuryeKisa:string,
 *              ekKuryeVar:bool, kunye:array<string,string>, bos:callable(?string):bool} $d
 */

return function (array $d): array {
    return [
        // ── Sektörler (hero şeridi) ──────────────────────────────
        'sektor' => ['Su bayii', 'Tüp bayii', 'Manav', 'Kuruyemişçi', 'Market', 'Fırın', 'Kırtasiye', 'Yem bayii', 'Halı yıkama'],

        // ── Kâğıt defterin maliyeti ──────────────────────────────
        'dert' => [
            ['ik' => 'defter', 't' => 'Defterde kalan alacak', 'a' => 'Kim ne kadar borçlu — sadece defteri tutanın kafasında. Biri izne çıkınca tahsilat durur.', 'c' => 'Her müşterinin bakiyesi, hareketi ve son ödemesi tek ekranda.'],
            ['ik' => 'cagri', 't' => 'Her aramada aynı üç soru', 'a' => '“Adınız? Adresiniz? Ne göndermiştik?” Müşteri her seferinde baştan anlatır.', 'c' => 'Telefon çaldığı anda ad, adres, geçmiş sipariş ve bakiye ekranda.'],
            ['ik' => 'para', 't' => 'Akşam tutmayan kasa', 'a' => 'Nakit, kart, veresiye birbirine karışır. Fark nereden çıktı, kimse bilmez.', 'c' => 'Gün sonunda üç kalem ayrı ayrı sayılır, fark anında görünür.'],
        ],

        /*
         * Ürün turu ekranları. `ekran` = x-site.telefon bileşenine geçilecek maket ekranı,
         * `cagri` = üstüne gelen çağrı kartı binsin mi (kaynaktaki TurBlm eşlemesi).
         */
        'tur' => [
            [
                'k' => 'cagri', 'ad' => 'Arayan tanıma', 'ik' => 'cagri', 'ekran' => 'ana', 'cagri' => true,
                'bas' => 'Telefon çalıyor. Kim aradığını zaten biliyorsunuz.',
                'a' => 'Numara rehberde varsa kart ekrana gelir: ad, kayıtlı adresler, açık borç, en son ne aldığı. Yoksa tek dokunuşla yeni müşteri açılır — numara hazır gelir.',
                'ozet' => ['Kayıtlı numara anında eşleşir', 'Borç ve son sipariş kartın üstünde', 'Kayıtsız numara için tek dokunuşla kayıt'],
            ],
            [
                'k' => 'veresiye', 'ad' => 'Veresiye defteri', 'ik' => 'defter', 'ekran' => 'musteri', 'cagri' => false,
                'bas' => 'Defter değil, bakiye. Herkes aynı rakamı görüyor.',
                'a' => 'Her müşterinin altında borç/alacak hareketi işler. Tahsilat girildiği anda bakiye düşer, kurye de ekranında görür.',
                'ozet' => ['Borç · alacak · temiz durumu renkle ayrılır', 'Tahsilat girildiği an bakiye güncellenir', 'Hareket geçmişi ödeme tipiyle saklanır'],
            ],
            [
                'k' => 'siparis', 'ad' => 'Sipariş akışı', 'ik' => 'fis', 'ekran' => 'siparis', 'cagri' => false,
                'bas' => 'Sipariş üç dokunuşta kaydolur.',
                'a' => 'Müşteri seç, ürünleri ekle, teslimatı ata. Serbest kalem gerekiyorsa açıklama yazıp tutar girin — katalog dışı iş de deftere düşer.',
                'ozet' => ['Katalogdan ya da barkodla ürün ekleme', 'Serbest kalem ve ek ücret satırı', 'Açık · teslim · iptal durumları'],
            ],
            [
                'k' => 'kurye', 'ad' => 'Kurye ve rota', 'ik' => 'kurye', 'ekran' => 'kurye', 'cagri' => false,
                'bas' => 'Kim nereye gidiyor, sıra ne — ekranda.',
                'a' => 'Siparişler kuryeye atanır. Konumu olan adresler için uygulama sırayı kendi kurar; sıralamayı elle de sürükleyebilirsiniz.',
                'ozet' => ['Kuryeye atama ve teslim onayı', 'Oto-sıralama ya da elle sürükleme', 'Konumsuz adres uyarısı'],
            ],
            [
                'k' => 'gunsonu', 'ad' => 'Gün sonu', 'ik' => 'para', 'ekran' => 'gunsonu', 'cagri' => false,
                'bas' => 'Akşam kasayı üç kalemde kapatın.',
                'a' => 'Nakit, kart ve veresiye ayrı ayrı toplanır. Sayılan nakdi girin, fark anında çıksın. Kapanan gün arşive düşer.',
                'ozet' => ['Nakit · kart · veresiye ayrımı', 'Sayım farkı anında hesaplanır', 'Kapanan günler arşivde saklanır'],
            ],
        ],

        // ── Kurulum adımları ─────────────────────────────────────
        'adim' => [
            ['n' => '01', 't' => 'Hesabınızı açın', 's' => '2 dakika', 'a' => 'İşletme adı ve telefon numarası yeter. Firma kodunuz bu ekranda üretilir — ekibiniz uygulamaya bu kodla girer.'],
            ['n' => '02', 't' => 'Müşterilerinizi aktarın', 's' => 'Aynı gün', 'a' => 'Rehberinizi ya da Excel listenizi gönderin, biz yükleyelim. Defterdeki açık bakiyeleri de birlikte aktarıyoruz.'],
            ['n' => '03', 't' => 'Telefonu bağlayın', 's' => '5 dakika', 'a' => 'Uygulamaya çağrı iznini verin. İlk çağrıda müşteri kartının ekrana geldiğini görün — kurulum bitti.'],
        ],

        // ── Güvenceler ───────────────────────────────────────────
        'guvence' => [
            ['ik' => 'cevrimdisi', 't' => 'İnternet gitse de çalışır', 'a' => 'Sipariş ve tahsilat cihazda tutulur, bağlantı gelince kendi senkronlanır.'],
            ['ik' => 'kalkan', 't' => 'Veriler Türkiye’de', 'a' => 'İstanbul’daki sunucularda, KVKK kapsamında.'],
            ['ik' => 'indir', 't' => 'Veriniz sizin', 'a' => 'Müşteri, sipariş ve defter kaydınızı istediğiniz an Excel olarak indirin.'],
            ['ik' => 'kulaklik', 't' => 'Telefonu insan açıyor', 'a' => 'Bot yok. Hafta içi 09:00–19:00 arası aynı ekip, aynı numara.'],
        ],

        /*
         * SSS. Deneme süresi cümlesi PlanDeposu::denemeGun()'den gelir (tasarımda 14 yazıyordu;
         * sunucu 30 gün veriyor — OKU-BENI çelişki tablosu: "site sunucuyla yalan söylemesin").
         * ÖDEME grubundaki "14 gün" ise CAYMA HAKKI süresidir (Mesafeli Sözleşmeler Yönetmeliği),
         * deneme süresi değil — bilinçli olarak 14 kaldı.
         */
        'sss' => [
            ['g' => 'Başlangıç', 'l' => [
                ['s' => 'Deneme için kart bilgisi istiyor musunuz?', 'c' => 'Hayır. '.$d['deneme'].' gün boyunca hiçbir ödeme bilgisi girmeden tüm özellikleri kullanırsınız. Süre dolduğunda uygulama salt-okunur kipe geçer, kaydınız silinmez.'],
                ['s' => 'Eski defterimdeki müşterileri nasıl aktarırım?', 'c' => 'Excel listesi ya da telefon rehberi olarak gönderin, biz yükleyelim — ücretsiz. Açık veresiye bakiyelerini de başlangıç bakiyesi olarak taşıyoruz.'],
                ['s' => 'Kaç kişi kullanabilir?', 'c' => 'İşletme sahibi + '.$d['kurye'].' kurye hesabı vardır. Ek kurye hesabı '.$d['ekKuryeTl'].'.'],
            ]],
            ['g' => 'Ödeme', 'l' => [
                ['s' => 'Hangi ödeme yöntemlerini kabul ediyorsunuz?', 'c' => 'Şu an havale/EFT ve elden ödeme alıyoruz. Kredi kartıyla online ödeme yakında açılacak; hazır olduğunda hesap panelinizden duyuracağız.'],
                ['s' => 'Fatura kesiyor musunuz?', 'c' => 'Evet. Her ödemede e-arşiv fatura düzenlenir ve hesap panelinizdeki Faturalar sayfasından PDF olarak indirilir.'],
                ['s' => 'İstediğim zaman iptal edebilir miyim?', 'c' => 'Evet, panelden tek tıkla. Dönem sonuna kadar erişiminiz devam eder, otomatik yenileme durur. Telefon etmenize gerek yok.'],
                ['s' => 'Yıllık ödedim, iade alabilir miyim?', 'c' => 'İlk 14 gün içinde koşulsuz iade. Sonrasında kullanılmayan aylar oranında iade yapılır.'],
            ]],
            ['g' => 'Teknik', 'l' => [
                ['s' => 'İnternet kesilirse ne olur?', 'c' => 'Uygulama çevrimdışı çalışmaya devam eder. Sipariş, tahsilat ve düzenlemeler cihazda tutulur; bağlantı gelince otomatik senkronlanır.'],
                ['s' => 'Arayan tanıma nasıl çalışıyor?', 'c' => 'Uygulama çağrı bilgisi iznini kullanarak gelen numarayı kendi müşteri listenizle eşleştirir. Numaralar cihazın dışına çıkmaz, üçüncü tarafla paylaşılmaz.'],
                ['s' => 'iPhone’da çalışıyor mu?', 'c' => 'Android’de tam sürüm. iOS’ta arayan tanıma dışındaki tüm özellikler çalışır; iOS çağrı entegrasyonu üzerinde çalışıyoruz.'],
                ['s' => 'Verilerim nerede duruyor?', 'c' => 'İstanbul’daki sunucularda, KVKK kapsamında. Verileriniz Türkiye dışına çıkmaz.'],
            ]],
        ],

        // ── Planlar (FİYAT YOK — fiyat PlanDeposu'dan, kartın içinde) ─
        'plan' => [
            'sipario' => [
                'ad' => 'Sipario',
                'ozet' => 'Tek plan, tek fiyat. Tezgâhın arkasındaki her şey içinde.',
                'cta' => $d['deneme'].' gün ücretsiz dene',
                'ctaAlt' => 'Kart istemiyoruz',
                'kapsam' => [
                    ['t' => 'Sınırsız müşteri ve sipariş', 'a' => 'Kayıt sayısına göre ücret almıyoruz'],
                    ['t' => 'Arayan tanıma', 'a' => 'Telefon çaldığı anda kart ekrana gelir'],
                    ['t' => 'Veresiye defteri', 'a' => 'Bakiye, tahsilat, hareket geçmişi'],
                    ['t' => 'Gün sonu kasa', 'a' => 'Nakit · kart · veresiye ayrımıyla devir'],
                    ['t' => $d['kurye'].' kurye hesabı', 'a' => 'Ek kurye '.$d['ekKuryeTl']],
                    ['t' => 'Ayda '.$d['kontor'].' oto-sıralama hakkı', 'a' => 'Rota sırasını uygulama kurar'],
                    ['t' => 'Ürün kataloğu ve barkod', 'a' => 'Fotoğraflı, birimli, çok fiyatlı'],
                    ['t' => 'Telefon + WhatsApp destek', 'a' => 'Hafta içi 09:00–19:00, gerçek insan'],
                ],
            ],
        ],

        /*
         * Plan detay tablosu. Eskiden "Sipario / Kurumsal" iki sütunluydu; Kurumsal satılmadığı için
         * karşılaştıracak ikinci plan kalmadı — tablo TEK DEĞER SÜTUNUNA indi ve "planda ne var"
         * sorusunu yanıtlıyor. Yalnız Kurumsal'ı ayırt etmek için duran satırlar (rol yönetimi,
         * e-Fatura aktarımı, kendi sunucunuzda kurulum, şube sayısı) kaldırıldı: hiçbiri satılan
         * üründe yok ve karşısında yükseltilecek bir plan da yok.
         *
         * Ek kurye parantezi yalnız KATALOGDA paket varken basılır — yoksa fiyat uydurulmaz.
         */
        'karsilastir' => [
            ['g' => 'Kullanım', 's' => [
                ['Müşteri ve sipariş', 'Sınırsız'],
                ['Kurye hesabı', $d['kurye'].($d['ekKuryeVar'] ? ' (ek hesap '.$d['ekKuryeKisa'].')' : '')],
                ['Oto-sıralama hakkı', $d['kontor'].' / ay'],
            ]],
            ['g' => 'Özellikler', 's' => [
                ['Arayan tanıma', true],
                ['Veresiye defteri', true],
                ['Gün sonu kasa devri', true],
                ['Çevrimdışı çalışma', true],
            ]],
            ['g' => 'Destek', 's' => [
                ['Telefon + WhatsApp', 'Hafta içi 09–19'],
                ['Yanıt süresi', 'Aynı gün'],
                ['Kurulum', 'Uzaktan, ücretsiz'],
            ]],
        ],

        // ── Ödeme güvencesi (11-sw-fiyat.jsx · OdemeGuvenBlm) ────
        'odemeGuven' => [
            ['ik' => 'para', 't' => 'Havale / EFT', 'a' => 'Banka havalesiyle ödeyin; dekont ulaştığı gün hesabınız açılır. IBAN ve referans kodu ödeme adımında çıkar.'],
            ['ik' => 'elpara', 't' => 'Elden ödeme', 'a' => 'Bölgenizdeyse uğrayıp elden alıyoruz. Makbuzu yerinde veriyoruz, hesap aynı gün açılıyor.'],
            ['ik' => 'kart', 't' => 'Kartla ödeme yakında', 'a' => 'Kredi ve banka kartıyla online ödeme üzerinde çalışıyoruz. Açıldığında panelinizden duyuracağız.'],
            ['ik' => 'geri', 't' => '14 gün koşulsuz iade', 'a' => 'İlk iki hafta içinde vazgeçerseniz tutarın tamamı iade edilir. Sebep sormuyoruz.'],
        ],

        // ── Ek özellikler (10-sw-ozellik.jsx · SW_EK) ────────────
        'ek' => [
            ['ik' => 'elpara', 't' => 'Muaf müşteriler', 'a' => 'Ücret almadığınız kişiler listede işaretlenir; siparişleri sıfır tutarla deftere düşer, ciroyu bozmaz.'],
            ['ik' => 'barkod', 't' => 'Barkodla ürün ekleme', 'a' => 'Kamerayla okutun, ürün sepete düşsün. Barkodu olmayan kalem için serbest satır açın.'],
            ['ik' => 'pin', 't' => 'Çoklu adres ve konum', 'a' => 'Bir müşterinin evi, dükkânı, deposu ayrı adres olarak durur. Konum kaydedilirse rota sırasına girer.'],
            ['ik' => 'fis', 't' => 'Serbest kalem', 'a' => 'Katalogda olmayan iş için açıklama yazıp tutar girin — merdiven çıkışı, montaj, iade farkı.'],
            ['ik' => 'takvim', 't' => 'Gün arşivi', 'a' => 'Kapanan her gün ciro, kasa farkı ve sipariş sayısıyla saklanır. Geriye dönüp bakabilirsiniz.'],
            ['ik' => 'kurye', 't' => 'Kurye görünümü', 'a' => 'Kurye hesabı sadece kendi teslimatlarını görür. Fiyat listesi, defter ve ayarlar ona kapalıdır.'],
            ['ik' => 'cevrimdisi', 't' => 'Çevrimdışı kip', 'a' => 'Sinyal yoksa kayıt cihazda tutulur, bağlantı gelince sıraya girer. Hiçbir sipariş kaybolmaz.'],
            // 'ay' takma adı ikon haritasında YOK — kaynakta da yoktu, bileşen nötr çember çizer (kasıtlı).
            ['ik' => 'ay', 't' => 'Koyu tema', 'a' => 'Akşam saatlerinde ekran yormasın diye. Sistem ayarını takip eder ya da elle sabitlenir.'],
        ],

        // ── "Bir gün" anlatısı (10-sw-ozellik.jsx · SW_GUN) ──────
        'gun' => [
            ['s' => '08:10', 't' => 'Gün açılır', 'a' => 'Dünden devreden kasa girilir. Açık siparişler ekranın üstünde.'],
            ['s' => '09:24', 't' => 'Telefon çalar', 'a' => 'Ahmet Yılmaz. Kart açılır: adres hazır, 8.550 ₺ borcu var, geçen sefer 2 damacana almış.'],
            ['s' => '09:25', 't' => 'Sipariş girilir', 'a' => 'Karttan “Sipariş oluştur”. Ürün seçilir, kuryeye atanır. Üç dokunuş.'],
            ['s' => '11:40', 't' => 'Kurye teslim eder', 'a' => 'Kurye kendi telefonundan teslim işaretler, nakit tahsilatı girer. Bakiye anında düşer.'],
            ['s' => '19:05', 't' => 'Gün kapanır', 'a' => 'Nakit sayılır, fark kontrol edilir, gün arşive düşer. Yarın sıfırdan başlar.'],
        ],

        /*
         * Destek kanalları. Değerler config('subscription.company')'den gelir — tasarımın
         * "0850 000 00 00" / "destek@sipario.com.tr" örnek verisi KULLANILMADI.
         *
         * `href` yalnız değer GERÇEKse dolar ($d['bos'] köşeli parantezli config varsayılanını yer
         * tutucu sayar). Yer tutucunun üzerine tel:/mailto: basmak, tıklanınca hiçbir yere gitmeyen
         * bir bağlantı üretirdi.
         *
         * WhatsApp'ın config karşılığı yok (company bloğunda böyle bir anahtar bulunmuyor), o yüzden
         * elle yer tutucu — gerçek numara netleşince config'e bir anahtar eklenip buraya bağlanmalı.
         *
         * Tasarımdaki "sırada ortalama 40 saniye" ölçüm iddiası ÇIKARILDI: ürün pilot aşamasında,
         * böyle bir ölçüm yok (SW_KANIT ile aynı gerekçe).
         *
         * YER TUTUCU OLAN KANAL HİÇ BASILMAZ (2026-08-05): eskiden yer tutucu bağlantısız düz metin
         * olarak ekranda kalıyordu, yani ziyaretçi "[Telefon]" yazan bir iletişim kutusu görüyordu.
         * Aşağıdaki `array_values(array_filter(...))` gerçek değeri olmayan kanalı listeden düşürür;
         * gerçek numara/adres config'e girdiği gün kanal kendiliğinden geri gelir. Alt bilgideki
         * künye kutularında da aynı ilke uygulandı.
         */
        'kanal' => array_values(array_filter([
            [
                'ik' => 'telefon', 't' => 'Telefon', 'dg' => 'Ara',
                'deger' => $d['kunye']['phone'] ?? '[Telefon]',
                'href' => $d['bos']($d['kunye']['phone'] ?? null) ? null : 'tel:'.preg_replace('/\s+/', '', $d['kunye']['phone']),
                'a' => $d['kunye']['hours'] ?? 'Hafta içi 09:00 – 19:00',
            ],
            [
                'ik' => 'sohbet', 't' => 'WhatsApp', 'dg' => 'Yaz',
                'deger' => '[WhatsApp numarası]', 'href' => null,
                'a' => 'Ekran görüntüsü gönderin, birlikte bakalım',
            ],
            [
                'ik' => 'posta', 't' => 'E-posta', 'dg' => 'Gönder',
                'deger' => $d['kunye']['support_email'] ?? '[destek e-postası]',
                'href' => $d['bos']($d['kunye']['support_email'] ?? null) ? null : 'mailto:'.$d['kunye']['support_email'],
                'a' => 'Aynı gün içinde yanıt · gece gelenler sabah',
            ],
        ], fn (array $k): bool => ! $d['bos']($k['deger']))),

        /*
         * İletişim formunun gideceği adres — config('subscription.company.support_email').
         * Yer tutucu (köşeli parantezli) olduğu sürece null döner; o durumda "Gönder" düğmesi PASİF
         * kalır ve altında gerekçesi yazar — sahte "gönderildi" ekranı GÖSTERİLMEZ. Gerçek adres
         * girildiğinde düğme kendiliğinden mailto: ile canlanır (site/parca/iletisim-form.blade.php).
         */
        'destekEposta' => $d['bos']($d['kunye']['support_email'] ?? null) ? null : $d['kunye']['support_email'],
    ];
};
