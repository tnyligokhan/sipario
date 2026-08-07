<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\CustomerPhone;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\Tenant;
use App\Models\User;
use Database\Seeders\DemoSeeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * Mağaza inceleme DEMO hesabı (Faz 6 gereksinimi). Seeder içi dolu, AKTİF, telefonlu bir demo bayi
 * kurmalı ki incelemeci mobil uygulamaya girip arayan-tanıma + dolu defteri görebilsin.
 */
class DemoSeederTest extends ApiTestCase
{
    #[Test]
    public function demo_seeder_ici_dolu_aktif_telefonlu_bir_bayi_kurar(): void
    {
        $this->seed(DemoSeeder::class);

        $this->asOwner(function () {
            $patron = User::query()->where('email', DemoSeeder::DEMO_EMAIL)->first();
            $this->assertNotNull($patron, 'Demo patron kullanıcı oluşmalı.');
            // Kimlik geçerli (incelemeci giriş yapabilmeli) + tenant aktif + valid_until gelecekte (kilitlenmez).
            $this->assertTrue(Hash::check(DemoSeeder::DEMO_PASSWORD, $patron->password));
            $tenant = Tenant::query()->findOrFail($patron->tenant_id);
            $this->assertSame('active', $tenant->status->value);
            $this->assertTrue($tenant->valid_until->isFuture());

            // Her müşteri TELEFONLU → arayan-tanıma demosu çalışır (bazısında ikinci hat da var).
            $musteri = Customer::query()->where('tenant_id', $tenant->id)->count();
            $this->assertGreaterThanOrEqual(10, $musteri, 'Demo defteri dolu görünmeli.');
            $this->assertGreaterThanOrEqual(
                $musteri,
                CustomerPhone::query()->where('tenant_id', $tenant->id)->count(),
                'Telefonsuz müşteri kalmamalı — arayan-tanıma demosunun dayanağı bu.',
            );

            // Teslim edilmiş siparişler + defter kayıtları (dolu defter).
            $this->assertGreaterThanOrEqual(10, Order::query()->where('tenant_id', $tenant->id)->count());
            $this->assertGreaterThan(0, LedgerEntry::query()->where('tenant_id', $tenant->id)->count());

            // ÜÇ BAKİYE DURUMUNUN da örneği olmalı: borçlu (+), temiz (0), alacaklı (−).
            // Tasarımın bakiye dili üç renkli; demo veri üçünü de göstermezse bir dal hiç denenmez.
            $sayi = fn (string $op, int $v) => Customer::query()
                ->where('tenant_id', $tenant->id)->where('balance_kurus', $op, $v)->count();
            $this->assertGreaterThan(0, $sayi('>', 0), 'Veresiye borçlu müşteri olmalı.');
            $this->assertGreaterThan(0, $sayi('=', 0), 'Hesabı temiz müşteri olmalı.');
            $this->assertGreaterThan(0, $sayi('<', 0), 'Alacaklı (fazla ödemiş) müşteri olmalı.');
        });
    }

    #[Test]
    public function demo_seeder_her_ekrani_dolduracak_veriyi_kurar(): void
    {
        // Amaç "kayıt var mı" değil, UYGULAMADA BOŞ EKRAN KALMAMASI. Her biri ayrı bir ekranın
        // ya da bir tasarım varyantının tek dayanağı: biri eksikse o ekran demo hesapta boş görünür.
        $this->seed(DemoSeeder::class);

        $this->asOwner(function () {
            $tenant = Tenant::query()->where('slug', DemoSeeder::DEMO_TENANT_CODE)->firstOrFail();
            $say = fn (string $tablo) => DB::table($tablo)->where('tenant_id', $tenant->id)->count();

            $this->assertGreaterThanOrEqual(2, $say('products'), 'Ürünler ekranı');
            $this->assertGreaterThanOrEqual(1, $say('call_logs'), 'Çağrı geçmişi + "Son Arama" kutusu');
            $this->assertGreaterThanOrEqual(1, $say('exempt_numbers'), 'Muaf Telefonlar ekranı');
            $this->assertGreaterThanOrEqual(1, $say('day_closings'), 'Gün Sonu → Arşiv bölümü');
            $this->assertSame(1, $say('tenant_settings'), 'İşletme Profili formu');

            // Ekip: en az iki AKTİF kurye (atama + kurye sekmesi + gün sonu kurye kapsamı) ve
            // en az bir PASİF kurye ("Pasif" rozeti boş listeyle sınanamaz).
            $kurye = fn (string $durum) => DB::table('users')->where('tenant_id', $tenant->id)
                ->where('role', 'kurye')->where('status', $durum)->count();
            $this->assertGreaterThanOrEqual(2, $kurye('active'));
            $this->assertGreaterThanOrEqual(1, $kurye('disabled'));

            // Sipariş varyantları: açık · teslim · iptal + müşterisiz TEZGÂH satışı.
            $durum = fn (string $s) => DB::table('orders')->where('tenant_id', $tenant->id)
                ->where('status', $s)->count();
            $this->assertGreaterThan(0, $durum('open'));
            $this->assertGreaterThan(0, $durum('delivered'));
            $this->assertGreaterThan(0, $durum('cancelled'));
            $this->assertGreaterThan(0, DB::table('orders')->where('tenant_id', $tenant->id)
                ->whereNull('customer_id')->count(), 'Tezgâh satışı (müşterisiz sipariş)');

            // Dört ödeme tipi de geçmeli — gün sonu kasa özetinin her satırı dolsun.
            foreach (['nakit', 'kart', 'havale', 'veresiye'] as $odeme) {
                $this->assertGreaterThan(0, DB::table('orders')->where('tenant_id', $tenant->id)
                    ->where('payment_type', $odeme)->count(), "Ödeme tipi: $odeme");
            }

            // Rota denemesi için: kontör > 0 VE koordinatlı en az iki adres (yoksa "Oto Sırala"
            // düğmesi çizilmez ya da sıralayacak durak bulamaz).
            $this->assertGreaterThan(0, $tenant->route_credits);
            $this->assertGreaterThanOrEqual(2, DB::table('customer_addresses')
                ->where('tenant_id', $tenant->id)->whereNotNull('lat')->count());

            // Defterde DÜZELTME (ters kayıt) örneği — append-only düzeltmenin görünür kanıtı.
            $this->assertGreaterThan(0, DB::table('ledger_entries')->where('tenant_id', $tenant->id)
                ->whereNotNull('reverses_entry_id')->count());
        });
    }

    #[Test]
    public function demo_seeder_idempotenttir_ikinci_kosuda_ikizlemez(): void
    {
        $this->seed(DemoSeeder::class);
        $this->seed(DemoSeeder::class); // ikinci kez — atlanmalı

        $this->asOwner(function () {
            $this->assertSame(1, User::query()->where('email', DemoSeeder::DEMO_EMAIL)->count());
        });
    }
}
