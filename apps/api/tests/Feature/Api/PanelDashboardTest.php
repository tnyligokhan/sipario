<?php

namespace Tests\Feature\Api;

use App\Models\AdminUser;
use App\Models\Order;
use App\Models\Tenant;
use App\Panel\PanelDashboardService;
use App\Support\Provisioning;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5c-3 · D1 — panel GENEL BAKIŞ panosu. TAMAMEN SALT-OKUNUR: yeni bir yazma yüzeyi açmaz.
 *
 * Panonun asıl riski yanlış sayı göstermesidir: "aktif bayi" dediği küme ile sunucunun push'ta
 * yazmaya izin verdiği küme AYNI olmalıdır. Buradaki en önemli test bu ikisini aynı senaryoda
 * karşılaştırır (pano "yazabilir değil" derken push da 'locked' döner).
 */
class PanelDashboardTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private function service(): PanelDashboardService
    {
        return new PanelDashboardService('pgsql_panel');
    }

    private function makeAdmin(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Pano Admin', 'email' => 'pano-admin@sipario.test',
            'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    /** @param array<string, mixed> $attrs */
    private function setTenant(string $tenantId, array $attrs): void
    {
        Provisioning::asOwner(fn () => Tenant::query()->whereKey($tenantId)->update($attrs));
    }

    private function seedOrder(string $tenantId, Carbon $at): void
    {
        Provisioning::asOwner(fn () => Order::query()->create([
            'id' => (string) Str::uuid7(), 'tenant_id' => $tenantId,
            'status' => 'open', 'total_kurus' => 0, 'occurred_at' => $at,
        ]));
    }

    #[Test]
    public function ozet_durum_dagilimini_ve_toplami_dogru_sayar(): void
    {
        $this->makeTenant('a'); // active
        $b = $this->makeTenant('b');
        $c = $this->makeTenant('c');
        $d = $this->makeTenant('d');
        $this->setTenant($b['tenant']->id, ['status' => 'trial', 'valid_until' => now()->addDays(10)]);
        $this->setTenant($c['tenant']->id, ['status' => 'locked', 'locked_at' => now()]);
        $this->setTenant($d['tenant']->id, ['status' => 'suspended', 'locked_at' => now()]);

        $ozet = $this->service()->ozet();

        $this->assertSame(4, $ozet['toplam']);
        $this->assertSame(1, $ozet['dagilim']['active']);
        $this->assertSame(1, $ozet['dagilim']['trial']);
        $this->assertSame(1, $ozet['dagilim']['locked']);
        $this->assertSame(1, $ozet['dagilim']['suspended']);
        $this->assertSame(2, $ozet['yazabilir'], 'Yalnız active + trial (süresi dolmamış) yazabilir sayılmalı.');
    }

    #[Test]
    public function panonun_yazabilir_tanimi_sunucunun_kilit_karariyla_ayni(): void
    {
        // Bu testin değeri: pano ile SyncService::resolveLock'un aynı kümeyi göstermesi. Panonun
        // "aktif" dediği bayiye push kilitli dönerse pano yalan söylüyor demektir.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->assertSame(1, $this->service()->ozet()['yazabilir']);
        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Önce'])])
            ->assertJsonPath('results.0.status', 'applied');

        // Süresi geçmiş bir bayi: status hâlâ 'active' ama valid_until geçmişte.
        $this->setTenant($a['tenant']->id, ['valid_until' => now()->subDay()]);

        $this->assertSame(0, $this->service()->ozet()['yazabilir'], 'Süresi geçen bayi yazabilir sayılmamalı.');
        $this->pushEvents($token, [$this->customerUpsert(['name' => 'Sonra'])])
            ->assertJsonPath('results.0.status', 'locked');
    }

    #[Test]
    public function biten_denemeler_yalnizca_yedi_gun_penceresini_listeler(): void
    {
        $yakin = $this->makeTenant('yakin');
        $uzak = $this->makeTenant('uzak');
        $gecmis = $this->makeTenant('gecmis');

        $this->setTenant($yakin['tenant']->id, ['status' => 'trial', 'trial_ends_at' => now()->addDays(3), 'valid_until' => now()->addDays(3)]);
        $this->setTenant($uzak['tenant']->id, ['status' => 'trial', 'trial_ends_at' => now()->addDays(20), 'valid_until' => now()->addDays(20)]);
        $this->setTenant($gecmis['tenant']->id, ['status' => 'trial', 'trial_ends_at' => now()->subDays(2), 'valid_until' => now()->subDays(2)]);

        $idler = $this->service()->bitenDenemeler(7)->pluck('id')->all();

        $this->assertContains($yakin['tenant']->id, $idler, '3 gün kalan deneme listede olmalı.');
        $this->assertNotContains($uzak['tenant']->id, $idler, '20 gün kalan deneme listede OLMAMALI.');
        $this->assertNotContains($gecmis['tenant']->id, $idler, 'Süresi geçmiş deneme "bitmek üzere" değildir.');
    }

    #[Test]
    public function churn_riski_siparis_gireni_disarida_birakir_hic_girmeyeni_isaretler(): void
    {
        $calisan = $this->makeTenant('calisan');   // dün sipariş girdi → risk YOK
        $sessiz = $this->makeTenant('sessiz');     // 10 gün önce girdi → RİSK
        $hicbir = $this->makeTenant('hicbir');     // hiç girmedi → RİSK
        $kilitli = $this->makeTenant('kilitli');   // hiç girmedi ama kilitli → listede YOK (zaten bizde)

        $this->seedOrder($calisan['tenant']->id, now()->subDay());
        $this->seedOrder($sessiz['tenant']->id, now()->subDays(10));
        $this->setTenant($kilitli['tenant']->id, ['status' => 'locked', 'locked_at' => now()]);

        $risk = $this->service()->churnRiski(3);
        $idler = $risk->pluck('id')->all();

        $this->assertNotContains($calisan['tenant']->id, $idler, 'Dün sipariş giren bayi riskli değil.');
        $this->assertContains($sessiz['tenant']->id, $idler, '10 gündür sipariş girmeyen bayi riskli.');
        $this->assertContains($hicbir['tenant']->id, $idler, 'Hiç sipariş girmemiş bayi riskli.');
        $this->assertNotContains($kilitli['tenant']->id, $idler, 'Kilitli bayi churn listesine girmez.');

        // "Hiç başlamamış" ile "bıraktı" ayrımı satırda görünür olmalı.
        $hicbirSatir = $risk->firstWhere('id', $hicbir['tenant']->id);
        $sessizSatir = $risk->firstWhere('id', $sessiz['tenant']->id);
        $this->assertNull($hicbirSatir->son_siparis, 'Hiç sipariş girmemişte son_siparis null olmalı.');
        $this->assertNotNull($sessizSatir->son_siparis, 'Eskiden girmişte son sipariş tarihi dolu olmalı.');
    }

    #[Test]
    public function yenileme_takvimi_ufku_disini_eler_ve_haftalik_kovalara_boler(): void
    {
        $bugun = $this->makeTenant('bugun');
        $ikinciHafta = $this->makeTenant('ikinci');
        $ufukDisi = $this->makeTenant('ufuk');
        $gecmis = $this->makeTenant('gecmis');

        $this->setTenant($bugun['tenant']->id, ['valid_until' => now()->addDays(2)]);
        $this->setTenant($ikinciHafta['tenant']->id, ['valid_until' => now()->addDays(9)]);
        $this->setTenant($ufukDisi['tenant']->id, ['valid_until' => now()->addDays(90)]);
        $this->setTenant($gecmis['tenant']->id, ['valid_until' => now()->subDay()]);

        $takvim = $this->service()->yenilemeTakvimi(60);
        $idler = $takvim->pluck('id')->all();

        $this->assertContains($bugun['tenant']->id, $idler);
        $this->assertContains($ikinciHafta['tenant']->id, $idler);
        $this->assertNotContains($ufukDisi['tenant']->id, $idler, '90 gün sonrası 60 günlük ufkun dışındadır.');
        $this->assertNotContains($gecmis['tenant']->id, $idler, 'Geçmiş tarih yenileme takviminde değildir.');

        $kovalar = $this->service()->haftalikKovalar($takvim, 60);
        $this->assertCount(9, $kovalar, '60 gün 7 günlük 9 kovaya bölünür.');
        $this->assertSame(1, $kovalar[0]['adet'], '2 gün sonrası ilk kovada.');
        $this->assertSame(1, $kovalar[1]['adet'], '9 gün sonrası ikinci kovada.');
        $this->assertSame(0, $kovalar[5]['adet'], 'Boş hafta kaybolmaz, 0 olarak döner.');
    }

    // --- Ekran (Livewire) ---------------------------------------------------------------

    #[Test]
    public function pano_admin_icin_acilir_ve_riskli_bayiyi_gosterir(): void
    {
        $riskli = $this->makeTenant('riskli');
        $admin = $this->makeAdmin();

        $this->actingAs($admin, 'admin')->get('/panel')
            ->assertOk()
            ->assertSee('Genel Bakış')
            ->assertSee('Churn riski')
            ->assertSee($riskli['tenant']->name);
    }

    #[Test]
    public function pano_oturumsuz_acilmaz(): void
    {
        $this->get('/panel')->assertRedirect(route('panel.login'));
    }
}
