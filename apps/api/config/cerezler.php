<?php

/*
 * ÇEREZ ENVANTERİ VE RIZA YAPILANDIRMASI — 2026-08-28.
 *
 * ── NEDEN AYRI BİR DOSYA (ve neden analitik.php'nin içinde değil) ────────────────────────────
 * Rıza yönetimi ölçümün bir alt başlığı DEĞİLDİR. Ölçüm, rızaya bağlı KATEGORİLERDEN yalnız
 * biridir; zorunlu çerezler (oturum, CSRF, rızanın kendisi) ölçüm kapalıyken de vardır ve
 * KVKK bilgilendirmesi onları da kapsar. Rıza ayarını `analitik.php` içinde tutmak, "ölçüm
 * yoksa çerez de yok" gibi yanlış bir denklem kurardı.
 *
 * ── BU DOSYA HEM ARAYÜZÜN HEM BELGENİN KAYNAĞIDIR — TEK LİSTE ────────────────────────────────
 * Aynı çerez listesi iki yerde görünür: (1) çerez tercih penceresi (site alt bandı), (2) Çerez
 * Politikası belgesi. Bugüne kadar liste YALNIZ belgeye elle yazılmıştı ve şu ölçülebilir
 * sonucu doğurmuştu: belge `sipario_session` diyordu, tarayıcıya yazılan çerezin gerçek adı
 * `sipario-session` idi (config/session.php → APP_NAME slug'ı + "-session"). Yani ziyaretçi
 * politikadaki adı tarayıcısında ARASA BULAMAZDI. İki liste tutmanın bedeli budur; bu yüzden
 * liste tek yerdedir ve dinamik değerler (oturum çerezinin adı, süresi, GA4 kimliği) buradan
 * DEĞİL, `App\Support\Cerez\CerezEnvanteri` tarafından çalışma anında çözülür.
 *
 * ── YER TUTUCULAR NEDEN VAR ──────────────────────────────────────────────────────────────────
 * Config dosyaları `config:cache` ile serileştirilir; closure ya da `config()` çağrısı burada
 * YAŞAYAMAZ. Bu yüzden çalışma anında değişen değerler `%…%` işaretleriyle yazılır ve envanter
 * sınıfı bunları çözer. Karşılıkları:
 *   %oturum_cerezi% → config('session.cookie')      %oturum_dk%  → config('session.lifetime')
 *   %riza_cerezi%   → aşağıdaki 'cerez'             %riza_ay%    → aşağıdaki 'gun', ay olarak
 *   %ga4%           → config('analitik.measurement_id')
 *
 * ── RIZA SÜRÜMÜ (`surum`) NE İŞE YARAR ───────────────────────────────────────────────────────
 * Ziyaretçinin verdiği rıza, RIZA VERDİĞİ LİSTEYE aittir. Listeye yeni bir çerez ya da yeni bir
 * kategori eklenirse eski rıza o yeni şeyi kapsamaz — KVKK m.3/1-a rızayı "belirli bir konuya
 * ilişkin" sayar. `surum` artırıldığında kayıtlı tercih geçersizleşir ve pencere bir kez daha
 * sorar. ⚠️ SÜRÜMÜ YALNIZ LİSTE DEĞİŞİNCE ARTIR: her vardiyada artırmak, ziyaretçiye sürekli
 * pencere göstermek demektir ve rıza yorgunluğu yaratır (rehberin karşı olduğu şeyin ta kendisi).
 */
