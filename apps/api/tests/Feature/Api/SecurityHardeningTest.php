<?php

namespace Tests\Feature\Api;

use PHPUnit\Framework\Attributes\Test;
use Tests\ApiTestCase;

/**
 * Faz 1 güvenlik denetimi düzeltmelerinin bekçisi:
 *  - F1: login kaba kuvvet hız sınırı (throttle:login) → aşımda 429.
 *  - F3: güvenlik başlıkları tüm api yanıtlarında.
 *  - F4: CORS varsayılanı kilitli (izinsiz origin ACAO başlığı ALMAZ).
 *
 * Cache testte `array` sürücüsüdür (phpunit.xml) ve her test taze uygulamada sıfırlanır;
 * bu yüzden sayaçlar testler arası sızmaz.
 */
class SecurityHardeningTest extends ApiTestCase
{
    #[Test]
    public function login_ayni_email_ip_icin_5_denemeden_sonra_429_verir(): void
    {
        $a = $this->makeTenant('a');
        $payload = ['email' => $a['patron']->email, 'password' => 'yanlis-parola'];

        // İlk 5 deneme sınır içinde: kimlik hatası (401), throttle değil.
        for ($i = 1; $i <= 5; $i++) {
            $this->postJson('/api/v1/auth/login', $payload)
                ->assertStatus(401);
        }

        // 6. deneme sınırı aşar: 429 + Retry-After başlığı.
        // (Not: 429 middleware exception'ı olarak render edilir, AppendServerTime'ın post-işlemesini
        // atlar; server_time yalnız denetleyiciden dönen normal JsonResponse'larda bulunur — kapsam dışı.)
        $blocked = $this->postJson('/api/v1/auth/login', $payload);
        $blocked->assertStatus(429);
        $this->assertNotNull($blocked->headers->get('Retry-After'));
    }

    #[Test]
    public function api_yanitlari_guvenlik_basliklarini_tasir(): void
    {
        // Kimlik gerektirmeyen basit bir api yanıtı (422) bile başlıkları taşımalı.
        $response = $this->postJson('/api/v1/auth/login', []);

        $response->assertStatus(422);
        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('X-Frame-Options', 'DENY');
        $response->assertHeader('Referrer-Policy', 'no-referrer');
        $response->assertHeader('X-Permitted-Cross-Domain-Policies', 'none');
    }

    #[Test]
    public function izinsiz_origin_cors_izni_almaz(): void
    {
        // CORS_ALLOWED_ORIGINS testte tanımsız → izinli origin listesi boş.
        // Rastgele bir origin ACAO başlığı ALMAMALI (joker `*` kaldırıldı, F4).
        $response = $this->withHeader('Origin', 'https://kotu-site.example')
            ->postJson('/api/v1/auth/login', []);

        $this->assertNull($response->headers->get('Access-Control-Allow-Origin'));
    }
}
