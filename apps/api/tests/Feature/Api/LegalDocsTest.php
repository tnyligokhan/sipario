<?php

namespace Tests\Feature\Api;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * HUKUK BELGELERİ — 2026-08-19'da metinler baştan yazıldıktan sonra sözleşme değişti.
 *
 * ── ESKİ TESTİN NE YAPTIĞI VE NEDEN ARTIK YANLIŞ OLDUĞU ──────────────────────────────────
 * Eski sürüm her belgede `assertSee('PLACEHOLDER')` arıyordu — "metin hukuk onayından geçmedi"
 * işareti. O iddia, belgeler İSKELET olduğu sürece doğru bir bekçiydi: gövde "avukat
 * netleştirecek" cümlelerinden ibaretti ve uyarının kaldırılması gerçekten bir kusur olurdu.
 *
 * Bugün belgeler tam metin. Uyarı kutusu duruyor ama artık "yazılmadı" değil "avukat görmedi"
 * diyor (bkz. components/legal/uyari.blade.php). "PLACEHOLDER" kelimesini aramaya devam etmek,
 * avukat onayı geldiği gün kutunun kaldırılmasını TESTİN engellemesi demekti — yani bekçi,
 * koruduğu şeyin tersine çalışmaya başlardı.
 *
 * ── BUGÜN NE KORUNUYOR ───────────────────────────────────────────────────────────────────
 * Sözleşme "metin taslak mı" değil, "belge gerçekten bir belge mi" sorusuna kaydı:
 *   1. Haritadaki HER slug 200 döner, başlığını ve sürümünü basar (eski iskelet testi).
 *   2. Gövde ciddi bir metin taşır — boş/yarım bir partial sessizce 200 dönebilir.
 *   3. Mevzuatın istediği ASGARİ belge kümesi haritada durur. Biri silinirse test kırılır;
 *      "çerez politikasını kaldıralım" gibi bir sadeleştirme, mevzuat açığı olarak geri gelir.
 *   4. Ödeme akışındaki onay kutularının bağlandığı üç belge YAŞIYOR. Bu bağ kopmuş bir slug
 *      bıraksaydı bayi "okudum, kabul ediyorum" derken 404'e onay vermiş olurdu.
 *   5. Belgeler birbirine atıf yapıyor ve atılan her bağlantı gerçek bir slug'a gidiyor.
 *
 * DB gerektirmez (salt route + view) — eşzamanlı vardiyalarda migrate:fresh yarışına girmez.
 */
class LegalDocsTest extends TestCase
{
    /**
     * Mevzuatın karşılığı olan ASGARİ belge kümesi. Her satırın yanındaki gerekçe, belgenin
     * neden silinemeyeceğini söyler — liste ezberden değil, dayanaktan çıkar.
     */
    private const ZORUNLU_BELGELER = [
        'mesafeli-satis' => 'Mesafeli Sözleşmeler Yönetmeliği — sözleşmenin kendisi',
        'on-bilgilendirme' => 'MSY m.5 — sözleşme öncesi bilgilendirme yükümlülüğü',
        'iptal-iade' => 'MSY m.9/m.15 — cayma ve iade koşullarının ilanı',
        'kullanim-kosullari' => 'Hesabın kullanımına ilişkin çerçeve (üyelik sözleşmesi)',
        'kvkk-aydinlatma' => 'KVKK m.10 — aydınlatma yükümlülüğü',
        'gizlilik-politikasi' => 'KVKK m.12 — teknik ve idari tedbirlerin beyanı',
        'acik-riza' => '6563 s. Kanun + KVKK m.5/1 — ileti ve ölçüm rızası, aydınlatmadan AYRI',
        'veri-isleyen' => 'KVKK m.12/1 — bayi veri sorumlusu, Sipario veri işleyen',
        'cerez-politikasi' => 'KVK Kurulu çerez rehberi — çerezlerin ilanı',
        'kvkk-basvuru' => 'Veri Sorumlusuna Başvuru Usul ve Esasları Tebliği m.5/m.7',
    ];

    #[Test]
    public function hukuk_belgeleri_baslik_ve_surumuyle_gorunur(): void
    {
        /** @var array<string, array{title: string, version_key: string}> $docs */
        $docs = config('subscription.legal_docs');
        $this->assertNotEmpty($docs);

        foreach ($docs as $slug => $meta) {
            $version = config('subscription.legal')[$meta['version_key']];

            $this->get("/sozlesme/{$slug}")
                ->assertOk()
                ->assertSee($meta['title'])
                ->assertSee($version);
        }
    }

    #[Test]
    public function her_belge_gercek_bir_metin_tasir(): void
    {
        /*
         * BOŞA GEÇMEYE KARŞI KİLİT (SiteIcerikTest'teki aynı desen). Yarım kalmış ya da
         * yanlışlıkla boşaltılmış bir partial, sayfayı 500 YAPMAZ — sessizce boş bir pano
         * basar ve yukarıdaki test (başlık layout'tan geliyor) yine yeşil kalırdı.
         *
         * Eşik 2500 karakter: ölçülen en kısa belge (açık rıza) 6470 bayt ham HTML, etiketler
         * söküldükten sonra bunun epey altına iner. Eşik, "gerçekten bir sözleşme metni" ile
         * "bir paragraflık yer tutucu" arasını ayıracak kadar yüksek, en kısa belgeyi sahte
         * kırmızıya düşürmeyecek kadar düşük tutuldu.
         */
        foreach (array_keys((array) config('subscription.legal_docs')) as $slug) {
            $ham = $this->get("/sozlesme/{$slug}")->assertOk()->getContent();
            $govde = strip_tags((string) preg_replace('#<(script|style)\b[^>]*>.*?</\1>#su', ' ', $ham));

            $this->assertGreaterThan(
                2500,
                mb_strlen(trim($govde)),
                "/sozlesme/{$slug} şüpheli derecede kısa — belge boşaltılmış olabilir."
            );
        }
    }

