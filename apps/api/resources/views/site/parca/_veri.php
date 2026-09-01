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

        /*
         * ── Kâğıt defterin maliyeti ─────────────────────────────────────────────────────
         * 2026-08-19 metin elden geçti. Değişen şey bilgi değil, SES: cümleler reklam
         * ritmine göre kurulmuştu (kısa-vurucu-kesik), esnafın konuştuğu gibi değil.
         * "Her aramada aynı üç soru" gibi bir başlık akıllıca ama soğuk; "Aynı soruları
         * her seferinde baştan sormak" olanı anlatıyor. Sahadaki gerçek dile yaklaştırıldı.
         */
        'dert' => [
            ['ik' => 'defter', 't' => 'Alacak defterde kalıyor', 'a' => 'Kimin ne kadar borcu olduğunu bir tek defteri tutan biliyor. O kişi izne çıktığında tahsilat da izne çıkıyor.', 'c' => 'Her müşterinin borcu, hareketi ve en son ne zaman ödediği tek ekranda.'],
            ['ik' => 'cagri', 't' => 'Aynı soruları her gün baştan soruyorsunuz', 'a' => '“Adınız neydi? Adres neresiydi? Geçen sefer ne göndermiştik?” Müşteri her aramada kendini yeniden anlatıyor.', 'c' => 'Telefon çaldığı anda adı, adresi, son siparişi ve borcu ekranda.'],
            ['ik' => 'para', 't' => 'Akşam kasa tutmuyor', 'a' => 'Nakit, kart ve veresiye gün içinde birbirine karışıyor. Akşam bir fark çıkıyor ama nereden çıktığını kimse bilmiyor.', 'c' => 'Gün sonunda üç kalem ayrı ayrı sayılıyor; fark varsa nerede olduğu görünüyor.'],
        ],

        /*
         * Ürün turu ekranları. `ekran` = x-site.telefon bileşenine geçilecek maket ekranı,
         * `cagri` = üstüne gelen çağrı kartı binsin mi (kaynaktaki TurBlm eşlemesi).
         */
        'tur' => [
            [
                'k' => 'cagri', 'ad' => 'Arayan tanıma', 'ik' => 'cagri', 'ekran' => 'ana', 'cagri' => true,
                'bas' => 'Telefon çalıyor ve kimin aradığını zaten biliyorsunuz.',
                'a' => 'Numara listenizde kayıtlıysa kartı ekrana geliyor: adı, kayıtlı adresleri, açık borcu, en son ne aldığı. Kayıtlı değilse tek dokunuşla yeni müşteri açıyorsunuz, numara hazır geliyor.',
                'ozet' => ['Kayıtlı numara anında eşleşiyor', 'Borcu ve son siparişi kartın üstünde', 'Yeni numara için tek dokunuşla kayıt'],
            ],
            [
                'k' => 'veresiye', 'ad' => 'Veresiye defteri', 'ik' => 'defter', 'ekran' => 'musteri', 'cagri' => false,
                'bas' => 'Borcu herkes aynı yerden, aynı rakamla görüyor.',
                'a' => 'Her müşterinin altında borç ve ödeme hareketi işliyor. Kurye tahsilatı girdiği anda borç düşüyor; siz de aynı rakamı görüyorsunuz, akşamı beklemiyorsunuz.',
                'ozet' => ['Borçlu, alacaklı ve temiz müşteri renkten ayrılıyor', 'Tahsilat girildiği an borç güncelleniyor', 'Hangi ödemenin nasıl alındığı kayıtta duruyor'],
            ],
            [
                'k' => 'siparis', 'ad' => 'Sipariş akışı', 'ik' => 'fis', 'ekran' => 'siparis', 'cagri' => false,
                'bas' => 'Müşteri hâlâ telefondayken sipariş kaydedilmiş oluyor.',
                'a' => 'Müşteriyi seçiyorsunuz, ürünleri ekliyorsunuz, kuryeye atıyorsunuz. Katalogda olmayan bir iş varsa açıklamasını yazıp tutarını giriyorsunuz — o da deftere düşüyor.',
                'ozet' => ['Katalogdan ya da barkod okutarak ürün ekleme', 'Katalog dışı iş için serbest satır', 'Açık, teslim edildi, iptal — hepsi ayrı görünüyor'],
            ],
            [
                'k' => 'kurye', 'ad' => 'Kurye ve rota', 'ik' => 'kurye', 'ekran' => 'kurye', 'cagri' => false,
                'bas' => 'Hangi kurye nereye gidiyor, sırası ne — bakınca görüyorsunuz.',
                'a' => 'Siparişleri kuryeye atıyorsunuz. Konumu kayıtlı adresler için sırayı uygulama kuruyor; beğenmezseniz parmağınızla sürükleyip kendiniz diziyorsunuz.',
                'ozet' => ['Kuryeye atama ve teslim onayı', 'Sırayı uygulama kuruyor ya da siz diziyorsunuz', 'Konumu olmayan adres uyarı veriyor'],
            ],
            [
                'k' => 'gunsonu', 'ad' => 'Gün sonu', 'ik' => 'para', 'ekran' => 'gunsonu', 'cagri' => false,
                'bas' => 'Akşam kasayı üç kalemde kapatıyorsunuz.',
                'a' => 'Nakit, kart ve veresiye ayrı ayrı toplanıyor. Elinizde saydığınız parayı giriyorsunuz, fark varsa hemen çıkıyor. Kapanan gün arşive düşüyor, sonra dönüp bakabiliyorsunuz.',
                'ozet' => ['Nakit, kart ve veresiye ayrı toplanıyor', 'Saydığınız parayla arasındaki fark anında çıkıyor', 'Kapanan günler arşivde duruyor'],
            ],
        ],

        /*
         * ── Kurulum adımları ────────────────────────────────────────────────────────────
         * ⚠️ 1. ADIMDA YANLIŞ BİLGİ VARDI (2026-08-19). Metin "İşletme adı ve telefon numarası
         * yeter" diyordu; kayıt formu (livewire/site/register.blade.php · adım 0) TELEFON
         * SORMUYOR, işletme adı ve E-POSTA istiyor. Yani site, formu doldurmaya gelen esnafa
         * yanlış hazırlık yaptırıyordu — küçük bir hata ama tam da "kurulum kolay" vaadinin
         * altını oyan türden: söylenenle görülen tutmayınca ilk izlenim bozulur.
         *
         * "Telefonu bağlayın" başlığı da netleşti: bağlanan bir şey yok, verilen bir izin var.
         */
        'adim' => [
            ['n' => '01', 't' => 'Hesabınızı açın', 's' => '2 dakika', 'a' => 'İşletme adınız ve bir e-posta adresi yeter. Firma kodunuz bu ekranda çıkar — ekibiniz uygulamaya o kodla girecek.'],
            ['n' => '02', 't' => 'Müşterilerinizi bize gönderin', 's' => 'Aynı gün', 'a' => 'Telefon rehberi, Excel listesi ya da defterin fotoğrafı — nasıl duruyorsa gönderin, biz gireriz. Açık borçları da birlikte taşıyoruz.'],
            ['n' => '03', 't' => 'Çağrı iznini verin', 's' => '5 dakika', 'a' => 'Uygulama bir kez izin isteyecek. İzni verdiğinizde ilk gelen aramada müşteri kartı ekranınıza gelir — kurulum bitmiş olur.'],
        ],

        /*
         * ── Güvenceler ──────────────────────────────────────────────────────────────────
         * ⚠️ "VERİLER TÜRKİYE'DE" KARTI KALDIRILDI (2026-09-01, kullanıcı kararı + ölçüm).
         * Sunucu ölçüldü: Hostinger, Frankfurt / Almanya (`srv1577146.hstgr.cloud`, AS47583).
         * Yani kart doğru değildi. BRIEF md.4'teki "veri Türkiye'de" kırmızı çizgisi kullanıcı
         * tarafından açıkça kaldırıldı (gerekçe: Türkiye'de sunucu maliyeti). Yerine gelen kart
         * BİLİNENİ söylüyor: nerede durduğunu, kimin göremediğini, satılmadığını.
         *
         * Bu bir kopya tercihi değil, doğruluk sorunudur: aynı sitede yayımlanan aydınlatma
         * metni barındırmayı yurt dışı aktarım olarak sayarken, ana sayfanın "Türkiye'de" demesi
         * iki metinden birini yalancı çıkarırdı.
         *
         * "Telefonu insan açıyor" da düştü: künyede gerçek bir telefon numarası YOK, kanal
         * listesi onu zaten süzüyor (aşağıda) — sayfanın telefon vaat edip destek sayfasında
         * telefon göstermemesi aynı türden bir çelişkiydi.
         */
        'guvence' => [
            ['ik' => 'cevrimdisi', 't' => 'İnternet gitse de çalışır', 'a' => 'Sipariş ve tahsilat telefonda tutulur, bağlantı gelince kendi kendine yerine oturur.'],
            ['ik' => 'kalkan', 't' => 'Defteriniz size özel', 'a' => 'Her işletmenin verisi veritabanı düzeyinde ayrıdır. Satılmaz, reklama verilmez, yapay zekâ eğitiminde kullanılmaz.'],
            ['ik' => 'indir', 't' => 'Veriniz sizin', 'a' => 'Müşteri, sipariş ve defter kaydınızı isteyin, Excel olarak gönderelim. Abonelik bitse de bu kapı açık.'],
            ['ik' => 'kulaklik', 't' => 'Cevabı insan yazıyor', 'a' => 'Hafta içi 09:00–19:00 arası aynı ekip. Otomatik yanıt yollamıyoruz.'],
        ],

        /*
         * SSS. Deneme süresi cümlesi PlanDeposu::denemeGun()'den gelir (tasarımda 14 yazıyordu;
         * sunucu 30 gün veriyor — OKU-BENI çelişki tablosu: "site sunucuyla yalan söylemesin").
         * ÖDEME grubundaki "14 gün" ise CAYMA HAKKI süresidir (Mesafeli Sözleşmeler Yönetmeliği),
         * deneme süresi değil — bilinçli olarak 14 kaldı.
         */
        /*
         * ── SSS'TE ÜÇ DÜZELTME (2026-08-19), üçü de ÜRÜNE UYMAYAN CÜMLELERDİ ─────────────
         *
         * 1. "salt-okunur kipe geçer" → esnaf sözlüğü değil, yazılımcı sözlüğü. Aynı şeyi
         *    kullanıcının gördüğü davranışla anlatıyoruz: yeni kayıt girilemez, eskiler durur.
         *
         * 2. "İstediğim zaman iptal edebilir miyim? → Evet, panelden tek tıkla." Bu CÜMLE
         *    YANLIŞTI: hesap panelinde iptal düğmesi YOK ve olmaması bilinçli bir karar
         *    (livewire/site/hesap/abonelik.blade.php · sapma 3 — `Cancelled` yazmak yazmayı
         *    ANINDA kapatır, oysa ekranın vaadi "dönem sonuna kadar hiçbir şey değişmez").
         *    Yani site, panelde bulunmayan bir düğmeyi tarif ediyordu; bayi arar, bulamaz.
         *    Gerçek cevap: otomatik yenileme zaten yok, iptal için bir şey yapmak gerekmiyor.
         *
         * 3. "Fatura … PDF olarak indirilir" → panelde Faturalar bölümü ödeme GEÇMİŞİNİ
         *    listeliyor, PDF indirme düğmesi yok (e-arşiv faturası e-posta ile gidiyor).
         *    Cevap, gerçekte olan yola çevrildi.
         */
        'sss' => [
            ['g' => 'Başlangıç', 'l' => [
                ['s' => 'Deneme için kart bilgisi istiyor musunuz?', 'c' => 'Hayır. '.$d['deneme'].' gün boyunca hiçbir ödeme bilgisi vermeden her şeyi kullanırsınız. Süre dolunca yeni kayıt girilemez; girdikleriniz olduğu gibi durur ve abone olduğunuz gün geri gelir.'],
                ['s' => 'Eski defterimdeki müşterileri nasıl aktarırım?', 'c' => 'Excel listesi, telefon rehberi, hatta defterin fotoğrafı — nasıl duruyorsa öyle gönderin, biz gireriz. Ücret almıyoruz. Açık veresiye bakiyelerini de başlangıç borcu olarak taşıyoruz.'],
                ['s' => 'Kaç kişi kullanabilir?', 'c' => 'İşletme sahibi + '.$d['kurye'].' kurye hesabı. Daha fazla kuryeniz varsa ek hesap '.$d['ekKuryeTl'].'.'],
                ['s' => 'Kurmak zor mu, birinin gelmesi gerekiyor mu?', 'c' => 'Kimsenin gelmesi gerekmiyor. Uygulamayı indirip firma kodunuzla giriyorsunuz; çağrı iznini verdiğiniz an arayan tanıma çalışmaya başlıyor. Takılırsanız telefonla birlikte kuruyoruz, o da ücretsiz.'],
            ]],
            ['g' => 'Ödeme', 'l' => [
                ['s' => 'Hangi ödeme yöntemlerini kabul ediyorsunuz?', 'c' => 'Şimdilik havale/EFT ve elden ödeme. Kartla online ödeme üzerinde çalışıyoruz; açıldığında hesap panelinizde göreceksiniz.'],
                ['s' => 'Fatura kesiyor musunuz?', 'c' => 'Evet, her ödeme için e-arşiv fatura düzenleyip e-posta ile gönderiyoruz. Ödeme geçmişinizin tamamı hesap panelinizdeki Faturalar bölümünde duruyor.'],
                /*
                 * ── İADE VAADİ KALDIRILDI (2026-09-01, kullanıcı kararı) ────────────────
                 * "İptal ve iade diye bir şey yok zaten 30 günlük deneme süresi var." Eski iki
                 * cevap ("kalan ayları iade ediyoruz" · "ilk 14 gün koşulsuz iade") bir SATIŞ
                 * TAAHHÜDÜYDÜ ve artık verilmiyor. Yerine geçen mantık daha dürüst: parayı
                 * denemeden ödemiyorsunuz — karar noktası ödemeden ÖNCE, deneme süresinde.
                 *
                 * İptal sorusunun cevabı DEĞİŞMEDİ ve bu önemli: iptal etmek için bir şey
                 * yapmak zaten gerekmiyor (otomatik yenileme yok). Değişen tek şey, ödenmiş
                 * dönemin geri alınmaması.
                 */
                ['s' => 'İstediğim zaman bırakabilir miyim?', 'c' => 'Evet ve bunun için bir şey yapmanız gerekmiyor: otomatik yenileme diye bir şey yok, kartınızdan kendiliğinden para çekilmez. Ödemezseniz dönem sonunda hesap yeni kayıt almayı durdurur, o kadar. Kayıtlarınız silinmez.'],
                ['s' => 'Ödedikten sonra vazgeçersem param geri gelir mi?', 'c' => 'Ödenmiş dönem için iade yapmıyoruz. Bunun yerine '.$d['deneme'].' gün ücretsiz deneme var: kart bilgisi vermeden, tam sürümle, kendi müşterilerinizle deniyorsunuz. Ödeme kararını ancak ürünü gördükten sonra veriyorsunuz.'],
                ['s' => 'Fiyat sonradan artar mı?', 'c' => 'Ödediğiniz dönemin fiyatı sabittir, dönem ortasında değişmez. Yeni dönemde fiyat değişecekse en az 30 gün önce haber veriyoruz — sürpriz zam yok.'],
            ]],
            /*
             * ── "VERİLERİM NEREDE DURUYOR?" CEVABI DÜZELTİLDİ (2026-08-19) ───────────────
             * Eski cevap "Verileriniz Türkiye dışına çıkmaz" diyordu. Bu cümle YANLIŞTI ve
             * yanlışlığı hukuk metinleri yazılırken koda bakınca çıktı:
             *   • Adres arama, aranan adres metnini Yandex/Google'a yolluyor (config/geocoding.php)
             *   • Rota sıralama, durak koordinatlarını Google Routes'a yolluyor (config/rota.php)
             *   • Anlık bildirim, cihaz jetonunu Google FCM'e yolluyor (app/Bildirim/FcmIstemcisi.php)
             *   • Bu vardiyada siteye Google Analytics eklendi (rızaya bağlı)
             * ⚠️ 2026-09-01 GÜNCELLEMESİ: o gün "SAKLAMA Türkiye'de" diye yazılan cümle de
             * yanlıştı — sunucu ölçüldü, Hostinger/Frankfurt. Cevap artık gerçek ülkeyi söylüyor.
             * Ama "saklama" ile "aktarım" hâlâ ayrı iki şey ve ziyaretçiye ikisini birbirine
             * karıştıran bir cümle kurulamaz; aynı sitede yayımlanan aydınlatma metni her çıkışı
             * tek tek sayarken SSS'in tersini söylemesi, iki metinden birini yalancı çıkarırdı.
             *
             * Yeni cevap ne gittiğini VE ne gitmediğini söylüyor — ikincisi olmadan cümle
             * ziyaretçiyi gereksiz yere ürkütürdü, çünkü müşteri adı ve borcu gerçekten hiçbir
             * çağrıda yer almıyor (ölçüldü).
             */
            ['g' => 'Teknik', 'l' => [
                ['s' => 'İnternet kesilirse ne olur?', 'c' => 'Uygulama çalışmaya devam eder. Sipariş, tahsilat ve düzeltmeler telefonda birikir; bağlantı gelince kendi kendine sunucuya geçer. Kurye bodrumda da teslim kapatır.'],
                ['s' => 'Arayan tanıma nasıl çalışıyor?', 'c' => 'Gelen numara telefonun kendi içinde, sizin müşteri listenizle eşleştirilir. Numara bu iş için sunucuya ya da üçüncü bir tarafa gönderilmez.'],
                ['s' => 'iPhone’da çalışıyor mu?', 'c' => 'Android’de her şey var. iPhone’da arayan tanıma dışındaki tüm özellikler çalışıyor — iOS işletim sistemi uygulamaların gelen çağrıyı görmesine izin vermiyor, bu bizim eksiğimiz değil Apple’ın kuralı.'],
                /*
                 * CEVAP KISALTILDI (2026-08-19). Önceki hâli beş cümleydi ve "durak
                 * koordinatları", "harita servisi", "KVKK aydınlatma metni" gibi ifadelerle
                 * SSS'in en uzun, en teknik maddesiydi. Sık sorulan bir sorunun cevabı
                 * okunacak kadar kısa olmalı; ayrıntı, ayrıntıyı arayanın gideceği yerde
                 * (aydınlatma metni) zaten var ve oradaki tablo her çıkışı tek tek sayıyor.
                 * Buradaki iş, esnafın gerçekten sorduğu şeyi cevaplamak: "verim bende kalır mı".
                 */
                ['s' => 'Verilerim nerede duruyor?', 'c' => 'Müşteri listeniz, siparişleriniz ve defteriniz Almanya’daki (Frankfurt) sunucularımızda saklanır ve KVKK kapsamında işlenir. Her işletmenin verisi veritabanı düzeyinde ayrıdır; biz de iş verinizi değiştiremeyiz. Adres ararken ve kurye yolunu sıralarken yalnız adres metni harita servisine gider — müşterinizin adı, telefonu ve borcu hiçbir çağrıda yer almaz.'],
            ]],
        ],

        // ── Planlar (FİYAT YOK — fiyat PlanDeposu'dan, kartın içinde) ─
        'plan' => [
            'sipario' => [
                'ad' => 'Sipario',
                /*
                 * Kartın özeti "Tek plan, tek fiyat. Tezgâhın arkasındaki her şey içinde."ydi
                 * ve bölüm başlığı da (ana-fiyat-ozet.blade.php) "Tek plan, tek fiyat." diyor —
                 * aynı cümle üst üste iki kez okunuyordu. Kart artık başlığı tekrar etmiyor,
                 * onun bıraktığı yerden devam ediyor.
                 */
                'ozet' => 'Tezgâhın arkasında ne yapıyorsanız hepsi içinde.',
                'cta' => $d['deneme'].' gün ücretsiz dene',
                'ctaAlt' => 'Kart istemiyoruz',
                'kapsam' => [
                    ['t' => 'Sınırsız müşteri ve sipariş', 'a' => 'Kayıt sayısına göre ücret almıyoruz'],
                    ['t' => 'Arayan tanıma', 'a' => 'Telefon çaldığı anda kart ekrana gelir'],
                    ['t' => 'Veresiye defteri', 'a' => 'Bakiye, tahsilat, hareket geçmişi'],
                    ['t' => 'Gün sonu kasa', 'a' => 'Nakit · kart · veresiye ayrımıyla devir'],
                    /*
                     * `k` anahtarı bir GÖRÜNÜM KANCASIDIR (2026-09-01): plan levhası bu satırı
                     * tanısın ve ek kurye paketlerini bir İPUCU olarak buraya gömsün diye var
                     * (bkz. components/site/plan-yatay.blade.php). Satırın metnini "kurye" diye
                     * ARAMAK da işe yarardı ama metin bir kopya kararıdır ve yarın değişebilir;
                     * anahtar sözleşmedir.
                     *
                     * Alt satır katalogda paket VARKEN boş: fiyat artık ipucunun içinde ve iki
                     * yerde iki kez yazmak, tam da kullanıcının "gereksiz" dediği tekrardı.
                     * Katalog boşsa ipucu hiç kurulmaz — o zaman alt satır bilgiyi taşıyor.
                     */
                    ['t' => $d['kurye'].' kurye hesabı', 'a' => $d['ekKuryeVar'] ? null : 'Ek kurye '.$d['ekKuryeTl'], 'k' => 'kurye'],
                    /*
                     * "Ayda 50 oto-sıralama hakkı" SATIRI DEĞİŞTİ (2026-08-19). Fiyat kartındaki
                     * sekiz satır içinde en anlaşılmazı buydu: "oto-sıralama" bizim iç adımız,
                     * "hak" ise ne olduğu belirsiz bir birim. Tezgâhın arkasındaki adam bu satırı
                     * okuyup ne aldığını bilemiyordu — üstelik satır bir ÖZELLİK listesinde, yani
                     * tam da "ne alıyorum" sorusunun cevaplandığı yerde duruyor.
                     * Yeni satır işi tarif ediyor; sayı alt satırda kaldı.
                     */
                    ['t' => 'Kuryenin yolunu uygulama sıralasın', 'a' => 'Ayda '.$d['kontor'].' kez'],
                    ['t' => 'Ürün kataloğu ve barkod', 'a' => 'Fotoğraflı, birimli, çok fiyatlı'],
                    // Künyede gerçek telefon/WhatsApp numarası olmadığı sürece burada da vaat
                    // edilmez — destek sayfası o kanalları basmıyor (2026-09-01).
                    ['t' => 'Gerçek insandan destek', 'a' => 'Hafta içi 09:00–19:00, aynı gün yanıt'],
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
                ['Kurye yolunu otomatik sıralama', $d['kontor'].' kez / ay'],
            ]],
            ['g' => 'Özellikler', 's' => [
                ['Arayan tanıma', true],
                ['Veresiye defteri', true],
                ['Gün sonu kasa devri', true],
                ['Çevrimdışı çalışma', true],
            ]],
            ['g' => 'Destek', 's' => [
                ['Destek kanalı', 'E-posta'],
                ['Yanıt süresi', 'Aynı gün'],
                ['Kurulum', 'Uzaktan, ücretsiz'],
                ['Müşteri listesi aktarımı', 'Biz giriyoruz, ücretsiz'],
            ]],
        ],

        // ── Ödeme güvencesi (11-sw-fiyat.jsx · OdemeGuvenBlm) ────
        'odemeGuven' => [
            ['ik' => 'para', 't' => 'Havale / EFT', 'a' => 'Banka havalesiyle ödeyin; dekont ulaştığı gün hesabınız açılır. IBAN ve referans kodu ödeme adımında çıkar.'],
            ['ik' => 'elpara', 't' => 'Elden ödeme', 'a' => 'Bölgenizdeyse uğrayıp elden alıyoruz. Makbuzu yerinde veriyoruz, hesap aynı gün açılıyor.'],
            ['ik' => 'kart', 't' => 'Kartla ödeme yakında', 'a' => 'Kredi ve banka kartıyla online ödeme üzerinde çalışıyoruz. Açıldığında panelinizden duyuracağız.'],
            // "14 gün koşulsuz iade" kartı kaldırıldı (2026-09-01): iade taahhüdü verilmiyor.
            // Yerine geçen güvence ÖDEMEDEN ÖNCE duruyor — deneme süresi ve otomatik yenilemenin
            // yokluğu. Bir riski geri ödemeyle değil, hiç aldırmayarak kaldırıyoruz.
            ['ik' => 'geri', 't' => 'Önce deneyin, sonra ödeyin', 'a' => $d['deneme'].' gün ücretsiz, kart bilgisi istemeden. Otomatik yenileme yok; ödemeyi her dönem siz başlatırsınız.'],
        ],

        /*
         * ── Ek özellikler (10-sw-ozellik.jsx · SW_EK) ───────────────────────────────────
         * SEKİZ KART → BEŞ (2026-08-19). Çıkarılan üçü ve gerekçeleri:
         *
         *  • "Çevrimdışı kip" — ana sayfadaki güvence kartlarında ("İnternet gitse de çalışır")
         *    ve SSS'te ("İnternet kesilirse ne olur?") zaten iki kez anlatılıyor. Üçüncü kez,
         *    üstelik "kip" gibi bir kelimeyle.
         *  • "Koyu tema" — bir SATIN ALMA kararına etki etmeyen tek kart buydu. Su bayii
         *    "koyu tema var mı" diye sorup almıyor; listede yer kaplayıp gerçekten önemli
         *    kartların dikkatini çalıyordu.
         *  • "Serbest kalem" — hemen üstündeki "Sipariş akışı" bölümü aynı şeyi aynı örnekle
         *    ("katalogda olmayan iş") zaten anlatıyor.
         *
         * Kalan beşi, sahada gerçekten sorulan şeyler: muafiyet, barkod, çoklu adres,
         * gün arşivi, kuryenin ne göreceği. "Kip" gibi kelimeler de temizlendi.
         */
        'ek' => [
            ['ik' => 'elpara', 't' => 'Para almadığınız müşteriler', 'a' => 'Akrabaya, komşuya bedava gönderdiğiniz siparişler listede işaretlenir; deftere sıfır tutarla düşer, cironuzu bozmaz.'],
            ['ik' => 'barkod', 't' => 'Barkod okutarak ürün ekleme', 'a' => 'Telefonun kamerasıyla okutun, ürün sepete düşsün. Barkodu olmayan mal için elle satır açarsınız.'],
            ['ik' => 'pin', 't' => 'Bir müşteriye birden fazla adres', 'a' => 'Evi, dükkânı ve deposu ayrı ayrı kayıtlı durur. Hangisine gideceğinizi sipariş girerken seçersiniz.'],
            ['ik' => 'takvim', 't' => 'Geçmiş günler duruyor', 'a' => 'Kapattığınız her gün cirosu, kasa farkı ve sipariş sayısıyla saklanır. Geçen ayın salısına dönüp bakabilirsiniz.'],
            ['ik' => 'kurye', 't' => 'Kurye her şeyi göremez', 'a' => 'Kurye hesabı yalnız kendi teslimatlarını görür. Fiyat listesi, veresiye defteri ve ayarlar ona kapalıdır.'],
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
         * ⚠️ WHATSAPP SATIRI KALDIRILDI (2026-09-01). Elle yazılmış "[WhatsApp numarası]" yer
         * tutucusuydu; `bos()` süzgeci onu HER ZAMAN düşürüyordu, yani listede hiç görünmeyen ama
         * kodda duran ölü bir satırdı ve "WhatsApp desteği var" izlenimini kod okuyanda bırakıyordu.
         * Gerçek numara geldiği gün geri gelmesinin yolu config'e bir anahtar eklemekten geçer
         * (COMPANY_WHATSAPP), yer tutucu satırı canlandırmaktan değil.
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
