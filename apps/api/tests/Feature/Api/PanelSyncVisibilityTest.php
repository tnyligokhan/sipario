<?php

namespace Tests\Feature\Api;

use App\Models\AdminUser;
use App\Panel\PanelWriteService;
use App\Support\Provisioning;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * FAZ 5c-3 — panelden yapılan DEĞİŞİKLİĞİN cihaza ulaşması.
 *
 * PanelWriteTest yeni KAYDIN deltaya düştüğünü kanıtlıyor. Buradaki sorular onun kapsamadıkları:
 * bir kaydı DÜZENLEMEK ve PASİFLEŞTİRMEK de cihaza düşüyor mu? Bu ayrı bir sorudur, çünkü ikisi de
 * `sync_changes`e YENİ satır değil AYNI varlığa ikinci bir satır yazar ve arada LWW damgası ile
 * ChangeApplier'ın bayat-olay kuralı durur. Yazma "uygulandı" dönse bile cihazın gördüğü şey eski
 * değer kalabilir — panelin sahadaki tek işe yarar tarafı budur, sessizce çalışmaması pahalıdır.
 *
 * Sahadaki karşılığı: destek telefonda müşterinin adresini düzeltir, kurye telefonunda hâlâ eski
 * adresi görür ve yanlış kapıya gider.
 */
class PanelSyncVisibilityTest extends ApiTestCase
{
    use BuildsSyncEvents;

    private function yazici(): PanelWriteService
    {
        return new PanelWriteService('pgsql_panel');
    }

    private function makeAdmin(): AdminUser
    {
        return Provisioning::asOwner(fn () => AdminUser::on('pgsql_owner')->create([
            'name' => 'Senkron', 'email' => 'senk@sipario.test', 'password' => 'panel-secret', 'role' => 'superadmin',
        ]));
    }

    /** Verilen varlık türü için imleçten sonraki SON değişikliğin payload'u. */
    private function sonDegisim(string $token, int $imlec, string $tur, ?string $entityId = null): ?array
    {
        $degisimler = collect($this->pullSince($token, $imlec)->assertOk()->json('changes'))
            ->filter(fn ($d) => $d['entity_type'] === $tur)
            ->when($entityId !== null, fn ($c) => $c->filter(fn ($d) => $d['entity_id'] === $entityId))
            ->sortBy('seq');

        return $degisimler->last();
    }

