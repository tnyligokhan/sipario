<?php

namespace Tests\Feature\Api;

use App\Abonelik\EkPaketServisi;
use App\Abonelik\MasrafServisi;
use App\Abonelik\OdemeKayitServisi;
use App\Enums\BillingPeriod;
use App\Models\AddonGrant;
use App\Models\AddonPackage;
use App\Models\Expense;
use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * İDEMPOTENS ANAHTARLARI + ÖDEME LİSTESİ SÖZLEŞMESİ.
 *
 * Buradaki ilk iki kural GERİ ALINAMAZ bir bozulmayı önler: `addon_grants` ve `expenses`
 * append-only'dir (UPDATE/DELETE revoke), kota kolonları ise elle düzeltilmek zorunda kalır.
 * Yani çift yazımın telafisi yoktur — engellenmesi gerekir.
 */
class AbonelikIdempotensTest extends ApiTestCase
{
    // ── Ek paket tanımlama ───────────────────────────────────────────────────

    #[Test]
    public function ayni_anahtarla_ikinci_tanimlama_kotayi_tekrar_artirmaz(): void
    {
        ['tenant' => $tenant] = $this->makeTenant('grantidem');
        $paket = $this->paket('credits', 250);
        $anahtar = (string) Str::uuid7();
        $servis = new EkPaketServisi('pgsql_owner');

        $once = (int) $this->taze($tenant->id)->route_credits;

        $ilk = $servis->tanimla($tenant->id, $paket->id, 'iban', grantId: $anahtar);
        $ikinci = $servis->tanimla($tenant->id, $paket->id, 'iban', grantId: $anahtar);

        $this->assertSame($ilk->id, $ikinci->id, 'İkinci çağrı AYNI grant satırını döndürmeli.');
        $this->assertSame(1, $this->asOwner(fn () => AddonGrant::on('pgsql_owner')
            ->where('tenant_id', $tenant->id)->count()));
        $this->assertSame(1, $this->asOwner(fn () => SubscriptionPayment::on('pgsql_owner')
            ->where('provider_ref', 'grant:'.$anahtar)->count()));
        $this->assertSame($once + 250, (int) $this->taze($tenant->id)->route_credits,
            'Kota İKİ KEZ artmamalı — append-only tabloda bunun telafisi yok.');
    }

    #[Test]
    public function kurye_kotasi_da_tek_kez_artar(): void
    {
        ['tenant' => $tenant] = $this->makeTenant('kuryeidem');
        $paket = $this->paket('courier', 3);
        $anahtar = (string) Str::uuid7();
        $servis = new EkPaketServisi('pgsql_owner');

        $once = (int) $this->taze($tenant->id)->courier_limit;

        $servis->tanimla($tenant->id, $paket->id, 'bedelsiz', grantId: $anahtar);
        $servis->tanimla($tenant->id, $paket->id, 'bedelsiz', grantId: $anahtar);

        $this->assertSame($once + 3, (int) $this->taze($tenant->id)->courier_limit);
    }

    #[Test]
    public function anahtarsiz_tanimlama_ikinci_kaydi_yazar(): void
    {
        // İdempotens ÇAĞIRANDADIR (OdemeKayitServisi::kaydet ile aynı sözleşme). Anahtar
        // verilmeyen çağrı "aynı işlem" değildir; iki gerçek tanımlama yapmak meşru bir istektir.
        ['tenant' => $tenant] = $this->makeTenant('anahtarsiz');
        $paket = $this->paket('credits', 100);
        $servis = new EkPaketServisi('pgsql_owner');

        $servis->tanimla($tenant->id, $paket->id, 'iban');
        $servis->tanimla($tenant->id, $paket->id, 'iban');

        $this->assertSame(2, $this->asOwner(fn () => AddonGrant::on('pgsql_owner')
            ->where('tenant_id', $tenant->id)->count()));
    }

    // ── Masraf ───────────────────────────────────────────────────────────────

    #[Test]
    public function ayni_anahtarla_ikinci_masraf_cift_kalem_yazmaz(): void
    {
        $anahtar = (string) Str::uuid7();
        $servis = new MasrafServisi('pgsql_owner');

        $ilk = $servis->ekle('Sunucu/Altyapı', 115000, null, 'Hetzner aylık', null, $anahtar);
        $ikinci = $servis->ekle('Sunucu/Altyapı', 115000, null, 'Hetzner aylık', null, $anahtar);

        $this->assertSame($ilk->id, $ikinci->id);
        $this->assertSame(1, $this->asOwner(fn () => Expense::on('pgsql_owner')->whereKey($anahtar)->count()));

        // İkinci denetim satırı da yazılmamalı: tekrar eden çağrı yeni bir eylem değildir.
        $this->assertSame(1, $this->asOwner(fn () => DB::connection('pgsql_owner')->table('panel_audit')
            ->where('action', 'expense_create')->count()));
    }

