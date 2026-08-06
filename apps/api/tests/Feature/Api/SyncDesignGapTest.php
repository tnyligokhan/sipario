<?php

namespace Tests\Feature\Api;

use App\Models\CallLog;
use App\Models\Customer;
use App\Models\DayClosing;
use App\Models\ExemptNumber;
use App\Models\TenantSetting;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * Tasarım boşluğu varlıklarının UÇTAN UCA senkron sözleşmesi (migration 601–607): istemci push eder →
 * sunucu uygular → pull'da GERİ GELİR. Her yeni tablo için bir round-trip; şema/model/applier/snapshot
 * zincirinin herhangi bir halkası kopunca bu dosya kırılır.
 *
 * Kapsam: tenant_settings (tek satır, PK=tenant_id), exempt_numbers, call_logs, day_closings (append)
 * ve 605'te eklenen additif kolonlar (barcode/image_url/region/sort_index/unit/is_custom).
 *
 * Kiracı izolasyonu bu dosyada DEĞİL: DB seviyesinde RlsDesignGapTest, HTTP seviyesinde
 * TenantIsolationTest kanıtlar.
 */
class SyncDesignGapTest extends ApiTestCase
{
    use BuildsSyncEvents;

    // ----------------------------------------------------------------------------------
    // tenant_settings — işletme profili (tek satır)
    // ----------------------------------------------------------------------------------

