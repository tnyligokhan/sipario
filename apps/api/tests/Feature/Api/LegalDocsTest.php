<?php

namespace Tests\Feature\Api;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * FAZ 5d iskeleti — hukuk belgeleri (mesafeli satış / ön bilgilendirme / iptal-iade / KVKK) görüntülenir.
 * Metinler PLACEHOLDER (tam metin + hukuk onayı insan işi); bu test yalnız İSKELETİ (route/view/sürüm/
 * config haritası) doğrular. DB gerektirmez (salt route+view).
 */
class LegalDocsTest extends TestCase
{
    #[Test]
    public function hukuk_belgeleri_baslik_surum_ve_placeholder_uyarisiyla_gorunur(): void
    {
        /** @var array<string, array{title: string, version_key: string}> $docs */
        $docs = config('subscription.legal_docs');
        $this->assertNotEmpty($docs);

        foreach ($docs as $slug => $meta) {
            $version = config('subscription.legal')[$meta['version_key']];

            $this->get("/sozlesme/{$slug}")
                ->assertOk()
                ->assertSee($meta['title'])
                ->assertSee($version)
                ->assertSee('PLACEHOLDER'); // metin hukuk onayından geçmedi işareti
        }
    }

    #[Test]
    public function bilinmeyen_belge_slugu_404_doner(): void
    {
        $this->get('/sozlesme/olmayan-belge')->assertNotFound();
    }
}