return [
    /*
     * Tercihin saklandığı çerezin adı ve ömrü. Bu çerezin KENDİSİ zorunlu çerezdir: onsuz
     * ziyaretçinin "hayır" cevabı hatırlanamaz ve her sayfada tekrar sorulur.
     *
     * ⚠️ AD İKİ YERDE DAHA YAZILI: bootstrap/app.php (şifrelemeden muaf tutulur — çerezi
     * tarayıcıdaki JS yazar, Laravel onu çözemez) ve public/js/cerez.js'e JSON kanalıyla geçer.
     * bootstrap/app.php'deki kopyayı CerezYonetimiTest kilitler.
     */
    'cerez' => 'sipario_cerez_izni',
    'gun' => 180,

    // Rıza sürümü — liste değişince artır, başka hiçbir sebeple artırma.
    'surum' => 1,

    /*
     * KATEGORİLER. Sıra ekranda göründüğü sıradır; zorunlu olan ÖNCE gelir çünkü ziyaretçinin
     * ilk sorusu "kapatamadığım ne var?"dır.
     *
     * Alanlar:
     *   ad       → pencerede ve belgede görünen başlık
     *   ozet     → kategorinin ne işe yaradığı, esnaf diliyle tek paragraf
     *   zorunlu  → true ise anahtar yoktur ("her zaman açık"), rıza aranmaz
     *   dayanak  → KVKK dayanağı; belge bunu birebir basar
     *   kosul    → kategori ancak bu koşul sağlanınca VAR SAYILIR (null = her zaman var).
     *              'analitik' → config('analitik.enabled') && measurement_id dolu.
     *              Koşulu sağlanmayan kategori ne pencerede ne belgede görünür: kurulmamış bir
     *              çerez için rıza istemek, olmayan bir şeyi ilan etmektir.
     *   cerezler → o kategoride tarayıcıya yazılan çerezlerin listesi
     */
    'kategoriler' => [
        'zorunlu' => [
            'ad' => 'Zorunlu çerezler',
            'ozet' => 'Sitenin çalışması için kesinlikle gereklidir: oturumunuzu açık tutar, formlarınızı sahte istek saldırılarına karşı korur ve çerez tercihinizi hatırlar. Bunlar olmadan giriş yapamaz ve form gönderemezsiniz.',
            'zorunlu' => true,
            'dayanak' => 'KVKK m.5/2-c (sözleşmenin kurulması ve ifası) ve m.5/2-f (meşru menfaat). KVK Kurulu çerez rehberi uyarınca açık rıza aranmaz, bilgilendirme yeterlidir.',
            'kosul' => null,
            'cerezler' => [
                [
                    'ad' => '%oturum_cerezi%',
                    'ne' => 'Oturumunuzu ayakta tutar; giriş yaptığınızda sizi hatırlar.',
                    'sure' => '%oturum_dk% dakika',
                    'taraf' => 'Birinci taraf',
                    'saglayici' => 'Sipario',
                ],
                [
                    'ad' => 'XSRF-TOKEN',
                    'ne' => 'Form gönderimlerini sahte istek saldırılarına (CSRF) karşı korur.',
                    'sure' => '%oturum_dk% dakika',
                    'taraf' => 'Birinci taraf',
                    'saglayici' => 'Sipario',
                ],
                [
                    'ad' => '%riza_cerezi%',
                    'ne' => 'Bu penceredeki tercihinizi hatırlar; her ziyarette tekrar sorulmasını önler.',
                    'sure' => '%riza_ay% ay',
                    'taraf' => 'Birinci taraf',
                    'saglayici' => 'Sipario',
                ],
            ],
        ],

        'olcum' => [
            'ad' => 'Ölçüm çerezleri',
            'ozet' => 'Hangi sayfaların okunduğunu, ziyaretçinin hangi adımda vazgeçtiğini ve siteye nereden gelindiğini görmemizi sağlar. Amaç reklam değil, sitenin kendisini düzeltmektir. Kapalı bırakırsanız site aynen çalışır, hiçbir işlev eksilmez.',
            'zorunlu' => false,
            'dayanak' => 'YALNIZ KVKK m.5/1 açık rızanıza dayanır. İzin vermezseniz Google\'a hiçbir istek gönderilmez; izni geri alırsanız ölçüm durur ve aşağıdaki çerezler silinir.',
            'kosul' => 'analitik',
            'cerezler' => [
                [
                    'ad' => '_ga',
                    'ne' => 'Ziyaretçiyi ayırt eden rastgele bir kimlik tutar — kim olduğunuzu değil, aynı ziyaretçi olduğunuzu bilir.',
                    'sure' => '2 yıl',
                    'taraf' => 'Üçüncü taraf',
                    'saglayici' => 'Google Analytics 4',
                ],
                [
                    'ad' => '_ga_%ga4%',
                    'ne' => 'Oturum durumunu tutar; bir ziyaretin nerede başlayıp nerede bittiğini belirler.',
                    'sure' => '2 yıl',
                    'taraf' => 'Üçüncü taraf',
                    'saglayici' => 'Google Analytics 4',
                ],
            ],
        ],
    ],

    /*
     * KULLANMADIKLARIMIZ. Belgede ve pencerede "yok" diye ilan edilenler. Liste burada duruyor
     * ki bir gün biri eklenirse buradan SİLİNMESİ gerektiği görünsün — ilan edilen bir yokluğun
     * sessizce yalana dönmesi, hiç ilan etmemekten kötüdür.
     */
    'yok' => [
        'Reklam ve yeniden hedefleme (retargeting) çerezleri',
        'Sosyal medya paylaşım izleyicileri',
        'Isı haritası ve oturum kaydı araçları',
        'Üçüncü taraf yazı tipi ve içerik dağıtım ağları',
    ],
];