    #[Test]
    public function isletme_profili_push_edilir_ve_snapshotta_geri_gelir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->tenantSettingsUpsert([
            'business_name' => 'Aspendos Su',
            'owner_name' => 'Ali Usta',
            'phone' => '+902421112233',
            'opens_at' => '08:30',
            'closes_at' => '20:00',
            'receipt_note' => 'Afiyet olsun',
        ])])->assertJsonPath('results.0.status', 'applied');

        $snap = $this->pullSince($token, 0);
        $snap->assertOk();
        $rows = $snap->json('entities.tenant_settings');
        $this->assertCount(1, $rows, 'Profil bayi başına TEK satırdır.');
        $this->assertSame($a['tenant']->id, $rows[0]['tenant_id']);
        $this->assertSame('Aspendos Su', $rows[0]['business_name']);
        $this->assertSame('08:30', $rows[0]['opens_at']);
        $this->assertSame('Afiyet olsun', $rows[0]['receipt_note']);
    }

    #[Test]
    public function isletme_profilini_iki_cihaz_cevrimdisi_yazarsa_ayni_satirda_birlesir(): void
    {
        // Migration 601'in varlık sebebi: PK = tenant_id olduğu için iki cihazın yazımı ÇAKIŞMAZ,
        // aynı satırda LWW ile birleşir — hiçbir olay "unique ihlali" ile kaybolmaz.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $eski = now()->subMinutes(10)->toIso8601String();
        $yeni = now()->toIso8601String();

        $this->pushEvents($token, [
            $this->tenantSettingsUpsert(['business_name' => 'Cihaz 1'], ['occurred_at' => $yeni]),
            $this->tenantSettingsUpsert(['business_name' => 'Cihaz 2 (geç gelen eski yazım)'], ['occurred_at' => $eski]),
        ])->assertOk()
            ->assertJsonPath('results.0.status', 'applied')
            ->assertJsonPath('results.1.status', 'stale'); // eski olay uygulanmaz, REDDEDİLMEZ

        $rows = $this->asOwner(fn () => TenantSetting::query()->get());
        $this->assertCount(1, $rows, 'İki yazım tek satırda birleşmeli.');
        $this->assertSame('Cihaz 1', $rows[0]->business_name, 'Son yazan kazanır.');
    }

    #[Test]
    public function iban_normallestirilerek_saklanir_ve_deltada_geri_gelir(): void
    {
        // IBAN borçluya gönderilen WhatsApp hatırlatmasının içine girer (kullanıcı isteği
        // 2026-08-04). İki şey sınanıyor: (1) saklama biçimi TEK — bayi "tr12 3456 …" yazsa da
        // boşluksuz/büyük harf saklanır, yoksa aynı hesap iki cihazda iki farklı metin olurdu;
        // (2) alan DELTAYA düşer — kurulu bir cihaz yalnız delta çeker ve sıra kodları vardiyasının
        // dersi tam buydu: sunucuda doğru duran bir alan deltaya düşmezse telefonda HİÇ görünmez.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->tenantSettingsUpsert([
            'business_name' => 'Aspendos Su',
            'iban' => ' tr33 0006 1005 1978 6457 8413 26 ',
        ])])->assertJsonPath('results.0.status', 'applied');

        $this->assertSame(
            'TR330006100519786457841326',
            $this->asOwner(fn () => TenantSetting::query()->firstOrFail()->iban)
        );

        $this->pushEvents($token, [$this->tenantSettingsUpsert(
            ['business_name' => 'Aspendos Su', 'iban' => 'TR330006100519786457841326'],
            ['occurred_at' => now()->addMinute()->toIso8601String()],
        )])->assertOk();

        $delta = $this->pullSince($token, 1);
        $delta->assertJsonPath('mode', 'delta');
        $ibanlar = collect($delta->json('changes'))
            ->where('entity_type', 'tenant_settings')
            ->pluck('payload.iban')
            ->filter();
        $this->assertTrue($ibanlar->isNotEmpty(), 'delta yükünde iban YOK');
    }

    #[Test]
    public function asiri_uzun_iban_reddedilir_ve_parti_bozulmaz(): void
    {
        // Kolon 34 karakter. Sınıra dayanıp 22001 almak TÜM partiyi düşürürdü (panel test
        // vardiyasının dersi); uygulayıcı önce kendisi reddeder, savepoint yalnız BU olayı
        // 'rejected' işaretler ve aynı partideki diğer olay yazılır. Kırpma YOK: yarım bir IBAN
        // müşteriyi yanlış hesaba yönlendirirdi.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $yanit = $this->pushEvents($token, [
            $this->tenantSettingsUpsert(['iban' => str_repeat('T', 35)]),
            $this->customerUpsert(['name' => 'Aynı partide, sağlam kayıt']),
        ]);

        $yanit->assertOk()
            ->assertJsonPath('results.0.status', 'rejected')
            ->assertJsonPath('results.1.status', 'applied');

        $this->assertSame(
            'Aynı partide, sağlam kayıt',
            $this->asOwner(fn () => Customer::query()->firstOrFail()->name)
        );
    }

    // ----------------------------------------------------------------------------------
    // exempt_numbers — muaf telefonlar
    // ----------------------------------------------------------------------------------

    #[Test]
    public function muaf_numara_push_edilir_son10_turetilir_ve_geri_gelir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $olay = $this->exemptNumberUpsert(['phone_e164' => '+905321112233', 'label' => 'Tedarikçi']);
        $this->pushEvents($token, [$olay])->assertJsonPath('results.0.status', 'applied');

        $rows = $this->pullSince($token, 0)->json('entities.exempt_number');
        $this->assertCount(1, $rows);
        $this->assertSame($olay['payload']['id'], $rows[0]['id']);
        $this->assertSame('Tedarikçi', $rows[0]['label']);
        // phone_last10 istemci göndermese de türetilir — native arayan tanıma eşleşme anahtarı.
        $this->assertSame('5321112233', $rows[0]['phone_last10']);
    }

    #[Test]
    public function muaf_numara_silinince_snapshottan_dusser_ama_deltada_tombstone_gorunur(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $olay = $this->exemptNumberUpsert();
        $this->pushEvents($token, [$olay])->assertOk();
        $id = $olay['payload']['id'];

        $this->pushEvents($token, [$this->event('exempt_number', 'delete', ['id' => $id])])
            ->assertJsonPath('results.0.status', 'applied');

        $this->assertCount(0, $this->pullSince($token, 0)->json('entities.exempt_number'));

        // Silinen satır DB'de tombstone olarak durur (diğer cihaza delta ile iner).
        $row = $this->asOwner(fn () => ExemptNumber::query()->find($id));
        $this->assertNotNull($row);
        $this->assertNotNull($row->deleted_at);

        $delta = $this->pullSince($token, 1)->json('changes');
        $this->assertSame('delete', $delta[0]['op']);
        $this->assertSame($id, $delta[0]['entity_id']);
    }

    // ----------------------------------------------------------------------------------
    // call_logs — çağrı günlüğü
    // ----------------------------------------------------------------------------------

    #[Test]
    public function cagri_gunlugu_push_edilir_ve_geri_gelir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert(['name' => 'Ayşe Hanım']);
        $this->pushEvents($token, [$cust])->assertOk();

        $cagri = $this->callLogUpsert([
            'customer_id' => $cust['payload']['id'],
            'phone_e164' => '+905324152290',
            'direction' => 'incoming',
            'outcome' => 'Sipariş alındı',
        ]);
        $this->pushEvents($token, [$cagri])->assertJsonPath('results.0.status', 'applied');

        $rows = $this->pullSince($token, 0)->json('entities.call_log');
        $this->assertCount(1, $rows);
        $this->assertSame($cust['payload']['id'], $rows[0]['customer_id']);
        $this->assertSame('incoming', $rows[0]['direction']);
        $this->assertSame('Sipariş alındı', $rows[0]['outcome']);
        $this->assertSame('5324152290', $rows[0]['phone_last10']);
    }

    #[Test]
    public function kayitsiz_numaranin_cagrisi_musterisiz_kabul_edilir(): void
    {
        // Tasarımın "Kayıtsız numara" durumu: customer_id null olmalı ve satır YİNE de yazılmalı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->callLogUpsert([
            'direction' => 'missed', 'outcome' => 'Kayıtsız numara',
        ])])->assertJsonPath('results.0.status', 'applied');

        $rows = $this->pullSince($token, 0)->json('entities.call_log');
        $this->assertCount(1, $rows);
        $this->assertNull($rows[0]['customer_id']);
    }

    #[Test]
    public function cagri_sonucu_sonradan_yazilinca_cagri_saati_degismez(): void
    {
        // occurred_at (çağrının GERÇEKLEŞTİĞİ an) ile updated_occurred_at (LWW damgası) ayrıdır:
        // sonuç sonradan zenginleşince damga ilerler ama "Son Aramalar"daki saat sabit kalmalı.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cagriAni = now()->subMinutes(30)->toIso8601String();
        $id = (string) Str::uuid7();

        $this->pushEvents($token, [$this->callLogUpsert(
            ['id' => $id, 'occurred_at' => $cagriAni],
            ['occurred_at' => $cagriAni],
        )])->assertJsonPath('results.0.status', 'applied');

        // Aynı satır, 30 dk sonra sonuçla güncellenir (LWW damgası ilerler).
        $this->pushEvents($token, [$this->callLogUpsert(
            ['id' => $id, 'occurred_at' => $cagriAni, 'outcome' => 'Sipariş alındı'],
            ['occurred_at' => now()->toIso8601String()],
        )])->assertJsonPath('results.0.status', 'applied');

        $row = $this->asOwner(fn () => CallLog::query()->findOrFail($id));
        $this->assertSame('Sipariş alındı', $row->outcome);
        $this->assertSame(
            $cagriAni,
            $row->occurred_at->toIso8601String(),
            'Çağrı saati sonuç yazımıyla ilerlememeli.'
        );
        $this->assertTrue($row->updated_occurred_at->greaterThan($row->occurred_at));
    }

    #[Test]
    public function gecersiz_cagri_yonu_reddedilir_ve_parti_bozulmaz(): void
    {
        // CHECK ihlali transaction'ı zehirlemeden ÖNCE reddedilmeli: aynı partideki geçerli olay uygulanır.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $gecerli = $this->callLogUpsert(['direction' => 'outgoing']);
        $bozuk = $this->callLogUpsert(['direction' => 'telepati']);

        $this->pushEvents($token, [$bozuk, $gecerli])->assertOk()
            ->assertJsonPath('results.0.status', 'rejected')
            ->assertJsonPath('results.1.status', 'applied');

        $rows = $this->pullSince($token, 0)->json('entities.call_log');
        $this->assertCount(1, $rows);
        $this->assertSame($gecerli['payload']['id'], $rows[0]['id']);
    }

    // ----------------------------------------------------------------------------------
    // day_closings — gün sonu kapanış arşivi (APPEND)
    // ----------------------------------------------------------------------------------

    #[Test]
    public function gun_kapanisi_push_edilir_ve_arsivde_geri_gelir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $kapanis = $this->dayClosing([
            'scope' => 'day',
            'delivery_count' => 12,
            'total_collected_kurus' => 145000,
            'cash_nakit_kurus' => 90000,
            'cash_kart_kurus' => 55000,
            'open_credit_kurus' => 32000,
            'expected_cash_kurus' => 90000,
            'counted_cash_kurus' => 89500,
            'diff_kurus' => -500,
            'note' => 'Eksik 5 TL bulunamadı',
        ]);
        $this->pushEvents($token, [$kapanis])->assertJsonPath('results.0.status', 'applied');

        $rows = $this->pullSince($token, 0)->json('entities.day_closing');
        $this->assertCount(1, $rows);
        $this->assertSame('day', $rows[0]['scope']);
        $this->assertNull($rows[0]['user_id']);
        $this->assertSame(12, $rows[0]['delivery_count']);
        // Fark KANITTIR: eksik para silinmez, kayıtta görünür kalır (kırmızı çizgi #2 felsefesi).
        $this->assertSame(-500, $rows[0]['diff_kurus']);
        $this->assertSame(89500, $rows[0]['counted_cash_kurus']);
    }

    #[Test]
    public function kurye_kapanisi_kullaniciya_baglanir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->dayClosing([
            'scope' => 'courier', 'user_id' => $a['kurye']->id, 'delivery_count' => 5,
        ])])->assertJsonPath('results.0.status', 'applied');

        $rows = $this->pullSince($token, 0)->json('entities.day_closing');
        $this->assertSame('courier', $rows[0]['scope']);
        $this->assertSame($a['kurye']->id, $rows[0]['user_id']);
    }

    #[Test]
    public function kapsam_ile_kullanici_tutarsizligi_reddedilir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        // courier kapanışı kullanıcısız olamaz.
        $this->pushEvents($token, [$this->dayClosing(['scope' => 'courier'])])
            ->assertJsonPath('results.0.status', 'rejected');
        // gün kapanışı kullanıcılı olamaz.
        $this->pushEvents($token, [$this->dayClosing(['scope' => 'day', 'user_id' => $a['kurye']->id])])
            ->assertJsonPath('results.0.status', 'rejected');
        // bilinmeyen kapsam.
        $this->pushEvents($token, [$this->dayClosing(['scope' => 'hafta'])])
            ->assertJsonPath('results.0.status', 'rejected');

        $this->assertSame(0, $this->asOwner(fn () => DayClosing::query()->count()));
    }

    #[Test]
    public function ayni_kapanis_kimligi_ikinci_kez_yazilamaz(): void
    {
        // Append arşiv: aynı id'yi FARKLI bir olayla yeniden göndermek satırı EZEMEZ. KORUNAN
        // DEĞİŞMEZ BUDUR — satır tek kalır ve İLK kayıt kazanır; durum dizesi onun göstergesidir.
        //
        // DURUM 'rejected' → 'duplicate' OLDU (2026-08-06, inceleme #①). Kapanış kimliği artık
        // (tenant|scope|user_id|TR gün) çekirdeğinden TÜRETİLİYOR, yani aynı id = aynı MANTIKSAL
        // olay: patron ile kurye aynı hesabı ayrı cihazlardan kapatırsa ikinci deneme buraya düşer.
        // Bunu `rejected` saymak istemcide KARANTİNA demekti (outbox satırı elle incelemeye kalır)
        // ve iyi huylu bir operasyon tekrarının kuyruğu rehin alması bu deponun çıktığı hata
        // sınıfıdır. 'duplicate' istemcide `acked` olur, kayıp yoktur (kayıt zaten sunucuda).
        //
        // ⚠️ BİLİNÇLİ BEDEL: İKİNCİ denemenin değerleri kayda GEÇMEZ — aşağıdaki 999 düşer, ilk
        // mutabakat (3) kalır. Sonraki vardiya "eskiden rejected'dı, geri alalım" demesin: red
        // sessiz yakınsamadan daha güvenli DEĞİL, yalnız daha gürültülü.
        //
        // (Aynı client_event_id ile retry AYRI bir yoldur — `processed_events` onu daha erken,
        // applier'a hiç girmeden yakalar; o da 'duplicate' döner. İkisi aynı sonuca farklı
        // kapıdan varır.)
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $id = (string) Str::uuid7();
        $this->pushEvents($token, [$this->dayClosing(['id' => $id, 'delivery_count' => 3])])
            ->assertJsonPath('results.0.status', 'applied');
        $this->pushEvents($token, [$this->dayClosing(['id' => $id, 'delivery_count' => 999])])
            ->assertJsonPath('results.0.status', 'duplicate')
            ->assertJsonPath('results.0.entity_id', $id);

        // ASIL DEĞİŞMEZ: tek satır, ilk değerlerle.
        $this->assertSame(1, $this->asOwner(fn () => DayClosing::query()->count()),
            'İkinci kimlik ikinci satır YAZMAMALI.');
        $row = $this->asOwner(fn () => DayClosing::query()->findOrFail($id));
        $this->assertSame(3, $row->delivery_count, 'Arşiv kaydı ezilmemeli.');
    }

    // ----------------------------------------------------------------------------------
    // 605 — additif kolonlar
    // ----------------------------------------------------------------------------------

    #[Test]
    public function urun_barkodu_ve_gorseli_round_trip_yapar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $urun = $this->event('product', 'upsert', [
            'id' => (string) Str::uuid7(), 'name' => '19L Damacana', 'unit_price_kurus' => 4500,
            'barcode' => '8690000000017', 'image_url' => 'https://cdn.example/damacana.webp',
        ]);
        $this->pushEvents($token, [$urun])->assertJsonPath('results.0.status', 'applied');

        $rows = $this->pullSince($token, 0)->json('entities.product');
        $this->assertSame('8690000000017', $rows[0]['barcode']);
        $this->assertSame('https://cdn.example/damacana.webp', $rows[0]['image_url']);
    }

    #[Test]
    public function ayni_barkod_iki_kez_kabul_edilir_cunku_teklik_zorlanmaz(): void
    {
        // Migration 605'in bilinçli kararı: çevrimdışı iki cihaz aynı barkodu girerse unique ihlali
        // olayı REDDEDER ve kullanıcının kaydı KAYBOLURDU. Mükerrer barkod zararsızdır, UI uyarır.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [
            $this->event('product', 'upsert', [
                'id' => (string) Str::uuid7(), 'name' => 'A', 'unit_price_kurus' => 100, 'barcode' => '111',
            ]),
            $this->event('product', 'upsert', [
                'id' => (string) Str::uuid7(), 'name' => 'B', 'unit_price_kurus' => 200, 'barcode' => '111',
            ]),
        ])->assertOk()
            ->assertJsonPath('results.0.status', 'applied')
            ->assertJsonPath('results.1.status', 'applied');

        $this->assertCount(2, $this->pullSince($token, 0)->json('entities.product'));
    }

    #[Test]
    public function adres_bolgesi_round_trip_yapar(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $cust = $this->customerUpsert();
        $this->pushEvents($token, [$cust])->assertOk();
        $this->pushEvents($token, [$this->event('customer_address', 'upsert', [
            'id' => (string) Str::uuid7(),
            'customer_id' => $cust['payload']['id'],
            'address_text' => 'Yeşilbahçe Mah. 15. Sok. No:3',
            'region' => 'Muratpaşa',
            'is_primary' => true,
        ])])->assertJsonPath('results.0.status', 'applied');

        $rows = $this->pullSince($token, 0)->json('entities.customer_address');
        $this->assertSame('Muratpaşa', $rows[0]['region']);
    }

    #[Test]
    public function serbest_siparis_satiri_is_custom_bayragiyla_ayirt_edilir(): void
    {
        // product_id IS NULL ayırt edici DEĞİLDİR (silinmiş ürünün satırı da null olabilir):
        // katalog satırı ile serbest satır AÇIK bayrakla ayrılır. Tasarım ikisini ayrı gösteriyor.
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $siparis = $this->orderCreated([
            $this->line(['product_name' => '19L Damacana', 'unit' => 'adet']),
            $this->line(['product_name' => 'Nakliye farkı', 'unit_price_kurus' => 2500, 'qty' => 1, 'is_custom' => true]),
        ]);
        $this->pushEvents($token, [$siparis])->assertJsonPath('results.0.status', 'applied');

        $satirlar = collect($this->pullSince($token, 0)->json('entities.order_line'))
            ->keyBy('product_name');
        $this->assertFalse($satirlar['19L Damacana']['is_custom']);
        $this->assertSame('adet', $satirlar['19L Damacana']['unit']);
        $this->assertTrue($satirlar['Nakliye farkı']['is_custom']);
    }

    #[Test]
    public function elle_siralama_sort_set_olayindan_turer(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $siparis = $this->orderCreated([$this->line()]);
        $this->pushEvents($token, [$siparis])->assertOk();
        $id = $siparis['payload']['order']['id'];

        $this->pushEvents($token, [$this->orderEvent('sort_set', ['order_id' => $id, 'sort_index' => 3])])
            ->assertJsonPath('results.0.status', 'applied');
        $this->assertSame(3, collect($this->pullSince($token, 0)->json('entities.order'))->firstWhere('id', $id)['sort_index']);

        // Sonraki sort_set önceki değeri değiştirir (önbellek son olaydan türer).
        $this->pushEvents($token, [$this->orderEvent('sort_set', ['order_id' => $id, 'sort_index' => 1])])
            ->assertJsonPath('results.0.status', 'applied');
        $this->assertSame(1, collect($this->pullSince($token, 0)->json('entities.order'))->firstWhere('id', $id)['sort_index']);

        // sort_index'siz olay istemci-kaynaklı geçersizliktir.
        $this->pushEvents($token, [$this->orderEvent('sort_set', ['order_id' => $id])])
            ->assertJsonPath('results.0.status', 'rejected');
    }

    // ----------------------------------------------------------------------------------
    // user_profile — kurye profili (team bloğuyla yayılır, sync_changes'e DÜŞMEZ)
    // ----------------------------------------------------------------------------------

    #[Test]
    public function kurye_profili_duzenlenir_ve_team_blogunda_geri_gelir(): void
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $yanit = $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'name' => 'Mehmet Kurye', 'phone' => '+905331234567',
        ])]);
        $yanit->assertJsonPath('results.0.status', 'applied');
        // users delta günlüğünde YOKTUR: değişiklik seq üretmez.
        $this->assertNull($yanit->json('results.0.server_seq'));
        $this->assertSame(0, $yanit->json('current_seq'));

        $uye = collect($yanit->json('team'))->firstWhere('id', $a['kurye']->id);
        $this->assertSame('Mehmet Kurye', $uye['name']);
        $this->assertSame('+905331234567', $uye['phone']);
    }

    #[Test]
    public function kullanici_profili_senkronla_olusturulamaz_veya_rol_degistiremez(): void
    {
        // Kimlik yüzeyi senkron yoluyla açılmaz (yetki yükseltme vektörü).
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);

        $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => (string) Str::uuid7(), 'name' => 'Hayalet Kullanıcı',
        ])])->assertJsonPath('results.0.status', 'rejected');

        // Rol payload'da gönderilse bile YOK SAYILIR (kurye patron olamaz).
        $this->pushEvents($token, [$this->userProfileUpsert([
            'id' => $a['kurye']->id, 'name' => 'Kurye', 'role' => 'patron',
        ])])->assertJsonPath('results.0.status', 'applied');

        $rol = collect($this->pullSince($token, 0)->json('team'))
            ->firstWhere('id', $a['kurye']->id)['role'];
        $this->assertSame('kurye', $rol, 'Senkron rol yükseltemez.');
    }

    // ----------------------------------------------------------------------------------
    // Snapshot bütünlüğü
    // ----------------------------------------------------------------------------------

    #[Test]
    public function taze_kurulum_snapshotu_yeni_varlik_anahtarlarini_daima_tasir(): void
    {
        // İstemci snapshot'ı anahtar anahtar okur; boş bayide de anahtarlar BULUNMALI (null değil).
        $a = $this->makeTenant('a');
        $entities = $this->pullSince($this->tokenFor($a['patron']), 0)->json('entities');

        foreach (['tenant_settings', 'exempt_number', 'call_log', 'day_closing'] as $anahtar) {
            $this->assertArrayHasKey($anahtar, $entities);
            $this->assertSame([], $entities[$anahtar]);
        }
    }
}
