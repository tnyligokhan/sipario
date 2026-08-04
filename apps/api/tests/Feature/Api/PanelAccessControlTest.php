<?php

namespace Tests\Feature\Api;

use App\Livewire\Panel\AdminUsers;
use App\Models\AdminUser;
use App\Panel\PanelAdminService;
use App\Panel\PanelWriteService;
use App\Support\Provisioning;
use Illuminate\Database\QueryException;
use Illuminate\Routing\Route as RouteEntry;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * FAZ 5c-3 — panelin ERİŞİM SINIRI: kim girebilir ve panel neyi ASLA yazamaz.
 *
 * Mevcut testler tek tek eylemleri kanıtlıyor (PanelAdminTest rol kapılarını, PanelTest iki route'un
 * oturum istediğini). Buradaki testler farklı bir soruyu sorar: KAPSAM. Panel yüzeyi 5c-3'te iki
 * route'tan ona çıktı ve her yeni route yeni bir sızıntı yüzeyidir; tek tek yazılan testler yeni
 * eklenen route'u göremez. Bu yüzden buradaki denetimler route tablosundan ve grant matrisinden
 * TÜRETİLİR — kapsam dışı kalan bir şey eklendiğinde test kendiliğinden kırılır.
 */
class PanelAccessControlTest extends ApiTestCase
{
    private function admin(string $rol = 'superadmin', string $email = 'ac-super@sipario.test'): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Erişim Testi', 'email' => $email, 'password' => 'panel-secret', 'role' => $rol,
        ]));
    }

    /**
     * `auth:admin` altındaki TÜM GET route'ları, gerçek parametreleriyle. Route tablosundan
     * türetilir: yeni bir panel sayfası eklendiğinde bu liste kendiliğinden büyür ve aşağıdaki
     * testler onu da denetler.
     *
     * @return list<string>
     */
    private function korunanUrller(string $tenantId): array
    {
        $urller = [];

        /** @var RouteEntry $route */
        foreach (Route::getRoutes() as $route) {
            $ad = $route->getName();
            if ($ad === null || ! str_starts_with($ad, 'panel.') || ! in_array('GET', $route->methods(), true)) {
                continue;
            }
            if (! in_array('auth:admin', $route->gatherMiddleware(), true)) {
                continue; // panel.login — kapı dışı, bilerek
            }

            $urller[] = route($ad, ['tenant' => $tenantId]);
        }

        return $urller;
    }

    #[Test]
    public function panelin_butun_korunan_sayfalari_oturum_ister(): void
    {
        // KAPSAM TESTİ: PanelTest yalnız iki route'a bakıyordu; 5c-3'te yüzey ona çıktı ve bunların
        // arasında müşteri adı/telefonu/adresi indiren CSV route'ları var. Route tablosundan
        // türetiliyor ki auth'suz eklenen yeni bir sayfa burada yakalansın.
        $a = $this->makeTenant('a');
        $urller = $this->korunanUrller($a['tenant']->id);

        $this->assertGreaterThanOrEqual(9, count($urller), 'Panel yüzeyi beklenenden küçük — route adları değişmiş olabilir.');

        foreach ($urller as $url) {
            $this->get($url)->assertRedirect(route('panel.login'), "Oturumsuz erişim engellenmeli: {$url}");
        }
    }

    #[Test]
    public function pasiflestirilen_admin_hicbir_panel_sayfasina_giremez(): void
    {
        // PanelAdminTest pasif hesabın provider'dan çözülemediğini kanıtlıyor; burada bunun HER
        // korunan sayfaya yansıdığını görüyoruz. Oturum GERÇEKTEN açılır (login), sonra hesap
        // pasifleştirilir — actingAs kullanılmaz, o provider'ı atlar ve kapsamı görmezdi.
        $a = $this->makeTenant('a');
        $super = $this->admin();
        $destek = $this->admin('support', 'ac-destek@sipario.test');

        $this->post(route('panel.login'));
        $this->assertTrue(Auth::guard('admin')->attempt(['email' => 'ac-destek@sipario.test', 'password' => 'panel-secret']));

        (new PanelAdminService('pgsql_panel'))->aktiflik($destek->id, false, $super->id);
        $this->app['auth']->forgetGuards();

        foreach ($this->korunanUrller($a['tenant']->id) as $url) {
            $this->get($url)->assertRedirect(route('panel.login'), "Pasif hesap girememeli: {$url}");
        }
    }

    #[Test]
    public function bayinin_kullanicisi_panel_sayfalarina_giremez(): void
    {
        // Bayi kullanıcısı ayrı guard'dadır (users tablosu, `web`/sanctum). Bir bayi oturumunun
        // panel guard'ında geçerli sayılmadığını route seviyesinde de görmek gerekir: guard
        // yapılandırması yanlışlıkla `auth` (varsayılan) yapılırsa bu test kırılır.
        $a = $this->makeTenant('a');

        $this->actingAs($a['patron']); // varsayılan (web) guard — panel guard'ı DEĞİL

        foreach ($this->korunanUrller($a['tenant']->id) as $url) {
            $this->get($url)->assertRedirect(route('panel.login'), "Bayi kullanıcısı panele girememeli: {$url}");
        }
    }

    #[Test]
    public function destek_rolu_hesap_yonetimi_eylemlerini_oturum_icinde_de_calistiramaz(): void
    {
        // PanelAdminTest ekranın `mount`ta kapandığını gösteriyor. Buradaki soru farklı: bileşen
        // MEŞRU biçimde açıldıktan SONRA rol düşerse ne olur? Livewire mount'u yalnız ilk istekte
        // koşar; sonraki eylem istekleri hidratlanmış bileşene gider. Kapı yalnız mount'ta olsaydı,
        // rolü düşürülmüş (ya da pasifleştirilmiş) bir oturum açık sekmesinden hesap açmayı
        // sürdürebilirdi. Kapının HER eylemde tekrarlandığını kanıtlıyoruz.
        $super = $this->admin();
        $destek = $this->admin('support', 'ac-destek@sipario.test');

        // Her eylem için TAZE bir bileşen: 403 dönen bir Livewire cevabında anlık görüntü (snapshot)
        // yoktur, aynı örnek üzerinden ikinci bir eylem çağrılamaz.
        $eylemler = [
            fn ($b) => $b->set('ad', 'Gizli Hesap')->set('email', 'gizli@sipario.test')->set('rol', 'superadmin')->call('ekle'),
            fn ($b) => $b->call('aktiflik', $super->id, false),
            fn ($b) => $b->call('rolDegistir', $destek->id, 'superadmin'),
        ];

        foreach ($eylemler as $eylem) {
            $this->actingAs($super, 'admin');
            $bilesen = Livewire::test(AdminUsers::class)->assertOk(); // meşru açılış: mount geçer

            // Oturum artık destek rolünde (rol düşürüldü / başka hesap devraldı). Guard'a doğrudan
            // kullanıcı yazıyoruz; `actingAs` Livewire'ın aktör durumunu da tazeler ve eylem
            // anındaki rolü değil test başındaki rolü görürdük.
            Auth::guard('admin')->setUser($destek);

            $eylem($bilesen)->assertForbidden();
        }

        // Hiçbiri sızmadı: yeni hesap yok, roller yerinde, süper hâlâ aktif.
        $this->assertSame(2, DB::connection('pgsql_panel')->table('admin_users')->count(), 'Yeni hesap açılmamalı.');
        $this->assertSame('support', DB::connection('pgsql_panel')->table('admin_users')->where('id', $destek->id)->value('role'));
        $this->assertNull(DB::connection('pgsql_panel')->table('admin_users')->where('id', $super->id)->value('disabled_at'));
    }

    // --- Salt-okunurluk: DB izni (kırmızı çizgi #1) --------------------------------------

    /**
     * İş verisi tabloları. PanelTest'in matrisi 11 tabloydu ve 5c/6. fazda eklenen tablolar
     * (ayar/muaf numara/çağrı günlüğü/gün sonu/kurye konumu) ile senkron altyapısı dışarıda
     * kalmıştı — panel bunlara SELECT bile alamaz, dolayısıyla yazma denemesi de reddedilmeli.
     *
     * @return list<string>
     */
    private const IS_TABLOLARI = [
        'customers', 'customer_phones', 'customer_addresses', 'products',
        'orders', 'order_lines', 'order_events', 'ledger_entries',
        'cash_handovers', 'devices', 'users',
        // 5c-2 sonrası eklenenler — matriste HİÇ yoktu:
        'tenant_settings', 'exempt_numbers', 'call_logs', 'day_closings',
        'courier_locations', 'sync_changes',
    ];

    /**
     * Verilen ifadenin panel rolüyle 42501 (permission denied) ile reddedildiğini doğrular.
     *
     * TEK TESTTE DÖNGÜ, veri sağlayıcı DEĞİL: her veri seti ayrı bir PHPUnit testidir ve
     * ApiTestCase'in setUp'ı her testte uygulamayı tazeleyip TRUNCATE atar. 17 tablo × 2 eksen = 34
     * kurulum, tek bir izin denetimi için çok pahalıdır ve her biri yeni DB bağlantısı açtığı için
     * kümenin bağlantı tavanını zorlar (Postgres max_connections küme geneli, testler paylaşır).
     * İzin denetiminin veriye ihtiyacı yok — tek kurulumda hepsini denemek hem doğru hem ucuz.
     */
    private function yazmaReddedilir(string $tablo, string $sql): void
    {
        try {
            DB::connection('pgsql_panel')->statement($sql);
            $this->fail("{$tablo}: panel rolüyle yazma reddedilmeliydi → {$sql}");
        } catch (QueryException $e) {
            $this->assertSame('42501', $e->getCode(),
                "{$tablo} için permission denied (42501) beklenir, gelen: {$e->getCode()} — {$sql}");
        }
    }

    #[Test]
    public function panel_rolu_is_verisine_insert_yapamaz(): void
    {
        // EKSİK EKSEN: mevcut matris UPDATE ve DELETE'i deniyordu, INSERT'i HİÇ denemiyordu.
        // Panele yanlışlıkla INSERT verilseydi "panel sipariş/para kaydı yazamaz" kırmızı çizgisi
        // sessizce delinirdi — UPDATE testleri bunu göremezdi.
        //
        // Sözdizimi bilerek eksik (kolon listesi yok): izin denetimi Postgres'te ayrıştırmadan SONRA
        // ama çalıştırmadan ÖNCE yapılır, yani yetki VARSA 42501 değil başka bir hata alırız ve test
        // yine kırılır. Böylece "izin yok" ile "sorgu zaten geçersiz" birbirine karışmaz.
        foreach (self::IS_TABLOLARI as $tablo) {
            $this->yazmaReddedilir($tablo, "INSERT INTO {$tablo} DEFAULT VALUES");
        }
    }

    #[Test]
    public function panel_rolu_yeni_is_tablolarina_da_yazamaz(): void
    {
        // UPDATE/DELETE eksenleri, PanelTest'in kaçırdığı 6 tabloyu da kapsayacak şekilde.
        foreach (self::IS_TABLOLARI as $tablo) {
            $this->yazmaReddedilir($tablo, "UPDATE {$tablo} SET tenant_id = tenant_id");
            $this->yazmaReddedilir($tablo, "DELETE FROM {$tablo}");
        }
    }

    #[Test]
    public function panel_rolunun_yetki_matrisi_beklenenden_genis_degil(): void
    {
        // Tek tek tablo denemek yeni bir tabloyu kaçırabilir; bu test TERSTEN bakar: panelin sahip
        // OLDUĞU tüm hakları veritabanından okur ve beklenen listeyle karşılaştırır. Bir migration
        // yanlışlıkla `GRANT ALL` verirse burada patlar, hangi tablo olduğunu bilmemize gerek kalmaz.
        $haklar = DB::connection('pgsql_owner')->select(
            "SELECT table_name, privilege_type FROM information_schema.role_table_grants
             WHERE grantee = 'sipario_panel' AND table_schema = 'public'
             ORDER BY table_name, privilege_type"
        );

        $matris = [];
        foreach ($haklar as $hak) {
            $matris[$hak->table_name][] = $hak->privilege_type;
        }

        $yazabildikleri = array_keys(array_filter(
            $matris,
            fn (array $izinler) => array_intersect($izinler, ['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE']) !== [],
        ));
        sort($yazabildikleri);

        // Panel YALNIZ bu üçüne yazabilir: abonelik/durum (tenants), panel hesapları (admin_users),
        // denetim günlüğü (panel_audit). Hepsi bayi-üstü yönetim verisidir — İŞ VERİSİ DEĞİL.
        $this->assertSame(['admin_users', 'panel_audit', 'tenants'], $yazabildikleri,
            'Panel rolü yalnız yönetim tablolarına yazabilmeli; iş verisine yazma hakkı kırmızı çizgidir.');

        // İş verisinde okuma dışında hiçbir hak olmamalı.
        foreach (['customers', 'orders', 'order_lines', 'ledger_entries', 'cash_handovers', 'products'] as $tablo) {
            $this->assertSame(['SELECT'], array_values(array_unique($matris[$tablo] ?? [])),
                "{$tablo} üzerinde SELECT dışında hak olmamalı.");
        }

        // Silme HİÇBİR tabloda yok (panel_audit ve admin_users dahil — günlük ve hesap silinmez).
        foreach ($matris as $tablo => $izinler) {
            $this->assertNotContains('DELETE', $izinler, "{$tablo} üzerinde DELETE hakkı olmamalı.");
        }
    }

    #[Test]
    public function panelde_siparis_ve_para_yazma_yuzeyi_hic_yok(): void
    {
        // "Böyle bir route/action hiç var olmamalı" ancak TERSTEN kanıtlanabilir: yüzeyin tamamını
        // sayıp beklenen listeyle karşılaştırmak. Sipariş/defter/kasa yazan bir route eklenirse bu
        // test kırılır ve eklendiği anda görülür — 42501 testleri ise yalnız DB katmanını korur,
        // owner bağlantısıyla yazan bir route'u göremezdi.
        $adlar = [];
        /** @var RouteEntry $route */
        foreach (Route::getRoutes() as $route) {
            $ad = $route->getName();
            if ($ad !== null && str_starts_with($ad, 'panel.')) {
                $adlar[] = $ad;
            }
        }
        sort($adlar);

        // 2026-08-04 eklendi: panel.finance (GelirGider) · panel.notifications (Bildirimler,
        // havale bildirimi eşleştirme) · panel.packages (Paketler, ek paket kataloğu+tanımlama).
        // Üçü de ABONELİK/ŞİRKET verisine (plans/addon_*/expenses/payment_notifications/
        // subscription_payments) dokunur — customers/orders/order_lines/ledger_entries/
        // cash_handovers/products'a hiçbir yazma çağrısı yok (grep doğrulandı); kırmızı çizgi #2 delinmedi.
        $this->assertSame([
            'panel.admins',
            'panel.audit',
            'panel.csv.sablon',
            'panel.dashboard',
            'panel.finance',
            'panel.login',
            'panel.logout',
            'panel.notifications',
            'panel.packages',
            'panel.payments',
            'panel.tenant',
            'panel.tenant.csv.musteriler',
            'panel.tenant.csv.siparisler',
            'panel.tenant.export',
            'panel.tenant.import',
            'panel.tenants',
        ], $adlar, 'Panel route yüzeyi değişmiş: yeni route sipariş/para yazıyorsa kırmızı çizgi delinmiştir.');

        // Yazma servisinin yüzeyi de kapalı: yalnız müşteri ve ürün. Sipariş/defter/kasa yok.
        $yazmaMetotlari = array_map(
            fn (\ReflectionMethod $m) => $m->getName(),
            (new \ReflectionClass(PanelWriteService::class))->getMethods(\ReflectionMethod::IS_PUBLIC),
        );
        sort($yazmaMetotlari);

        $this->assertSame(
            ['__construct', 'musteriKaraListe', 'musteriKaydet', 'urunAktiflik', 'urunKaydet'],
            $yazmaMetotlari,
            'Panel yazma servisi yalnız müşteri/ürün yazmalı; sipariş veya para kaydı yazan bir metot eklenmiş.'
        );
    }
}