    #[Test]
    public function panelden_yapilan_duzenleme_cihaza_yeni_degerle_duser(): void
    {
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $token = $this->tokenFor($a['patron']);

        // Cihaz müşteriyi kendisi yaratır (düzenlenecek olan kayıt cihazdan gelir — gerçek akış).
        $musteriId = (string) Str::uuid7();
        $this->pushEvents($token, [
            $this->customerUpsert(['id' => $musteriId, 'name' => 'Eski Ad']),
            $this->event('customer_phone', 'upsert', [
                'id' => (string) Str::uuid7(), 'customer_id' => $musteriId,
                'phone_e164' => '+905321112233', 'phone_last10' => '5321112233', 'is_primary' => true,
            ]),
        ])->assertOk();

        $imlec = (int) $this->pullSince($token, 0)->json('cursor');

        // Panel AYNI kaydı düzenler: ad ve telefon değişir.
        $sonuc = $this->yazici()->musteriKaydet($a['tenant']->id, [
            'id' => $musteriId, 'ad' => 'Düzeltilmiş Ad', 'telefon' => '05339998877', 'adres' => 'Yeni Adres',
        ], $admin->id);

        $this->assertSame('applied', $sonuc['durum'], 'Düzenleme uygulanmalı.');
        $this->assertSame($musteriId, $sonuc['id'], 'Düzenleme YENİ kayıt yaratmamalı, aynı kimlikte kalmalı.');

        // Cihaz imleçten sonrasını çeker ve YENİ değeri görür.
        $degisim = $this->sonDegisim($token, $imlec, 'customer', $musteriId);
        $this->assertNotNull($degisim, 'Panel düzenlemesi cihazın deltasına düşmeli.');
        $this->assertSame('Düzeltilmiş Ad', $degisim['payload']['name'], 'Cihaz YENİ adı görmeli.');

        // Telefon da güncellendi (yeni satır değil, aynı satırın yeni hâli).
        $telefon = $this->sonDegisim($token, $imlec, 'customer_phone');
        $this->assertNotNull($telefon, 'Telefon güncellemesi de deltaya düşmeli.');
        $this->assertSame('+905339998877', $telefon['payload']['phone_e164']);

        // Adres panelden İLK KEZ eklendi; o da düşmeli.
        $adres = $this->sonDegisim($token, $imlec, 'customer_address');
        $this->assertNotNull($adres, 'Panelden eklenen adres deltaya düşmeli.');
        $this->assertSame('Yeni Adres', $adres['payload']['address_text']);

        // SIFIRDAN kurulan cihaz da (snapshot) yalnız yeni değeri görmeli — eski ad hiç görünmemeli.
        $snapshot = $this->pullSince($token, 0)->assertOk();
        $adlar = collect($snapshot->json('entities.customer'))->pluck('name')->all();
        $this->assertContains('Düzeltilmiş Ad', $adlar);
        $this->assertNotContains('Eski Ad', $adlar, 'Eski ad snapshot\'ta kalmamalı — düzenleme yerine kopya yaratılmış olabilir.');
        $this->assertCount(1, $adlar, 'Düzenleme ikinci bir müşteri satırı doğurmamalı.');
    }

    #[Test]
    public function panelden_kara_listeye_alma_ve_geri_alma_cihaza_duser(): void
    {
        // "Pasifleştirme" bu üründe KARA LİSTEdir (müşteri silinmez, is_active kolonu yok). Cihazın
        // bunu görmesi işlevseldir: kara listedeki müşteriye yeni sipariş açılmamalıdır. Bayrak
        // cihaza düşmezse kurye/operatör kararı ESKİ duruma göre verir.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $token = $this->tokenFor($a['patron']);

        $musteriId = (string) Str::uuid7();
        $this->pushEvents($token, [$this->customerUpsert(['id' => $musteriId, 'name' => 'Borçlu Müşteri'])])->assertOk();
        $imlec = (int) $this->pullSince($token, 0)->json('cursor');

        // Kara listeye al.
        $this->assertSame('applied', $this->yazici()->musteriKaraListe($a['tenant']->id, $musteriId, true, $admin->id)['durum']);

        $degisim = $this->sonDegisim($token, $imlec, 'customer', $musteriId);
        $this->assertNotNull($degisim, 'Kara liste değişikliği cihaza düşmeli.');
        $this->assertNotNull($degisim['payload']['blacklisted_at'] ?? null, 'Cihaz kara liste damgasını görmeli.');
        $this->assertSame('Borçlu Müşteri', $degisim['payload']['name'], 'Kara liste alma müşterinin adını silmemeli.');

        // Geri al: bayrak temizlenmiş olarak yine düşmeli (tek yönlü olmadığı kanıtlanır).
        $imlec2 = (int) $this->pullSince($token, 0)->json('cursor');
        $this->assertSame('applied', $this->yazici()->musteriKaraListe($a['tenant']->id, $musteriId, false, $admin->id)['durum']);

        $geri = $this->sonDegisim($token, $imlec2, 'customer', $musteriId);
        $this->assertNotNull($geri, 'Kara listeden çıkarma da cihaza düşmeli.');
        $this->assertNull($geri['payload']['blacklisted_at'] ?? null, 'Cihaz bayrağın kalktığını görmeli.');

        // Snapshot da temiz.
        $snapshot = collect($this->pullSince($token, 0)->json('entities.customer'))->firstWhere('id', $musteriId);
        $this->assertNull($snapshot['blacklisted_at'] ?? null);
    }