    #[Test]
    public function mevzuatin_gerektirdigi_belgeler_haritadan_dusmez(): void
    {
        $docs = (array) config('subscription.legal_docs');

        foreach (self::ZORUNLU_BELGELER as $slug => $gerekce) {
            $this->assertArrayHasKey(
                $slug,
                $docs,
                "Zorunlu hukuk belgesi haritadan düşmüş: {$slug} — dayanak: {$gerekce}"
            );
        }
    }

    #[Test]
    public function odeme_onayindaki_belgeler_yasiyor(): void
    {
        /*
         * `livewire/site/partials/odeme-onaylar.blade.php` ve `register.blade.php` bu üç
         * slug'a `route('legal.show', …)` ile bağlanıyor; kabul edilen sürümler
         * `subscription_payments.consent_version`a yazılıyor. Slug değişirse Laravel route
         * çözer (parametre serbest) ama sayfa 404 döner — yani onay kutusu, açılmayan bir
         * belgeye onay toplamaya devam ederdi. Bu test o sessiz kırığı kapatır.
         */
        foreach (['mesafeli-satis', 'on-bilgilendirme', 'kvkk-aydinlatma'] as $slug) {
            $this->get(route('legal.show', $slug))->assertOk();
        }
    }

    #[Test]
    public function belgeler_arasi_atiflar_gercek_bir_belgeye_gider(): void
    {
        /*
         * Belgeler birbirine yoğun atıf yapıyor ("ayrıntı için Veri İşleyen Sözleşmesi'ne
         * bakınız"). Bir slug yeniden adlandırıldığında bu bağlantılar sessizce 404 olurdu;
         * hukuk metninde ölü bir çapraz atıf, metnin bütününü şüpheli kılar.
         *
         * Yöntem: her belgenin gövdesindeki /sozlesme/... bağlantıları toplanır ve hepsinin
         * haritada karşılığı olduğu doğrulanır. Etiket listesi ezberlenmez — yapısal kontrol.
         */
        $bilinen = array_keys((array) config('subscription.legal_docs'));

        foreach ($bilinen as $slug) {
            $govde = $this->get("/sozlesme/{$slug}")->assertOk()->getContent();

            preg_match_all('#/sozlesme/([a-z0-9-]+)#', $govde, $m);

            foreach (array_unique($m[1]) as $hedef) {
                $this->assertContains(
                    $hedef,
                    $bilinen,
                    "/sozlesme/{$slug} içinde haritada olmayan bir belgeye atıf var: {$hedef}"
                );
            }
        }
    }

    #[Test]
    public function eksik_kunye_alanlari_sayfanin_ustunde_bildirilir(): void
    {
        /*
         * Künye config'te hâlâ yer tutucu (şirket kurulmadı). `x-legal.deger` bunu metnin
         * İÇİNDE işaretliyor; `legal/show.blade.php` işaretleri sayıp en üstte özet uyarı
         * basıyor. Bu, belgeyi yayına alacak insanın yapılacaklar listesidir.
         *
         * Test her iki yönü de sınar: unvan yer tutucuyken uyarı VAR, gerçek değer girildiğinde
         * o alan artık sayılmaz. İkinci yön olmadan test, bugünkü hâli sabitlemekten öteye
         * gitmez ve künye dolduğunda kimse fark etmez.
         */
        $this->get(route('legal.show', 'mesafeli-satis'))
            ->assertOk()
            ->assertSee('DOLDURULACAK')
            ->assertSee('alan</strong> henüz doldurulmadı', false);

        config(['subscription.company.title' => 'Örnek Yazılım Ticaret Limited Şirketi']);

        $govde = $this->get(route('legal.show', 'mesafeli-satis'))->assertOk()->getContent();

        $this->assertStringContainsString('Örnek Yazılım Ticaret Limited Şirketi', $govde);
        $this->assertStringNotContainsString('DOLDURULACAK: ticaret unvanı', $govde);
    }

    #[Test]
    public function kunye_tamamen_dolduruldugunda_uyari_kutusu_hic_basilmaz(): void
    {
        /*
         * Sayacın SIFIRA inebildiğinin kanıtı. Gizlilik politikası, künye alanı içermeyen tek
         * belge (ölçüldü: eksik=0) — yani bugün bile uyarısız basılıyor. Bu, uyarı kutusunun
         * "her belgede var" gibi bir dekor değil, gerçekten sayıma bağlı olduğunu gösterir.
         */
        $this->get(route('legal.show', 'gizlilik-politikasi'))
            ->assertOk()
            ->assertDontSee('henüz doldurulmadı');
    }

    #[Test]
    public function bilinmeyen_belge_slugu_404_doner(): void
    {
        $this->get('/sozlesme/olmayan-belge')->assertNotFound();
    }
}
