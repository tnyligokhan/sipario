<?php

/*
 * GENEL SİTE İÇERİĞİ — tek kaynak.
 *
 * ── ÜRÜN KİMDİR ─────────────────────────────────────────────────────────────────────────────
 * Sipario, **paket servisi yapan küçük ve orta işletmeler** için bir sipariş, kurye ve veresiye
 * uygulamasıdır. Restoran, kafe, pastane, fırın, market, manav, şarküteri, çiçekçi, su ve tüp
 * bayii — telefonla sipariş alıp adrese gönderen her işletme.
 *
 * ⚠️ TEK BİR SEKTÖRÜN ADIYLA METİN YAZILMAZ. Bu dosyadaki hiçbir cümle ürünü "su bayii
 * uygulaması" ya da "restoran uygulaması" gibi göstermez; örnekler çoğuldur ve sektör şeridi
 * kapsamı gösterir. Ekran maketlerindeki temsili sepet de tek bir dikeye çakılmaz.
 *
 * NEDEN BLADE PARTIAL DEĞİL DE DÜZ PHP: Blade `@include` çağrılan görünümde tanımlanan değişkenleri
 * ÇAĞIRANA geri vermez; ortak içeriği tek yerde tutmanın yolu `require` ile dizi döndürmektir.
 * `php artisan view:cache` yalnız `*.blade.php` derler, bu dosyaya dokunmaz.
 *
 * SAYI YOK: fiyat, deneme süresi, kota gibi SUNUCU SAHİPLİ değerler burada SABİT YAZILMAZ. Dosya
 * bir closure döndürür; çağıran taraf güncel değerleri (PlanDeposu + EkPaketServisi) $d ile geçirir.
 *
 * TEK PLAN: `plans` tablosu tek satırlıdır; ikinci bir plan satılmaz.
 *
 * @param array{deneme:int, kontor:int, kurye:int, ekKuryeTl:string, ekKuryeKisa:string,
 *              ekKuryeVar:bool, kunye:array<string,string>, bos:callable(?string):bool} $d
 */