    #[Test]
    public function panelden_urun_pasiflestirme_cihaza_duser(): void
    {
        // Ürün tarafında pasiflik GERÇEK bir kolondur (`is_active`); pasif ürün sipariş ekranında
        // seçilemez. Panelden kapatılan ürün cihazda hâlâ seçilebiliyorsa fiyatı kaldırılmış bir
        // ürün satılmaya devam eder.
        $a = $this->makeTenant('a');
        $admin = $this->makeAdmin();
        $token = $this->tokenFor($a['patron']);

        $urun = $this->yazici()->urunKaydet($a['tenant']->id, ['ad' => '19L Damacana', 'fiyat_kurus' => 4500], $admin->id);
        $this->assertSame('applied', $urun['durum']);

        $imlec = (int) $this->pullSince($token, 0)->json('cursor');

        $this->assertSame('applied', $this->yazici()->urunAktiflik($a['tenant']->id, $urun['id'], false, $admin->id)['durum']);

        $degisim = $this->sonDegisim($token, $imlec, 'product', $urun['id']);
        $this->assertNotNull($degisim, 'Ürün pasifleştirme cihazın deltasına düşmeli.');
        $this->assertFalse((bool) $degisim['payload']['is_active'], 'Cihaz ürünün pasifleştiğini görmeli.');
        $this->assertSame(4500, (int) $degisim['payload']['unit_price_kurus'], 'Pasifleştirme fiyatı sıfırlamamalı.');

        // Geri açılınca da düşer.
        $imlec2 = (int) $this->pullSince($token, 0)->json('cursor');
        $this->yazici()->urunAktiflik($a['tenant']->id, $urun['id'], true, $admin->id);

        $geri = $this->sonDegisim($token, $imlec2, 'product', $urun['id']);
        $this->assertNotNull($geri);
        $this->assertTrue((bool) $geri['payload']['is_active']);
    }

    #[Test]
    public function panelden_yazilan_kayit_baska_bayinin_pull_una_dusmez(): void
    {
        // Senkron YÜZEYİNDE cross-tenant kontrolü: panel yazması RLS'li bağlantıdan geçse de
        // `sync_changes` satırı yanlış tenant_id ile doğsaydı, B'nin cihazı A'nın müşterisini
        // ÇEKERDİ. Bu, ekrandaki sızıntıdan daha kötüdür — veri karşı cihazın diskine yazılır.
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');
        $admin = $this->makeAdmin();
        $tokenB = $this->tokenFor($b['patron']);

        // B'nin KENDİ verisi olmalı: imleç 0 kalırsa pull snapshot kipine düşer ve 'changes'
        // hiç dönmez — delta boşluğunu sınadığımızı sanıp aslında hiçbir şey sınamamış oluruz.
        $this->pushEvents($tokenB, [$this->customerUpsert(['name' => 'B Kendi Müşterisi'])])->assertOk();
        $imlecB = (int) $this->pullSince($tokenB, 0)->json('cursor');
        $this->assertGreaterThan(0, $imlecB, 'B\'nin imleci ilerlemiş olmalı (delta kipi için şart).');

        $sonuc = $this->yazici()->musteriKaydet($a['tenant']->id, ['ad' => 'Yalnız A Görsün', 'telefon' => '05321112233'], $admin->id);
        $this->assertSame('applied', $sonuc['durum']);

        // B'nin deltası boş.
        $degisimler = $this->pullSince($tokenB, $imlecB)->assertOk()->json('changes');
        $this->assertSame([], $degisimler, 'A\'ya yazılan kayıt B\'nin deltasına DÜŞMEMELİ.');

        // B'nin snapshot'ı da temiz.
        $snapshotB = (string) json_encode($this->pullSince($tokenB, 0)->json('entities'));
        $this->assertStringNotContainsString('Yalnız A Görsün', $snapshotB);
        $this->assertStringNotContainsString($sonuc['id'], $snapshotB);
    }
}
