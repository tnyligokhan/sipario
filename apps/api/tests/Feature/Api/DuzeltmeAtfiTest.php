<?php

namespace Tests\Feature\Api;

use App\Models\Device;
use App\Models\LedgerEntry;
use App\Models\Tenant;
use App\Models\User;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;
use Tests\Feature\Api\Concerns\BuildsSyncEvents;

/**
 * KASAYA DOKUNAN DÜZELTMENİN NAKİT ATFI (inceleme #⑥, lead kararı 2026-08-06).
 *
 * ARIZA: `collected_by_user_id` düzeltmeyi YAZAN kişiye atfedilirse para iki çerçevede birden
 * yanlış yere düşer. Kurye 100,00 topladı; patron kendi telefonundan hatalı 20,00'ı ters çevirdi.
 * Düzeltme patrona atfedilirse günün nakdi 80,00'a iner ama kuryenin günlük net değişimi 100,00
 * kalır → gün beklenen −20,00, patron kasadaki 0'ı sayınca "FAZLA 20,00". Kurye kapsamında da
 * beklenen 100,00 kalırken cebinde 80,00 vardır → "EKSİK 20,00". İkisi de append-only DONAR ve
 * kurye hiç var olmamış paradan sorumlu tutulur.
 *
 * SUNUCU ATFI YENİDEN YAZMAZ, ÇELİŞKİYİ REDDEDER. Yeniden yazmak "counted/expected/diff İSTEMCİ
 * SNAPSHOT'ıdır, sunucu yeniden hesaplamaz" güven modelini kırardı (DECISIONS Faz 4) ve arızayı
 * başka kapıdan geri getirirdi: sunucudaki kayıt ile istemcideki ayrışır, bir sonraki pull'a kadar
 * iki cihaz farklı rakam konuşur ve o aralıkta donan bir kapanış yalanı kalıcılaştırır. Üstelik
 * istemci yanlış satırı işaret ederse sunucu YANLIŞ kuryeye para yazmış olurdu.
 *
 * KAPI UYGULAMA KATMANINDA KALMAK ZORUNDA — `payment_type` kapsam kuralının aksine (o 2026-08-06'da
 * DB'ye bir CHECK olarak indi) bu kural BAŞKA BİR SATIRA bakmayı gerektiriyor ve CHECK bunu yapamaz.
 * Sonucu: Eloquent'le doğrudan yazan bir yol açılırsa (seeder deseni) kapı yine atlanır.
 *
 * KAPSAM DAR ve testler tam olarak bu sınırı çiziyor: yalnız `correction` + `payment_type` dolu +
 * `reverses_entry_id` dolu. Kasaya dokunmayan düzeltme ve serbest düzeltme kapıya HİÇ uğramaz —
 * kapının geniş tutulması, meşru bakiye düzeltmelerini reddederdi.
 */
class DuzeltmeAtfiTest extends ApiTestCase
{
    use BuildsSyncEvents;

    /**
     * Kuryenin aldığı nakit tahsilatı yazar ve id'sini döner (ters çevrilecek satır).
     *
     * @param  array{tenant: Tenant, patron: User, kurye: User, device: Device}  $a
     */
    private function kuryeninTahsilati(string $token, array $a, string $musteriId): string
    {
        $tahsilat = $this->ledgerEntry([
            'customer_id' => $musteriId,
            'entry_type' => 'payment',
            'amount_kurus' => -10000,
            'payment_type' => 'nakit',
            'collected_by_user_id' => $a['kurye']->id,
        ]);
        $this->pushEvents($token, [$tahsilat])->assertOk()
            ->assertJsonPath('results.0.status', 'applied');

        return $tahsilat['payload']['id'];
    }

    /** @return array{0: string, 1: array<string, mixed>, 2: string} [token, seed, musteriId] */
    private function hazirla(): array
    {
        $a = $this->makeTenant('a');
        $token = $this->tokenFor($a['patron']);
        $musteri = $this->customerUpsert(['name' => 'Ayşe']);
        $this->pushEvents($token, [$musteri])->assertOk();

        return [$token, $a, $musteri['payload']['id']];
    }

