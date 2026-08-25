<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Support\Facades\Notification;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * MOBİL PAROLA KURTARMA (kullanıcı isteği 2026-08-13) — `POST /v1/auth/parola-sifirla`.
 *
 * ══ KAPATILAN BOŞLUK ═══════════════════════════════════════════════════════════════════════
 * Mobilde parola kurtarma yolu HİÇ YOKTU; kullanıcı parolasını unuttuğunda tek çare birini
 * aramaktı. Pilot bayilerde bu birinci sıradaki destek çağrısıdır.
 *
 * ══ İKİ AYRI GERÇEK ════════════════════════════════════════════════════════════════════════
 * PATRON'un e-postası gerçektir → bağlantı gider. KURYE/OPERATÖR'ün adresi SENTETİKTİR
 * (`<kullanıcı>@<kod>.sipario.local`) ve oraya giden posta hiçbir yere ulaşmaz → uç nokta
 * onlar için bilinçli olarak HİÇBİR ŞEY YAPMAZ.
 *
 * ⚠️ BU DOSYANIN ASIL KİLİDİ NUMARALANDIRMADIR: dört farklı girdiye (patron · kurye · olmayan
 * kullanıcı · olmayan firma) verilen yanıt BİREBİR AYNI olmalıdır. Ayrışan tek bir cümle,
 * geçerli firma kodu + kullanıcı adı çiftlerinin tek tek numaralandırılmasına kapı açar
 * (`login`in nötr hata kuralının aynısı).
 */
class ParolaSifirlamaApiTest extends ApiTestCase
{
    private function iste(string $tenantCode, string $username): TestResponse
    {
        return $this->postJson('/api/v1/auth/parola-sifirla', [
            'tenant_code' => $tenantCode,
            'username' => $username,
        ]);
    }

    #[Test]
    public function patrona_sifirlama_baglantisi_gonderilir(): void
    {
        Notification::fake();
        $a = $this->makeTenant('a');

        $this->iste($a['tenant']->slug, 'patron')->assertOk();

        Notification::assertSentTo($a['patron'], ResetPassword::class);
    }

    #[Test]
    public function kuryeye_posta_gonderilmez_cunku_adresi_sentetiktir(): void
    {
        // Kurye adresi `<kullanıcı>@<kod>.sipario.local` — gerçek bir kutuya karşılık gelmez.
        // Gönderseydik akış "gönderdik" der, posta kaybolur ve kullanıcı bağlantıyı bekleyerek
        // kilitli kalırdı. Hata hiçbir yerde GÖRÜNMEZDİ.
        Notification::fake();
        $a = $this->makeTenant('a');

        $this->iste($a['tenant']->slug, $a['kurye']->username)->assertOk();

        Notification::assertNothingSent();
    }

    #[Test]
    public function yanit_dort_durumda_da_ayni_kalir(): void
    {
        // NUMARALANDIRMA KAPISI. "Gönderildi" / "böyle bir hesap yok" / "bu hesap kurye"
        // ayrımı yapmak, saldırgana geçerli firma kodu + kullanıcı adı çiftlerini tarama
        // imkânı verirdi. Ekran bu yüzden iki gerçeği ÖNCEDEN yazar: cevaptan öğrenilemeyecek
        // şeyi baştan söylemek hem dürüst hem güvenlidir.
        Notification::fake();
        $a = $this->makeTenant('a');

        $yanitlar = [
            $this->iste($a['tenant']->slug, 'patron'),
            $this->iste($a['tenant']->slug, $a['kurye']->username),
            $this->iste($a['tenant']->slug, 'boyle-bir-kullanici-yok'),
            $this->iste('boyle-bir-firma-yok', 'patron'),
        ];

        foreach ($yanitlar as $yanit) {
            $yanit->assertOk();
            $this->assertSame(
                $yanitlar[0]->json('message'),
                $yanit->json('message'),
                'yanıt metni girdiye göre DEĞİŞMEMELİ — ayrışan tek cümle numaralandırma açar'
            );
        }
    }

    #[Test]
    public function pasif_patrona_gonderilmez(): void
    {
        Notification::fake();
        $a = $this->makeTenant('a');
        $this->asOwner(fn () => User::query()->whereKey($a['patron']->id)
            ->update(['status' => 'disabled']));

        $this->iste($a['tenant']->slug, 'patron')->assertOk();

        Notification::assertNothingSent();
    }

    #[Test]
    public function baska_bayinin_patronu_bu_firma_koduyla_bulunamaz(): void
    {
        // Kırmızı çizgi #1'in bu uçtaki karşılığı: arama (firma kodu, kullanıcı adı) ÇİFTİYLE
        // yapılır. A'nın koduyla B'nin patronu istenirse hiçbir şey gönderilmemeli — aksi
        // hâlde bir bayi, başka bir bayinin patronuna posta yağdırabilirdi.
        Notification::fake();
        $a = $this->makeTenant('a');
        $b = $this->makeTenant('b');

        $this->iste($a['tenant']->slug, $b['patron']->username)->assertOk();

        Notification::assertNotSentTo($b['patron'], ResetPassword::class);
    }
}
