<?php

namespace Tests\Feature\Api;

use Illuminate\Support\Facades\Auth;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * GENEL SİTE GEZİNMESİ — üst menü, alt bilgi bağlantıları ve oturum görünürlüğü (2026-08-05).
 *
 * NEDEN DB GEREKMEZ: `/hesap-silme` statik bir görünümdür ama `x-layouts.site` kullanır, yani
 * üst menü + alt bilgi ile birlikte basılır. Oturum görünürlüğü de bilerek KULLANICI YÜKLEMEDEN
 * çözülüyor (bkz. layout başlığı) — tam da bu yüzden bu davranış veritabanına hiç dokunmadan
 * sınanabiliyor. Test bunu kullanır: `migrate:fresh` yok, eşzamanlı vardiyalarda yarış yok.
 *
 * NEYİ KORUYOR: "giriş yaptım ama ana sayfada misafir görünüyorum" kusuru SESSİZDİ — hiçbir test
 * genel sayfaların üst menüsüne bakmıyordu, sayfa 200 dönüyordu, kimse fark etmedi. Kök neden
 * mimariydi: genel sayfalar `tenant` middleware'i taşımaz → `app.tenant_id` kurulmaz → `users`
 * RLS'i sıfır satır verir → `Auth::check()` giriş yapmış patrona "misafir" der.
 */
class SiteGezinmeTest extends TestCase
{
    /** Oturumun açık olduğunu söyleyen anahtar — SessionGuard girişte bunu yazar, çıkışta siler. */
    private function oturumAnahtari(): string
    {
        return Auth::guard('web')->getName();
    }

    #[Test]
    public function oturum_acikken_menu_hesabim_gosterir(): void
    {
        // Değer önemsiz: oturum VARLIĞI sorulur, kullanıcı YÜKLENMEZ. Kullanıcı yüklenseydi bu
        // sayfada RLS yüzünden bulunamaz ve menü yine "Giriş yap" derdi — kusurun ta kendisi.
        $this->withSession([$this->oturumAnahtari() => 'oturum-var'])
            ->get('/hesap-silme')
            ->assertOk()
            ->assertSee('Hesabım')
            ->assertDontSee('Ücretsiz dene');
    }

    #[Test]
    public function misafir_menusu_giris_ve_kayit_gosterir(): void
    {
        $this->get('/hesap-silme')
            ->assertOk()
            ->assertSee('Giriş yap')
            ->assertSee('Ücretsiz dene')
            ->assertDontSee('Hesabım');
    }

    /** Üst menünün ham HTML'i — iddiaların sayfanın gerisine taşmaması için. */
    private function ustMenu(array $oturum = []): string
    {
        $istek = $oturum === [] ? $this : $this->withSession($oturum);
        $govde = $istek->get('/hesap-silme')->assertOk()->getContent();

        preg_match('/<header class="ust".*?<\/header>/s', $govde, $m);
        $this->assertNotEmpty($m, 'Üst menü <header class="ust"> bulunamadı.');

        return $m[0];
    }

    #[Test]
    public function misafir_menusunde_cikis_yolu_bulunmaz(): void
    {
        $menu = $this->ustMenu();

        $this->assertStringNotContainsString('Çıkış', $menu);
        $this->assertStringNotContainsString('method="POST"', $menu);
    }

    #[Test]
    public function oturum_acikken_menude_cikis_yolu_vardir_ve_GET_DEGILDIR(): void
    {
        // Çıkışın GET olmaması pazarlıksız: prefetch / üçüncü taraf <img> ile istemsiz tetiklenir.
        // Bu test o kuralı kilitler — biri kolaylık olsun diye <a href>'e çevirirse kırılır.
        if (! \Illuminate\Support\Facades\Route::has('site.cikis')) {
            $this->markTestSkipped(
                'POST `site.cikis` rotası henüz açılmadı (rota dosyasının sahibi LEAD). '
                .'Rota eklendiği an bu test kendiliğinden koşar ve çıkış yolunu doğrular.'
            );
        }

        $menu = $this->ustMenu([$this->oturumAnahtari() => 'oturum-var']);

        // Masaüstü + mobil: iki blokta da çıkış olmalı (mobilde menü ayrı basılıyor).
        $this->assertSame(2, substr_count($menu, 'Çıkış'), 'Çıkış masaüstü VE mobil menüde olmalı.');
        $this->assertSame(2, substr_count($menu, 'action="'.route('site.cikis').'"'));
        $this->assertStringNotContainsString('<a href="'.route('site.cikis').'"', $menu);

        // CSRF alanı olmadan form üçüncü taraf sayfadan gönderilebilirdi.
        $this->assertSame(2, substr_count($menu, 'name="_token"'));
    }

