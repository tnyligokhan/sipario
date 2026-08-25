<?php

namespace Tests\Feature\Api;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * FAZ 6 — Google Play zorunlu hesap/veri silme talebi sayfası (/hesap-silme). Genel erişilebilir,
 * auth gerektirmez, DB gerektirmez (statik view). Play data-safety formu bu URL'e işaret eder.
 *
 * ── 2026-08-19 · İDDİALAR KOPYADAN ÇÖZÜLDÜ ───────────────────────────────────────────────
 * Eski sürüm `assertSee('Hesap ve Veri Silme')` diyordu ve sayfanın BAŞLIĞINI kilitliyordu.
 * Metin doğallaştırılırken başlık "Hesabınızı ve verilerinizi sildirmek" oldu ve test kırıldı —
 * ama kırılan şey bir DAVRANIŞ değil, bir BÜYÜK/KÜÇÜK HARF tercihiydi. Sayfa hâlâ genel
 * erişilebilir, hâlâ süreci anlatıyor, Play'in istediği her şey yerinde.
 *
 * `assertSee('TASLAK')` de aynı sebeple düştü: o kelime, sayfadaki üç yer tutucuyu (destek
 * adresi, saklama süresi, azami işlem süresi) işaret ediyordu. Üçü de bu vardiyada gerçek
 * değerlerine kavuştu — destek adresi config'ten, saklama süreleri VUK m.253 / TTK m.82 /
 * 5651'den, işlem süresi KVKK m.13/2'den. Geriye kalan tek eksik avukat onayıdır ve onu
 * `x-legal.uyari` söylüyor.
 *
 * Bu dosya artık KOPYAYI DEĞİL, SAYFANIN TAŞIMAK ZORUNDA OLDUĞU BİLGİYİ kilitliyor: Play'in
 * şartı (erişilebilirlik + sürecin anlatılması), BRIEF'in şartı (talep destek kanalından),
 * KVKK'nın şartı (sorumlu/işleyen ayrımı + saklama istisnaları + süre). Kopya iyileştikçe
 * kırılmaz; bilgi düşerse kırılır.
 */
class AccountDeletionPageTest extends TestCase
{
    #[Test]
    public function hesap_silme_sayfasi_genel_erisilebilir_ve_silme_surecini_anlatir(): void
    {
        $this->get('/hesap-silme')
            ->assertOk()
            // Play data-safety formu bu sayfaya işaret ediyor; başlığın kendisi sayfanın konusunu
            // söylemeli (hangi kelimelerle söylediği kopya kararıdır, burada kilitlenmez).
            ->assertSee('silme')
            ->assertSee('destek')          // talep destek kanalından yürür (BRIEF: uygulamada buton yok)
            ->assertSee('veri işleyen');   // KVKK: bayi=sorumlu / Sipario=işleyen ayrımı
    }

    #[Test]
    public function hesap_silme_sayfasi_saklama_istisnalarini_dayanagiyla_soyler(): void
    {
        /*
         * "Talep edersen sileriz" demek yetmez ve YANLIŞ da olurdu: fatura, ticari defter ve
         * trafik kayıtları mevzuat gereği silinemez. Kullanıcıya neyin silinMEyeceğini ve
         * NEDEN silinemeyeceğini söylemeyen bir silme sayfası, karşılanamayacak bir söz verir.
         *
         * Süreler dayanağıyla birlikte kilitleniyor — çıplak bir "5 yıl" ifadesi, gerekçesi
         * silindiğinde kimsenin doğrulayamayacağı bir sayıya dönüşür.
         */
        $this->get('/hesap-silme')
            ->assertOk()
            ->assertSee('Vergi Usul Kanunu')
            ->assertSee('Türk Ticaret Kanunu')
            ->assertSee('5651')
            ->assertSee('30 gün');         // KVKK m.13/2 — talebin azami sonuçlandırma süresi
    }

    #[Test]
    public function hesap_silme_sayfasi_hukuk_onayi_beklediğini_belirtir(): void
    {
        // Sayfa bir hukuk metnidir ve diğer on belgeyle aynı kapıya tabidir. Avukat onayı
        // geldiğinde `x-legal.uyari` çağrıları TOPLUCA silinecek; bu iddia o gün bilinçli
        // olarak güncellenir, sessizce düşmez.
        $this->get('/hesap-silme')
            ->assertOk()
            ->assertSee('avukat incelemesinden geçmemiştir');
    }

    #[Test]
    public function hesap_silme_kvkk_belgelerine_baglanir(): void
    {
        $this->get('/hesap-silme')
            ->assertOk()
            ->assertSee('/sozlesme/kvkk-aydinlatma', false)  // aydınlatma metni
            ->assertSee('/sozlesme/veri-isleyen', false)     // sorumlu/işleyen ilişkisinin kaynağı
            ->assertSee('/sozlesme/kvkk-basvuru', false);    // hakkın kullanılma yolu
    }
}
