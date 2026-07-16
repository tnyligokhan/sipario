<?php

namespace Tests\Feature\Api;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * FAZ 6 — Google Play zorunlu hesap/veri silme talebi sayfası (/hesap-silme). Genel erişilebilir,
 * auth gerektirmez, DB gerektirmez (statik view). Play data-safety formu bu URL'e işaret eder.
 */
class AccountDeletionPageTest extends TestCase
{
    #[Test]
    public function hesap_silme_sayfasi_genel_erisilebilir_ve_silme_surecini_anlatir(): void
    {
        $this->get('/hesap-silme')
            ->assertOk()
            ->assertSee('Hesap ve Veri Silme')
            ->assertSee('destek')          // talep destek kanalından yürür (BRIEF: uygulamada buton yok)
            ->assertSee('veri işleyen')    // KVKK: bayi=sorumlu / Sipario=işleyen ayrımı
            ->assertSee('TASLAK');         // iletişim/süre PLACEHOLDER — yayına almadan doldurulacak
    }

    #[Test]
    public function hesap_silme_kvkk_aydinlatma_metnine_baglanir(): void
    {
        $this->get('/hesap-silme')
            ->assertOk()
            ->assertSee('/sozlesme/kvkk-aydinlatma', false); // KVKK belgesine link (route resolve)
    }
}