    // ── Ödeme listesi ────────────────────────────────────────────────────────

    #[Test]
    public function odemeler_sayfali_ve_toplam_tum_kayitlari_kapsar(): void
    {
        // Bellekte sayfalayan eski yol 500 satırlık tavanı sessizce kırpıyordu; sayfalama artık
        // sorguda. Başlıktaki toplam SAYFANIN değil SÜZGECİN toplamı olmalı.
        ['tenant' => $tenant] = $this->makeTenant('sayfa');
        $this->odemeYaz($tenant->id, 5, 10000);

        $servis = new OdemeKayitServisi('pgsql_panel');
        $sayfa = $servis->odemelerSayfali(perPage: 2);

        $this->assertCount(2, $sayfa->items(), 'Sayfa boyu uygulanmalı.');
        $this->assertSame(5, $sayfa->total(), 'Toplam kayıt sayısı süzgecin tamamından gelmeli.');

        $ozet = $servis->odemeOzeti();
        $this->assertSame(5, $ozet['adet']);
        $this->assertSame(50000, $ozet['toplam_kurus'], 'Toplam sayfaya değil süzgece göre hesaplanmalı.');
    }

    #[Test]
    public function firma_aramasi_turkce_harfleri_katlar(): void
    {
        // "İzmir" araması "izmir" yazınca da bulmalı: Postgres'te lower('İ') düz `i` DEĞİLDİR,
        // katlama önce yapılmazsa bu arama sessizce sıfır sonuç döndürür.
        ['tenant' => $izmir] = $this->makeTenant('izm');
        ['tenant' => $ankara] = $this->makeTenant('ank');
        $this->adlandir($izmir->id, 'İzmir Su Bayii');
        $this->adlandir($ankara->id, 'Ankara Su Bayii');
        $this->odemeYaz($izmir->id, 1, 59900);
        $this->odemeYaz($ankara->id, 1, 39900);

        $servis = new OdemeKayitServisi('pgsql_panel');

        foreach (['izmir', 'İZMİR', 'İzmir'] as $arama) {
            $sonuc = $servis->odemelerSayfali(firmaArama: $arama);
            $this->assertSame(1, $sonuc->total(), "'{$arama}' araması İzmir'i bulmalı.");
            $this->assertSame($izmir->id, $sonuc->items()[0]->tenant_id);
        }

        // Özet de AYNI süzgeci kullanmalı, yoksa başlık listeyle tutmaz.
        $this->assertSame(59900, $servis->odemeOzeti(firmaArama: 'izmir')['toplam_kurus']);
    }

    #[Test]
    public function firma_aramasinda_joker_karakterler_kacirilir(): void
    {
        // `%` LIKE'ın jokeridir. Kaçırılmazsa arama kutusuna `%` yazan kullanıcı TÜM bayileri
        // getirir — arama gibi görünen ama süzmeyen bir kutu. `_` de "herhangi bir karakter"dir.
        // Kaçış karakterinin KENDİSİ de kaçırılmalı, yoksa `!` yazmak deseni bozar.
        ['tenant' => $a] = $this->makeTenant('joka');
        ['tenant' => $b] = $this->makeTenant('jokb');
        $this->adlandir($a->id, 'Berrak Su');
        $this->adlandir($b->id, 'Damla Su');
        $this->odemeYaz($a->id, 1, 10000);
        $this->odemeYaz($b->id, 1, 10000);

        $servis = new OdemeKayitServisi('pgsql_panel');

        foreach (['%', '_', '!', '%Su%'] as $arama) {
            $this->assertSame(0, $servis->odemelerSayfali(firmaArama: $arama)->total(),
                "'{$arama}' düz metin olarak aranmalı, joker olarak DEĞİL.");
        }

        // Gerçek metin hâlâ bulunuyor — kaçış aramayı öldürmedi.
        $this->assertSame(1, $servis->odemelerSayfali(firmaArama: 'Berrak')->total());
    }

    #[Test]
    public function firma_kaydi_eager_yuklenir(): void
    {
        // Ekran firma adını gösteriyor; ilişki gelmezse N+1 ya da tüm bayi tablosunu belleğe çekme.
        ['tenant' => $tenant] = $this->makeTenant('eager');
        $this->adlandir($tenant->id, 'Berrak Su');
        $this->odemeYaz($tenant->id, 1, 59900);

        $sayfa = (new OdemeKayitServisi('pgsql_panel'))->odemelerSayfali();

        $this->assertTrue($sayfa->items()[0]->relationLoaded('tenant'));
        $this->assertSame('Berrak Su', $sayfa->items()[0]->tenant?->name);
    }