    #[Test]
    public function atif_ters_cevrilen_kayitla_ayniysa_uygulanir(): void
    {
        [$token, $a, $musteriId] = $this->hazirla();
        $tahsilatId = $this->kuryeninTahsilati($token, $a, $musteriId);

        // Mobilin düzeltilmiş hâli: `duzeltme()` payment_type İLE atfı BİRLİKTE devralıyor.
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $musteriId,
            'entry_type' => 'correction',
            'amount_kurus' => 2000,
            'payment_type' => 'nakit',
            'reverses_entry_id' => $tahsilatId,
            'collected_by_user_id' => $a['kurye']->id, // kuryeye atfedildi — DOĞRU
        ])])->assertOk()->assertJsonPath('results.0.status', 'applied');

        $this->assertSame(2, $this->asOwner(fn () => LedgerEntry::query()->count()));
    }

    #[Test]
    public function atif_yazan_kisiye_kayarsa_reddedilir(): void
    {
        // ARIZANIN TA KENDİSİ: düzeltme patrona atfediliyor, oysa parayı kurye toplamıştı.
        [$token, $a, $musteriId] = $this->hazirla();
        $tahsilatId = $this->kuryeninTahsilati($token, $a, $musteriId);

        $yanit = $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $musteriId,
            'entry_type' => 'correction',
            'amount_kurus' => 2000,
            'payment_type' => 'nakit',
            'reverses_entry_id' => $tahsilatId,
            'collected_by_user_id' => $a['patron']->id, // YANLIŞ — düzeltmeyi yazan kişi
        ])]);

        $yanit->assertOk()->assertJsonPath('results.0.status', 'rejected');
        // `domain_rejected`: kural sunucunun İŞ KURALIDIR, bir SQL/veri biçimi hatası değil.
        $yanit->assertJsonPath('results.0.reason', 'domain_rejected');

        $this->assertSame(1, $this->asOwner(fn () => LedgerEntry::query()->count()),
            'Çelişkili düzeltme YAZILMAMALI — yoksa kuryeye hiç var olmamış para borçlanırdı.');
    }

    #[Test]
    public function atifsiz_tahsilatin_duzeltmesi_de_atifsiz_olmali(): void
    {
        // NULL ATIF DA BİR BEYANDIR: para doğrudan kasaya girdiyse (toplayıcısı yok) düzeltmesi de
        // atıfsız olmalı. Atıf EKLEMEK, olmayan bir kuryeye para yazmaktır.
        [$token, $a, $musteriId] = $this->hazirla();

        $tahsilat = $this->ledgerEntry([
            'customer_id' => $musteriId,
            'entry_type' => 'payment',
            'amount_kurus' => -10000,
            'payment_type' => 'nakit',
        ]); // collected_by_user_id YOK
        $this->pushEvents($token, [$tahsilat])->assertOk();
        $tahsilatId = $tahsilat['payload']['id'];

        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $musteriId,
            'entry_type' => 'correction',
            'amount_kurus' => 2000,
            'payment_type' => 'nakit',
            'reverses_entry_id' => $tahsilatId,
        ])])->assertOk()->assertJsonPath('results.0.status', 'applied');

        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $musteriId,
            'entry_type' => 'correction',
            'amount_kurus' => 2000,
            'payment_type' => 'nakit',
            'reverses_entry_id' => $tahsilatId,
            'collected_by_user_id' => $a['kurye']->id, // atıf UYDURULDU
        ])])->assertOk()->assertJsonPath('results.0.status', 'rejected');
    }

    #[Test]
    public function kasaya_dokunmayan_duzeltme_kapiya_ugramaz(): void
    {
        // `payment_type` YOKSA kayıt kasaya dokunmaz (yalnız bakiye düzelir) — arıza doğmaz ve
        // kapı ÇALIŞMAMALI. Kapı geniş tutulsaydı meşru bakiye düzeltmeleri reddedilirdi;
        // `bakiyeDuzeltmesiYaz` tam olarak bu şekli yazıyor.
        [$token, $a, $musteriId] = $this->hazirla();
        $tahsilatId = $this->kuryeninTahsilati($token, $a, $musteriId);

        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $musteriId,
            'entry_type' => 'correction',
            'amount_kurus' => 2000,
            'reverses_entry_id' => $tahsilatId,
            'collected_by_user_id' => $a['patron']->id, // atıf FARKLI ama payment_type YOK
        ])])->assertOk()->assertJsonPath('results.0.status', 'applied');
    }

    #[Test]
    public function serbest_duzeltme_ve_normal_tahsilat_kapiya_ugramaz(): void
    {
        [$token, $a, $musteriId] = $this->hazirla();
        $this->kuryeninTahsilati($token, $a, $musteriId);

        // Serbest düzeltme: `reverses_entry_id` YOK → karşılaştıracak kaynak yok, kapı geçilir.
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $musteriId,
            'entry_type' => 'correction',
            'amount_kurus' => -3000,
            'collected_by_user_id' => $a['patron']->id,
        ])])->assertOk()->assertJsonPath('results.0.status', 'applied');

        // Sıradan tahsilat: `correction` değil → kapı YALNIZ düzeltmede çalışır.
        $this->pushEvents($token, [$this->ledgerEntry([
            'customer_id' => $musteriId,
            'entry_type' => 'payment',
            'amount_kurus' => -4000,
            'payment_type' => 'nakit',
            'collected_by_user_id' => $a['patron']->id,
        ])])->assertOk()->assertJsonPath('results.0.status', 'applied');
    }
}