    #[Test]
    public function ust_menu_yalnizca_ozellikler_ve_destek_tasir(): void
    {
        // Kullanıcı kararı 2026-08-05: menü keşif aracıdır, site haritası değil. Fiyatlandırma ve
        // İletişim SAYFA OLARAK DURUR, menüden alt bilgiye indi.
        $govde = $this->get('/hesap-silme')->assertOk()->getContent();

        preg_match('/<nav class="ust-nav".*?<\/nav>/s', $govde, $nav);
        $this->assertNotEmpty($nav, 'Üst menü <nav class="ust-nav"> bulunamadı.');

        $this->assertStringContainsString('Özellikler', $nav[0]);
        $this->assertStringContainsString('Destek', $nav[0]);
        $this->assertStringNotContainsString('Fiyatlandırma', $nav[0]);
        $this->assertStringNotContainsString('İletişim', $nav[0]);
    }

    #[Test]
    public function alt_bilgide_ayni_sayfaya_giden_ikiz_baglanti_kalmadi(): void
    {
        // Kaldırılan tuzaklar: "Kurulum"→/ozellikler (Özellikler'in ikizi), "Sürüm notları" ve
        // "Sık sorulanlar"→/destek, "Demo talebi"→/iletisim. Farklı ad, aynı hedef: bağlantı yeni
        // bir şey vaat edip kullanıcıyı gördüğü sayfaya geri atıyordu.
        $yanit = $this->get('/hesap-silme')->assertOk();

        foreach (['Kurulum', 'Sürüm notları', 'Sık sorulanlar', 'Demo talebi'] as $tuzak) {
            $yanit->assertDontSee($tuzak);
        }
    }

    #[Test]
    public function fiyat_baglantisi_gizlenen_sayfaya_degil_ana_sayfadaki_ozete_gider(): void
    {
        // `fiyat` ajanıyla ortak karar (2026-08-05): /fiyatlar rotası ve sayfası DURUYOR ama
        // `noindex` ile arama motorlarına kapatıldı ve siteden gelen bütün çağrılar ana sayfanın
        // `#fiyat` özetine çevrildi. Alt bilgi, o karara açılan tek delik olarak kalmamalı.
        $govde = $this->get('/hesap-silme')->assertOk()->getContent();

        preg_match('/<div class="alt-baglanti">.*?<\/div>\s*<\/div>\s*<\/div>/s', $govde, $blok);
        $this->assertNotEmpty($blok);

        $this->assertStringContainsString(route('site.ana').'#fiyat', $blok[0]);
        $this->assertStringNotContainsString(route('site.fiyatlar'), $blok[0]);
    }

    #[Test]
    public function alt_bilgideki_her_baglanti_benzersiz_bir_hedefe_gider(): void
    {
        // Sözleşmenin kendisi: ikiz hedef YASAK. Yeni bir satır eklenip aynı adrese bağlanırsa
        // bu test kırılır (etiket listesi ezberlemeden, yapısal olarak).
        $govde = $this->get('/hesap-silme')->assertOk()->getContent();

        preg_match('/<div class="alt-baglanti">.*?<\/div>\s*<\/div>\s*<\/div>/s', $govde, $blok);
        $this->assertNotEmpty($blok, 'Alt bilgi bağlantı bloğu bulunamadı.');

        preg_match_all('/<a href="([^"]+)"/', $blok[0], $m);
        $hedefler = $m[1];

        $this->assertNotEmpty($hedefler);
        $this->assertSame(
            array_values(array_unique($hedefler)),
            $hedefler,
            'Alt bilgide aynı adrese giden iki bağlantı var: '
            .implode(', ', array_keys(array_diff_key($hedefler, array_unique($hedefler))))
        );
    }

    #[Test]
    public function alt_bilgi_kunye_bloklarini_basmaz_ama_kunye_yasal_belgelerden_erisilir(): void
    {
        // Madde 10: dört künye kutusu (Ünvan/Kayıt/İletişim/Ödeme) kalktı — hepsi köşeli parantezli
        // yer tutucu basıyordu. Mevzuat karşılığı kapalı kalmalı: satıcı künyesi mesafeli satış
        // sözleşmesi ve ön bilgilendirme formunda duruyor ve alt bilgiden tek tıkla açılıyor.
        $this->get('/hesap-silme')
            ->assertOk()
            ->assertDontSee('alt-kunye', false)
            ->assertDontSee('MERSİS')
            ->assertSee(route('legal.show', 'mesafeli-satis'), false)
            ->assertSee(route('legal.show', 'on-bilgilendirme'), false);
    }

    #[Test]
    public function alt_bilgide_koseli_parantezli_yer_tutucu_gorunmez(): void
    {
        // Kullanıcının gördüğü kusur buydu: sayfanın dibi "[Şirket unvanı]" gibi kırık kutularla
        // doluydu. Telif satırı da dahil hiçbir yer tutucu artık ekrana çıkmamalı.
        $govde = $this->get('/hesap-silme')->assertOk()->getContent();

        $altBilgi = mb_substr($govde, (int) mb_strpos($govde, '<footer class="alt'));

        $this->assertDoesNotMatchRegularExpression(
            '/\[[^\]]{3,40}\]/u',
            strip_tags($altBilgi),
            'Alt bilgide hâlâ köşeli parantezli yer tutucu basılıyor.'
        );
    }
}