    #[Test]
    public function aylar_yalniz_odeme_gormus_aylari_verir(): void
    {
        ['tenant' => $tenant] = $this->makeTenant('aylar');
        $this->odemeYaz($tenant->id, 1, 59900, now());
        $this->odemeYaz($tenant->id, 1, 59900, now()->subMonthNoOverflow());

        // Yalnız MASRAF görmüş bir ay listeye GİRMEMELİ: süzgeç ödemelerin üzerinde.
        (new MasrafServisi('pgsql_owner'))->ekle('Reklam', 90000, now()->subMonthsNoOverflow(6));

        $aylar = (new OdemeKayitServisi('pgsql_panel'))->aylar();

        $this->assertSame([now()->format('Y-m'), now()->subMonthNoOverflow()->format('Y-m')], $aylar,
            'Aylar yeniden eskiye sıralı olmalı ve yalnız ödemeli aylar listelenmeli.');
        $this->assertNotContains(now()->subMonthsNoOverflow(6)->format('Y-m'), $aylar);
    }

    #[Test]
    public function ay_suzgeci_tr_gun_sinirini_kullanir(): void
    {
        // TR saatiyle ayın SON günü 23:30'da alınan ödeme O AYA yazılmalı. UTC'ye göre gruplansaydı
        // (TR = UTC+3) o an UTC'de ertesi ayın 1'i 20:30 olur ve tahsilat bir sonraki aya kayardı —
        // ay sonu kapanışları her ay birkaç kayıt oynardı.
        ['tenant' => $tenant] = $this->makeTenant('aysinir');

        // Anı TR saat diliminde kur, UTC'ye çevirip öyle yaz: Laravel'in `datetime` cast'i OFSET
        // YAZMAZ ('Y-m-d H:i:s'), yani +03:00'lık bir Carbon naive olarak serileşir ve oturum saat
        // dilimine (UTC) göre yorumlanıp 3 saat kayardı. Testin ölçtüğü şey servisin ay sınırı,
        // cast'in davranışı değil — o yüzden yazılan an baştan tekilleştiriliyor.
        $trAySonu = Carbon::now('Etc/GMT-3')->endOfMonth()->setTime(23, 30);
        $this->odemeYaz($tenant->id, 1, 59900, $trAySonu->copy()->utc());

        $servis = new OdemeKayitServisi('pgsql_panel');
        $this->assertSame(1, $servis->odemeOzeti($trAySonu->format('Y-m'))['adet'],
            'TR ayının son gecesindeki tahsilat O AYIN süzgecine düşmeli.');
        $this->assertSame(0, $servis->odemeOzeti($trAySonu->copy()->addDay()->format('Y-m'))['adet'],
            'Sonraki aya SIZMAMALI (UTC ile gruplansaydı sızardı).');
    }

    // ── Yardımcılar ──────────────────────────────────────────────────────────

    private function paket(string $tur, int $adet): AddonPackage
    {
        /** @var AddonPackage $paket */
        $paket = $this->asOwner(fn () => AddonPackage::on('pgsql_owner')
            ->where('type', $tur)->where('quantity', $adet)->firstOrFail());

        return $paket;
    }

    private function taze(string $tenantId): Tenant
    {
        /** @var Tenant $tenant */
        $tenant = $this->asOwner(fn () => Tenant::on('pgsql_owner')->findOrFail($tenantId));

        return $tenant;
    }

    private function adlandir(string $tenantId, string $ad): void
    {
        $this->asOwner(fn () => Tenant::on('pgsql_owner')->whereKey($tenantId)->update(['name' => $ad]));
    }

    private function odemeYaz(string $tenantId, int $adet, int $kurus, ?Carbon $zaman = null): void
    {
        $this->asOwner(function () use ($tenantId, $adet, $kurus, $zaman) {
            for ($i = 0; $i < $adet; $i++) {
                SubscriptionPayment::on('pgsql_owner')->create([
                    'tenant_id' => $tenantId,
                    'amount_kurus' => $kurus,
                    'currency' => 'TRY',
                    'provider' => 'iban',
                    'provider_ref' => 'test:'.Str::uuid7(),
                    'status' => 'success',
                    'period' => BillingPeriod::Monthly->value,
                    'occurred_at' => $zaman ?? now(),
                ]);
            }
        });
    }
}