return function (array $d): array {
    return [
        /*
         * Hero altındaki sektör şeridi. Sıra kasıtlı: en yaygın paket servis türleri önde.
         * Listenin işi kapsamı GÖSTERMEK — "benim işim de bunlardan biri" dedirtmek.
         */
        'sektor' => ['Restoran', 'Kafe', 'Pastane', 'Fırın', 'Market', 'Manav', 'Şarküteri', 'Su ve tüp bayii', 'Çiçekçi'],

        // Kâğıt defterin maliyeti. (Bugün hiçbir sayfa basmıyor; anlatı yeniden gerekirse burada.)
        'dert' => [
            ['ik' => 'defter', 't' => 'Alacak defterde kalıyor', 'a' => 'Kimin ne kadar borcu olduğunu bir tek defteri tutan biliyor. O kişi izne çıktığında tahsilat da izne çıkıyor.', 'c' => 'Her müşterinin borcu, hareketi ve en son ne zaman ödediği tek ekranda.'],
            ['ik' => 'cagri', 't' => 'Aynı soruları her gün baştan soruyorsunuz', 'a' => '“Adınız neydi? Adres neresiydi? Geçen sefer ne göndermiştik?” Müşteri her aramada kendini yeniden anlatıyor.', 'c' => 'Telefon çaldığı anda adı, adresi, son siparişi ve borcu ekranda.'],
            ['ik' => 'para', 't' => 'Akşam kasa tutmuyor', 'a' => 'Nakit, kart ve veresiye gün içinde birbirine karışıyor. Akşam bir fark çıkıyor ama nereden çıktığını kimse bilmiyor.', 'c' => 'Gün sonunda üç kalem ayrı ayrı sayılıyor; fark varsa nerede olduğu görünüyor.'],
        ],

        /*
         * Ürünün beş alanı. `ekran` = x-site.telefon maketi, `cagri` = üstüne çağrı kartı binsin mi,
         * `k` = çapa/sekme anahtarı.
         */
        'tur' => [
            [
                'k' => 'cagri', 'ad' => 'Arayan tanıma', 'ik' => 'cagri', 'ekran' => 'ana', 'cagri' => true,
                'bas' => 'Telefon çalıyor ve kimin aradığını zaten biliyorsunuz.',
                'a' => 'Numara listenizde kayıtlıysa kartı ekrana geliyor: adı, kayıtlı adresleri, açık borcu, en son ne sipariş ettiği. Kayıtlı değilse tek dokunuşla yeni müşteri açıyorsunuz, numara hazır geliyor.',
                'ozet' => ['Kayıtlı numara anında eşleşiyor', 'Borcu ve son siparişi kartın üstünde', 'Yeni numara için tek dokunuşla kayıt'],
            ],
            [
                'k' => 'siparis', 'ad' => 'Sipariş alma', 'ik' => 'fis', 'ekran' => 'siparis', 'cagri' => false,
                'bas' => 'Müşteri hâlâ telefondayken sipariş kaydedilmiş oluyor.',
                'a' => 'Müşteriyi seçiyorsunuz, ürünleri ekliyorsunuz, kuryeye atıyorsunuz. Menünüzde ya da rafınızda olmayan bir şey varsa açıklamasını yazıp tutarını giriyorsunuz — o da deftere düşüyor.',
                'ozet' => ['Kendi ürün listenizden ya da barkod okutarak', 'Liste dışı iş için serbest satır', 'Açık, teslim edildi, iptal — hepsi ayrı görünüyor'],
            ],
            [
                'k' => 'kurye', 'ad' => 'Kurye ve rota', 'ik' => 'kurye', 'ekran' => 'kurye', 'cagri' => false,
                'bas' => 'Hangi kurye nereye gidiyor, sırası ne — bakınca görüyorsunuz.',
                'a' => 'Siparişleri kuryeye atıyorsunuz. Konumu kayıtlı adresler için sırayı uygulama kuruyor; beğenmezseniz parmağınızla sürükleyip kendiniz diziyorsunuz.',
                'ozet' => ['Kuryeye atama ve teslim onayı', 'Sırayı uygulama kuruyor ya da siz diziyorsunuz', 'Konumu olmayan adres uyarı veriyor'],
            ],
            [
                'k' => 'veresiye', 'ad' => 'Veresiye defteri', 'ik' => 'defter', 'ekran' => 'musteri', 'cagri' => false,
                'bas' => 'Borcu herkes aynı yerden, aynı rakamla görüyor.',
                'a' => 'Her müşterinin altında borç ve ödeme hareketi işliyor. Kurye tahsilatı girdiği anda borç düşüyor; siz de aynı rakamı görüyorsunuz, akşamı beklemiyorsunuz.',
                'ozet' => ['Borçlu, alacaklı ve temiz müşteri renkten ayrılıyor', 'Tahsilat girildiği an borç güncelleniyor', 'Hangi ödemenin nasıl alındığı kayıtta duruyor'],
            ],
            [
                'k' => 'gunsonu', 'ad' => 'Gün sonu', 'ik' => 'para', 'ekran' => 'gunsonu', 'cagri' => false,
                'bas' => 'Akşam kasayı üç kalemde kapatıyorsunuz.',
                'a' => 'Nakit, kart ve veresiye ayrı ayrı toplanıyor. Elinizde saydığınız parayı giriyorsunuz, fark varsa hemen çıkıyor. Kapanan gün arşive düşüyor, sonra dönüp bakabiliyorsunuz.',
                'ozet' => ['Nakit, kart ve veresiye ayrı toplanıyor', 'Saydığınız parayla arasındaki fark anında çıkıyor', 'Kapanan günler arşivde duruyor'],
            ],
        ],

        /*
         * Kurulum adımları. Metin kayıt formuyla birebir uyumlu olmak zorunda: form işletme adı ve
         * e-posta ister, telefon SORMAZ (livewire/site/register.blade.php · adım 0).
         */
        'adim' => [
            ['n' => '01', 't' => 'Hesabınızı açın', 's' => '2 dakika', 'a' => 'İşletme adınız ve bir e-posta adresi yeter. Firma kodunuz bu ekranda çıkar — ekibiniz uygulamaya o kodla girecek.'],
            ['n' => '02', 't' => 'Müşterilerinizi bize gönderin', 's' => 'Aynı gün', 'a' => 'Telefon rehberi, Excel listesi ya da defterin fotoğrafı — nasıl duruyorsa gönderin, biz gireriz. Açık borçları da birlikte taşıyoruz.'],
            ['n' => '03', 't' => 'Çağrı iznini verin', 's' => '5 dakika', 'a' => 'Uygulama bir kez izin isteyecek. İzni verdiğinizde ilk gelen aramada müşteri kartı ekranınıza gelir — kurulum bitmiş olur.'],
        ],

        /*
         * Güvenceler. Hepsi doğrulanabilir olmak zorunda: barındırma Almanya'da (Frankfurt) ve
         * künyede gerçek bir telefon numarası yok — ikisi de burada vaat edilmez.
         */
        'guvence' => [
            ['ik' => 'cevrimdisi', 't' => 'İnternet gitse de çalışır', 'a' => 'Sipariş ve tahsilat telefonda tutulur, bağlantı gelince kendi kendine yerine oturur.'],
            ['ik' => 'kalkan', 't' => 'Defteriniz size özel', 'a' => 'Her işletmenin verisi veritabanı düzeyinde ayrıdır. Satılmaz, reklama verilmez, yapay zekâ eğitiminde kullanılmaz.'],
            ['ik' => 'indir', 't' => 'Veriniz sizin', 'a' => 'Müşteri, sipariş ve defter kaydınızı isteyin, Excel olarak gönderelim. Abonelik bitse de bu kapı açık.'],
            ['ik' => 'kulaklik', 't' => 'Cevabı insan yazıyor', 'a' => 'Hafta içi 09:00–19:00 arası aynı ekip. Otomatik yanıt yollamıyoruz.'],
        ],

        /*
         * SSS. Deneme süresi PlanDeposu'ndan gelir. Ödeme grubundaki cevaplar İPTAL/İADE
         * belgesiyle birebir tutmak zorunda: iade taahhüdü yok, otomatik yenileme yok.
         */
        'sss' => [
            ['g' => 'Başlangıç', 'l' => [
                ['s' => 'Deneme için kart bilgisi istiyor musunuz?', 'c' => 'Hayır. '.$d['deneme'].' gün boyunca hiçbir ödeme bilgisi vermeden her şeyi kullanırsınız. Süre dolunca yeni kayıt girilemez; girdikleriniz olduğu gibi durur ve abone olduğunuz gün geri gelir.'],
                ['s' => 'Hangi işletmeler kullanıyor?', 'c' => 'Telefonla sipariş alıp adrese gönderen her işletme: restoran, kafe, pastane, fırın, market, manav, şarküteri, çiçekçi, su ve tüp bayii. Ürün sektöre göre değil, İŞİN AKIŞINA göre kurgulandı — sipariş, teslimat, tahsilat.'],
                ['s' => 'Eski defterimdeki müşterileri nasıl aktarırım?', 'c' => 'Excel listesi, telefon rehberi, hatta defterin fotoğrafı — nasıl duruyorsa öyle gönderin, biz gireriz. Ücret almıyoruz. Açık veresiye bakiyelerini de başlangıç borcu olarak taşıyoruz.'],
                ['s' => 'Kaç kişi kullanabilir?', 'c' => 'İşletme sahibi + '.$d['kurye'].' kurye hesabı. Daha fazla kuryeniz varsa ek hesap '.$d['ekKuryeTl'].'.'],
                ['s' => 'Kurmak zor mu, birinin gelmesi gerekiyor mu?', 'c' => 'Kimsenin gelmesi gerekmiyor. Uygulamayı indirip firma kodunuzla giriyorsunuz; çağrı iznini verdiğiniz an arayan tanıma çalışmaya başlıyor. Takılırsanız birlikte kuruyoruz, o da ücretsiz.'],
            ]],
            ['g' => 'Ödeme', 'l' => [
                ['s' => 'Hangi ödeme yöntemlerini kabul ediyorsunuz?', 'c' => 'Şimdilik havale/EFT ve elden ödeme. Kartla online ödeme üzerinde çalışıyoruz; açıldığında hesap panelinizde göreceksiniz.'],
                ['s' => 'Fatura kesiyor musunuz?', 'c' => 'Evet, her ödeme için e-arşiv fatura düzenleyip e-posta ile gönderiyoruz. Ödeme geçmişinizin tamamı hesap panelinizdeki Faturalar bölümünde duruyor.'],
                ['s' => 'İstediğim zaman bırakabilir miyim?', 'c' => 'Evet ve bunun için bir şey yapmanız gerekmiyor: otomatik yenileme diye bir şey yok, kartınızdan kendiliğinden para çekilmez. Ödemezseniz dönem sonunda hesap yeni kayıt almayı durdurur, o kadar. Kayıtlarınız silinmez.'],
                ['s' => 'Ödedikten sonra vazgeçersem param geri gelir mi?', 'c' => 'Ödenmiş dönem için iade yapmıyoruz. Bunun yerine '.$d['deneme'].' gün ücretsiz deneme var: kart bilgisi vermeden, tam sürümle, kendi müşterilerinizle deniyorsunuz. Ödeme kararını ancak ürünü gördükten sonra veriyorsunuz.'],
                ['s' => 'Fiyat sonradan artar mı?', 'c' => 'Ödediğiniz dönemin fiyatı sabittir, dönem ortasında değişmez. Yeni dönemde fiyat değişecekse en az 30 gün önce haber veriyoruz — sürpriz zam yok.'],
            ]],
            ['g' => 'Teknik', 'l' => [
                ['s' => 'İnternet kesilirse ne olur?', 'c' => 'Uygulama çalışmaya devam eder. Sipariş, tahsilat ve düzeltmeler telefonda birikir; bağlantı gelince kendi kendine sunucuya geçer. Kurye asansörde de teslim kapatır.'],
                ['s' => 'Arayan tanıma nasıl çalışıyor?', 'c' => 'Gelen numara telefonun kendi içinde, sizin müşteri listenizle eşleştirilir. Numara bu iş için sunucuya ya da üçüncü bir tarafa gönderilmez.'],
                ['s' => 'iPhone’da çalışıyor mu?', 'c' => 'Android’de her şey var. iPhone’da arayan tanıma dışındaki tüm özellikler çalışıyor — iOS işletim sistemi uygulamaların gelen çağrıyı görmesine izin vermiyor, bu bizim eksiğimiz değil Apple’ın kuralı.'],
                ['s' => 'Verilerim nerede duruyor?', 'c' => 'Müşteri listeniz, siparişleriniz ve defteriniz Almanya’daki (Frankfurt) sunucularımızda saklanır ve KVKK kapsamında işlenir. Her işletmenin verisi veritabanı düzeyinde ayrıdır; biz de iş verinizi değiştiremeyiz. Adres ararken ve kurye yolunu sıralarken yalnız adres metni harita servisine gider — müşterinizin adı, telefonu ve borcu hiçbir çağrıda yer almaz.'],
                ['s' => 'Yazar kasa ya da muhasebe programıma bağlanıyor mu?', 'c' => 'Hayır. Sipario muhasebe programı değil; e-fatura kesmez, beyanname doldurmaz, yazar kasayla konuşmaz. Yaptığı iş sipariş, teslimat ve tahsilatın kaydını tutmak.'],
            ]],
        ],

        // ── Plan (fiyat PlanDeposu'ndan, kartın içinde) ─────────────────────────────────────
        'plan' => [
            'sipario' => [
                'ad' => 'Sipario',
                'ozet' => 'Sipariş, kurye ve defter — hepsi içinde.',
                'cta' => $d['deneme'].' gün ücretsiz dene',
                'ctaAlt' => 'Kart istemiyoruz',
                'kapsam' => [
                    ['t' => 'Sınırsız müşteri ve sipariş', 'a' => 'Kayıt sayısına göre ücret almıyoruz'],
                    ['t' => 'Arayan tanıma', 'a' => 'Telefon çaldığı anda kart ekrana gelir'],
                    ['t' => 'Veresiye defteri', 'a' => 'Bakiye, tahsilat, hareket geçmişi'],
                    ['t' => 'Gün sonu kasa', 'a' => 'Nakit · kart · veresiye ayrımıyla devir'],
                    /*
                     * `k` anahtarı bir GÖRÜNÜM KANCASIDIR: plan levhası bu satırı tanıyıp ek kurye
                     * paketlerini ipucu olarak buraya gömüyor (components/site/plan-yatay).
                     * Metinle aramak da işe yarardı ama metin bir kopya kararıdır, anahtar sözleşme.
                     * Alt satır katalogda paket VARKEN boş — fiyat ipucunun içinde, iki kez yazılmaz.
                     */
                    ['t' => $d['kurye'].' kurye hesabı', 'a' => $d['ekKuryeVar'] ? null : 'Ek kurye '.$d['ekKuryeTl'], 'k' => 'kurye'],
                    ['t' => 'Kuryenin yolunu uygulama sıralasın', 'a' => 'Ayda '.$d['kontor'].' kez'],
                    ['t' => 'Ürün listesi ve barkod', 'a' => 'Fotoğraflı, birimli, çok fiyatlı'],
                    ['t' => 'Gerçek insandan destek', 'a' => 'Hafta içi 09:00–19:00, aynı gün yanıt'],
                ],
            ],
        ],

        // ── Plan detay tablosu (tek plan → tek değer sütunu) ────────────────────────────────
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

        // ── Ödeme yolları ve güvencesi ─────────────────────────────────────────────────────
        'odemeGuven' => [
            ['ik' => 'para', 't' => 'Havale / EFT', 'a' => 'Banka havalesiyle ödeyin; dekont ulaştığı gün hesabınız açılır. IBAN ve referans kodu ödeme adımında çıkar.'],
            ['ik' => 'elpara', 't' => 'Elden ödeme', 'a' => 'Bölgenizdeyse uğrayıp elden alıyoruz. Makbuzu yerinde veriyoruz, hesap aynı gün açılıyor.'],
            ['ik' => 'kart', 't' => 'Kartla ödeme yakında', 'a' => 'Kredi ve banka kartıyla online ödeme üzerinde çalışıyoruz. Açıldığında panelinizden duyuracağız.'],
            ['ik' => 'geri', 't' => 'Önce deneyin, sonra ödeyin', 'a' => $d['deneme'].' gün ücretsiz, kart bilgisi istemeden. Otomatik yenileme yok; ödemeyi her dönem siz başlatırsınız.'],
        ],

        // ── Küçük ama her gün lazım olanlar ────────────────────────────────────────────────
        'ek' => [
            ['ik' => 'elpara', 't' => 'Para almadığınız siparişler', 'a' => 'Personele, komşuya ya da ikram olarak gönderdikleriniz listede işaretlenir; deftere sıfır tutarla düşer, cironuzu bozmaz.'],
            ['ik' => 'barkod', 't' => 'Barkod okutarak ürün ekleme', 'a' => 'Telefonun kamerasıyla okutun, ürün sepete düşsün. Barkodu olmayan ürün için elle satır açarsınız.'],
            ['ik' => 'pin', 't' => 'Bir müşteriye birden fazla adres', 'a' => 'Evi, iş yeri ve ikinci adresi ayrı ayrı kayıtlı durur. Hangisine gideceğinizi sipariş girerken seçersiniz.'],
            ['ik' => 'takvim', 't' => 'Geçmiş günler duruyor', 'a' => 'Kapattığınız her gün cirosu, kasa farkı ve sipariş sayısıyla saklanır. Geçen ayın salısına dönüp bakabilirsiniz.'],
            ['ik' => 'kurye', 't' => 'Kurye her şeyi göremez', 'a' => 'Kurye hesabı yalnız kendi teslimatlarını görür. Fiyat listesi, veresiye defteri ve ayarlar ona kapalıdır.'],
        ],

        // ── "Bir gün" anlatısı (bugün hiçbir sayfa basmıyor) ───────────────────────────────
        'gun' => [
            ['s' => '10:10', 't' => 'Gün açılır', 'a' => 'Dünden devreden kasa girilir. Açık siparişler ekranın üstünde.'],
            ['s' => '12:24', 't' => 'Telefon çalar', 'a' => 'Ahmet Yılmaz. Kart açılır: adres hazır, açık borcu görünüyor, geçen sefer ne aldığı yazıyor.'],
            ['s' => '12:25', 't' => 'Sipariş girilir', 'a' => 'Karttan “Sipariş oluştur”. Ürün seçilir, kuryeye atanır. Üç dokunuş.'],
            ['s' => '13:05', 't' => 'Kurye teslim eder', 'a' => 'Kurye kendi telefonundan teslim işaretler, nakit tahsilatı girer. Bakiye anında düşer.'],
            ['s' => '22:40', 't' => 'Gün kapanır', 'a' => 'Nakit sayılır, fark kontrol edilir, gün arşive düşer. Yarın sıfırdan başlar.'],
        ],

        /*
         * Destek kanalları — değerler config('subscription.company')'den. `href` yalnız değer
         * GERÇEKse dolar; köşeli parantezli config varsayılanı yer tutucudur ve o satır listeden
         * hiç düşer. Gerçek numara girildiği gün kanal kendiliğinden geri gelir.
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
         * İletişim formunun gideceği adres. Yer tutucu olduğu sürece null döner; o durumda "Gönder"
         * düğmesi PASİF kalır ve altında gerekçesi yazar — sahte "gönderildi" ekranı gösterilmez.
         */
        'destekEposta' => $d['bos']($d['kunye']['support_email'] ?? null) ? null : $d['kunye']['support_email'],
    ];
};
