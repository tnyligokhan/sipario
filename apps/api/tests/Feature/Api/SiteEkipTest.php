<?php

namespace Tests\Feature\Api;

use App\Livewire\Site\Ekip;
use App\Livewire\Site\Forms\IsletmeFormu;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Livewire\Livewire;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * BAYİNİN WEB PANELİNDEN EKİP YÖNETİMİ (kullanıcı şikâyeti 6: "kurye hesaplarını web panelinden
 * ekleyebilmeli, silebilmeli").
 *
 * Bu dosya ürünün en pahalı dört kuralını sınar; dördü de sessizce bozulabilecek cinstendir:
 *
 *  1. KOTA SUNUCUDA GERÇEKTİR. `tenants.courier_limit` doluyken web'den kurye AÇILAMAZ ve
 *     pasif bir kuryeyi GERİ AÇMAK da kotaya çarpar — yoksa "birini kapat, ötekini aç" ile
 *     limit sonsuza kadar aşılırdı (kapatma kotayı serbest bırakır, açma serbest olsaydı).
 *
 *  2. WEB YAZIMI LWW DAMGASI BIRAKIR. `users` senkron varlığıdır; damgasız yazım telefonun
 *     bekleyen `user_profile` olayı tarafından EZİLİR ve pasifleştirilen kurye kendiliğinden
 *     geri açılır. Damga olmadan bu arıza HİÇBİR ekranda görünmez.
 *
 *  3. PASİFLEŞTİRME GERÇEKTEN GİRİŞİ KAPATIR — hem yeni girişi hem de AÇIK OTURUMU. Token
 *     yaşamaya devam ederse "devre dışı bıraktım" cümlesi yalandır.
 *
 *  4. KIRMIZI ÇİZGİ #1. Eylemler istemciden kullanıcı KİMLİĞİ alır; başka bayinin kuryesi
 *     bu kimlikle gösterilse bile dokunulamaz.
 */
class SiteEkipTest extends ApiTestCase
{
    use BuildsSyncEvents;

    // ── Kota ─────────────────────────────────────────────────────────────────

    #[Test]
    public function kota_doluyken_web_den_kurye_acilamaz(): void
    {
        // makeTenant bir aktif kurye açar; limiti 1'e çekince kota DOLUdur.
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('kota');
        $this->limitYaz($tenant, 1);

        Livewire::actingAs($patron, 'web')->test(Ekip::class)
            ->set('form.ad', 'Yeni Kurye')
            ->set('form.kullaniciAdi', 'yenikurye')
            ->set('form.parola', '1234')
            ->call('kuryeEkle')
            ->assertHasErrors('form.kota')
            // Kota dolduğunda çıkış yolu gösterilmeli ve o yol TEK yere gitmeli: paket katalogu
            // "Kullanım ve ek paketler" bölümünde duruyor (hesap ajanıyla kararlaştırıldı).
            ->assertSee('Ek kurye paketi al')
            ->assertSee('bolum=hak', escape: false);

        $this->assertSame(1, $this->kuryeSayisi($tenant->id), 'Kota dolu olmasına rağmen kurye açıldı.');
    }

    #[Test]
    public function kota_musaitken_web_den_kurye_acilir_ve_giris_yapabilir(): void
    {
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('acilis');
        $this->limitYaz($tenant, 3);

        Livewire::actingAs($patron, 'web')->test(Ekip::class)
            ->set('form.ad', 'Ahmet Kurye')
            ->set('form.kullaniciAdi', 'ahmet')
            ->set('form.parola', 'sifre1234')
            ->set('form.telefon', '05321112233')
            ->call('kuryeEkle')
            ->assertHasNoErrors();

        /** @var User $yeni */
        $yeni = $this->asOwner(fn () => User::on('pgsql_owner')
            ->where('tenant_id', $tenant->id)->where('username', 'ahmet')->firstOrFail());

        $this->assertSame('kurye', $yeni->role->value);
        $this->assertSame('active', $yeni->status);
        // Parola ASLA düz saklanmaz (KVKK + kimlik yüzeyi).
        $this->assertNotSame('sifre1234', $yeni->password);

        // Hesap gerçekten çalışıyor: mobilden firma kodu + kullanıcı adıyla girilebiliyor.
        $this->postJson('/api/v1/auth/login', $this->girisGovdesi($tenant, $yeni, 'sifre1234'))
            ->assertOk();
    }

    #[Test]
    public function pasif_kuryeyi_geri_acmak_da_kotaya_carpar(): void
    {
        // "Birini kapat, ötekini aç" ile limitin aşılması: kapatma kotayı serbest bırakır
        // (KuryeKotasi yalnız active sayar), bu yüzden GERİ AÇMA da kapıdan geçmelidir.
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('geriac');
        $this->limitYaz($tenant, 1);
        $eski = $this->makeTenantKuryesi($tenant, 'eski', 'disabled');

        Livewire::actingAs($patron, 'web')->test(Ekip::class)
            ->call('durumDegistir', $eski->id)
            ->assertDispatched('bildir');

        $this->assertSame('disabled', $this->tazeKullanici($eski->id)->status,
            'Kota doluyken pasif kurye geri açıldı — limit aşıldı.');
    }

    #[Test]
    public function suresi_dolmus_bayi_web_den_kurye_acamaz(): void
    {
        // Süresi dolmuş bayi bu SİTEYE girebilir (ödeme yapmak için — Login'in API'den bilinçli
        // farkı) ama YAZAMAZ. Hesap açma provizyon yolundan gider ve orada kilit kontrolü yoktur;
        // kapı bileşenin içinde olmasa süresi biten bayi kurye açmaya devam ederdi.
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('kilitli');
        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenant->id)->update([
            'courier_limit' => 5,
            'valid_until' => now()->subDay(),
        ]));

        Livewire::actingAs($patron, 'web')->test(Ekip::class)
            ->set('form.ad', 'Kilitli Kurye')
            ->set('form.kullaniciAdi', 'kilitli')
            ->set('form.parola', '1234')
            ->call('kuryeEkle')
            ->assertHasErrors('form.kota');

        $this->assertSame(1, $this->kuryeSayisi($tenant->id), 'Süresi dolmuş bayi kurye açtı.');
    }

    // ── Senkron damgası (LWW) ────────────────────────────────────────────────

    #[Test]
    public function web_den_pasiflestirme_lww_damgasi_birakir(): void
    {
        ['tenant' => $tenant, 'patron' => $patron, 'kurye' => $kurye] = $this->makeTenant('damga');

        Livewire::actingAs($patron, 'web')->test(Ekip::class)->call('durumDegistir', $kurye->id);

        $taze = $this->tazeKullanici($kurye->id);
        $this->assertSame('disabled', $taze->status);
        $this->assertNotNull($taze->updated_occurred_at, 'Web yazımı damgasız kaldı: LWW bunu bayat sayar.');
        $this->assertSame(IsletmeFormu::SITE_DEVICE_ID, $taze->updated_device_id);
    }

    #[Test]
    public function telefonun_eski_yazimi_pasiflestirmeyi_geri_acamaz(): void
    {
        // KAYITLI TUZAK: "cihazsız yazım LWW'de sessizce bayat kalır". Web pasifleştirir;
        // telefonun ÖNCEDEN kuyruğa girmiş (daha eski) profil yazımı sunucuya ulaşır. Damga
        // yoksa o olay kazanır ve kurye kendiliğinden geri açılır — hiçbir ekranda görünmeden.
        ['patron' => $patron, 'kurye' => $kurye] = $this->makeTenant('bayat');
        $token = $this->tokenFor($patron);

        Livewire::actingAs($patron, 'web')->test(Ekip::class)->call('durumDegistir', $kurye->id);

        $this->pushEvents($token, [$this->userProfileUpsert(
            ['id' => $kurye->id, 'name' => $kurye->name, 'status' => 'active'],
            ['occurred_at' => now()->subMinutes(5)->toIso8601String()],
        )])->assertOk()->assertJsonPath('results.0.status', 'stale');

        $this->assertSame('disabled', $this->tazeKullanici($kurye->id)->status,
            'Telefonun ESKİ yazımı web pasifleştirmesini ezdi.');
    }

    #[Test]
    public function web_den_acilan_kurye_telefona_team_blogu_ile_iner(): void
    {
        // `users` sync_changes delta günlüğünde YOKTUR; her senkron yanıtındaki `team` bloğuyla
        // toptan tazelenir. Web'den açılan hesabın telefona inip inmediğini kanıtlayan tek yer.
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('team');
        $this->limitYaz($tenant, 3);
        $token = $this->tokenFor($patron);

        Livewire::actingAs($patron, 'web')->test(Ekip::class)
            ->set('form.ad', 'Veli Kurye')
            ->set('form.kullaniciAdi', 'veli')
            ->set('form.parola', '1234')
            ->call('kuryeEkle')
            ->assertHasNoErrors();

        $team = $this->pullSince($token)->assertOk()->json('team');
        $veli = collect($team)->firstWhere('username', 'veli');

        $this->assertNotNull($veli, 'Web\'den açılan kurye telefonun ekip listesine inmedi.');
        $this->assertSame('active', $veli['status']);
        $this->assertSame('kurye', $veli['role']);
    }

    // ── Pasifleştirme = giriş kapanır ────────────────────────────────────────

    #[Test]
    public function pasiflestirilen_kurye_giris_yapamaz_ve_acik_oturumu_duser(): void
    {
        ['tenant' => $tenant, 'patron' => $patron, 'kurye' => $kurye] = $this->makeTenant('kapat');
        $kuryeToken = $this->tokenFor($kurye);

        // Kurye şu an gerçekten çalışıyor.
        $this->asToken($kuryeToken)->getJson('/api/v1/sync/pull?since=0')->assertOk();

        Livewire::actingAs($patron, 'web')->test(Ekip::class)->call('durumDegistir', $kurye->id);

        // Eylemin GERÇEKTEN koştuğunu önce burada kanıtla: aşağıdaki 403/401 beklentileri, eylem
        // hiç çalışmasa da "giriş açık" diye kırılırdı ve hata yanlış yere bakılarak aranırdı.
        $this->assertSame('disabled', $this->tazeKullanici($kurye->id)->status);

        $this->postJson('/api/v1/auth/login', $this->girisGovdesi($tenant, $kurye))
            ->assertStatus(403);

        // AÇIK OTURUM DA DÜŞER: token yaşamaya devam etseydi "devre dışı bıraktım" yalan olurdu
        // (TeamController'ın parola değişiminde yaptığının aynısı).
        $this->asToken($kuryeToken)->getJson('/api/v1/sync/pull?since=0')->assertStatus(401);
    }

    #[Test]
    public function pasiflestirme_kaydi_silmez_yalnizca_devre_disi_birakir(): void
    {
        // Kuryenin geçmiş siparişleri/tahsilatları ona referanslıdır ve bu kolonlarda FK YOKTUR
        // (orders.assigned_user_id, ledger_entries.collected_by_user_id, cash_handovers.*,
        // day_closings.user_id) — gerçek bir DELETE veritabanı tarafından ENGELLENMEZ, sessizce
        // sahipsiz para kayıtları bırakırdı. Bu yüzden "silme" pasifleştirmedir.
        ['patron' => $patron, 'kurye' => $kurye] = $this->makeTenant('silme');

        Livewire::actingAs($patron, 'web')->test(Ekip::class)->call('durumDegistir', $kurye->id);

        $taze = $this->tazeKullanici($kurye->id);
        $this->assertSame('disabled', $taze->status);
        $this->assertSame($kurye->name, $taze->name, 'Ad korunmalı: geçmiş atamalarda okunur kalır.');
    }

    // ── Yetki ────────────────────────────────────────────────────────────────

    #[Test]
    public function patron_disindaki_roller_ekip_yonetemez(): void
    {
        ['tenant' => $tenant, 'operator' => $operator, 'kurye' => $kurye] = $this->makeTenant('yetki');
        $this->limitYaz($tenant, 5);

        Livewire::actingAs($operator, 'web')->test(Ekip::class)
            ->set('form.ad', 'Gizli Kurye')
            ->set('form.kullaniciAdi', 'gizli')
            ->set('form.parola', '1234')
            ->call('kuryeEkle');

        $this->assertSame(1, $this->kuryeSayisi($tenant->id), 'Operatör hesabı kurye açtı.');

        Livewire::actingAs($operator, 'web')->test(Ekip::class)->call('durumDegistir', $kurye->id);
        $this->assertSame('active', $this->tazeKullanici($kurye->id)->status, 'Operatör kurye pasifleştirdi.');
    }

    #[Test]
    public function patron_hesabi_bu_ekrandan_pasiflestirilemez(): void
    {
        // Patron kendini kilitlerse kurtarma yolu yalnız BİZ oluruz (panel). TeamController'ın
        // kimlik ucundaki kuralın aynısı: hedef roller yalnız kurye/operator.
        ['patron' => $patron] = $this->makeTenant('patronkilit');

        Livewire::actingAs($patron, 'web')->test(Ekip::class)->call('durumDegistir', $patron->id);

        $this->assertSame('active', $this->tazeKullanici($patron->id)->status);
    }

    #[Test]
    public function baska_bayinin_kuryesine_dokunulamaz(): void
    {
        // KIRMIZI ÇİZGİ #1: eylem istemciden KULLANICI KİMLİĞİ alır. RLS bağlamı A bayisine
        // kurulduğu için B'nin satırı hiç bulunamaz; kod filtresi unutulsa bile politika durdurur.
        ['patron' => $aPatron] = $this->makeTenant('a');
        ['kurye' => $bKurye] = $this->makeTenant('b');

        Livewire::actingAs($aPatron, 'web')->test(Ekip::class)->call('durumDegistir', $bKurye->id);

        $this->assertSame('active', $this->tazeKullanici($bKurye->id)->status,
            'A bayisinin patronu B bayisinin kuryesini pasifleştirdi (kırmızı çizgi #1).');
    }

    #[Test]
    public function liste_yalniz_kendi_bayisinin_ekibini_gosterir(): void
    {
        ['patron' => $aPatron, 'kurye' => $aKurye] = $this->makeTenant('lista');
        ['kurye' => $bKurye] = $this->makeTenant('listb');

        Livewire::actingAs($aPatron, 'web')->test(Ekip::class)
            ->assertSee($aKurye->name)
            ->assertDontSee($bKurye->name);
    }

    #[Test]
    public function form_ve_onay_kutusu_gercekten_ciziliyor(): void
    {
        // Bu iki dal yalnız kullanıcı bir düğmeye bastığında çizilir; diğer testler eylemleri
        // DOĞRUDAN çağırdığı için görünümün o parçaları hiç derlenmiyordu. Blade'deki bir
        // yazım hatası ancak sahada görünürdü.
        ['tenant' => $tenant, 'patron' => $patron, 'kurye' => $kurye] = $this->makeTenant('cizim');
        $this->limitYaz($tenant, 3);

        Livewire::actingAs($patron, 'web')->test(Ekip::class)
            ->call('formAc')
            ->assertSet('formAcik', true)
            ->assertSee('Giriş için kullanıcı adı')
            ->assertSee('Hesabı aç')
            ->call('formKapat')
            ->assertSet('formAcik', false);

        // Onay kutusu: silme DEĞİL devre dışı bırakma olduğunu ekranda dürüstçe yazmalı.
        Livewire::actingAs($patron, 'web')->test(Ekip::class)
            ->call('onayIste', $kurye->id)
            ->assertSee('Devre dışı bırak')
            ->assertSee('silinmez');

        // Onay İSTEMEK hiçbir şeyi değiştirmez — değişiklik yalnız ikinci tıklamayla olur.
        $this->assertSame('active', $this->tazeKullanici($kurye->id)->status);
    }

    // ── Kimlik çakışması ─────────────────────────────────────────────────────

    #[Test]
    public function ayni_kullanici_adi_500_yerine_form_hatasi_verir(): void
    {
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('cakis');
        $this->limitYaz($tenant, 5);

        Livewire::actingAs($patron, 'web')->test(Ekip::class)
            ->set('form.ad', 'İkinci Kurye')
            ->set('form.kullaniciAdi', 'kurye') // makeTenant'ın açtığı kurye bu adı kullanıyor
            ->set('form.parola', '1234')
            ->call('kuryeEkle')
            ->assertHasErrors('form.kullaniciAdi');

        $this->assertSame(1, $this->kuryeSayisi($tenant->id));
    }

    #[Test]
    public function e_posta_global_tekildir_ve_carpisma_500_vermez(): void
    {
        // `users_email_unique` GLOBAL bir kısıttır ve türetilen e-posta
        // `<kullanici>@<firma-kodu>.sipario.local` biçimindedir: aynı firma kodunu paylaşan iki
        // bayi olamaz, ama PASİF bir kurye aynı kullanıcı adını hâlâ tutuyor olabilir. Çakışma
        // kullanıcıya alan adıyla söylenir; 500 ile patlamaz.
        ['tenant' => $tenant, 'patron' => $patron] = $this->makeTenant('eposta');
        $this->limitYaz($tenant, 5);
        $this->makeTenantKuryesi($tenant, 'ayrilan', 'disabled');

        Livewire::actingAs($patron, 'web')->test(Ekip::class)
            ->set('form.ad', 'Yerine Gelen')
            ->set('form.kullaniciAdi', 'ayrilan')
            ->set('form.parola', '1234')
            ->call('kuryeEkle')
            ->assertHasErrors('form.kullaniciAdi');
    }

    // ── Yardımcılar ──────────────────────────────────────────────────────────

    private function limitYaz(Tenant $tenant, int $limit): void
    {
        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenant->id)
            ->update(['courier_limit' => $limit]));
    }

    private function kuryeSayisi(string $tenantId): int
    {
        return (int) $this->asOwner(fn () => User::on('pgsql_owner')
            ->where('tenant_id', $tenantId)->where('role', 'kurye')->count());
    }

    private function tazeKullanici(string $id): User
    {
        /** @var User $u */
        $u = $this->asOwner(fn () => User::on('pgsql_owner')->findOrFail($id));

        return $u;
    }

    private function makeTenantKuryesi(Tenant $tenant, string $username, string $status): User
    {
        return Provisioning::asOwner(function () use ($tenant, $username, $status) {
            /** @var User $u */
            $u = User::factory()->kurye()->create([
                'tenant_id' => $tenant->id,
                'name' => ucfirst($username).' Kurye',
                'email' => $username.'@'.$tenant->slug.'.sipario.local',
                'username' => $username,
                'status' => $status,
            ]);

            return $u;
        });
    }
}
