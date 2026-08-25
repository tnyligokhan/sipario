<?php

namespace Tests\Feature\Api;

use App\Eposta\BayiPostacisi;
use App\Mail\Hosgeldiniz;
use App\Mail\IcBildirim;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\Test;
use Symfony\Component\Mime\Email;
use Tests\ApiTestCase;

/**
 * E-POSTA ÇAĞRI YERLERİ — şablonu değil, ŞABLONU POSTAYA BAĞLAYAN KATMANI sürer.
 *
 * NEDEN AYRI BİR DOSYA VAR: `EpostaSablonlariTest` on üç şablonun hepsini gönderiyor ve yeşil
 * yanıyor — ama o test alıcıyı KENDİSİ veriyor (`Mail::to('bayi@ornek.test')->send(...)`). Yani
 * yapı gereği bir çağrı yerinin alıcı vermeyi unutmasını ASLA yakalayamaz. 2026-08-12'de canlıda
 * yaşanan arıza tam olarak buradaydı: şablon kusursuzdu, `ResetPassword::toMailUsing()` bir
 * `Mailable` döndürüp `->to(...)` çağırmıyordu, `MailChannel` de `Mailable` aldığında alıcı ekleme
 * adımını atlıyordu. Üstüne `Parola::baglantiGonder()` istisnayı numaralandırmaya karşı bilerek
 * yuttuğu için ekran "gönderildi" diyordu ve posta hiç çıkmıyordu.
 *
 * Bu dosyanın kuralı: **üretilen her iletinin gerçek bir alıcısı olduğunu, gerçek yoldan geçerek
 * doğrula.** `BayiPostacisi` on üç şablonun sekizinin ortak boğazıdır; sessiz `return false`
 * dalları da (patron yok / adres boş / sentetik kurye adresi) burada tek tek sürülür — çünkü
 * onların her biri "posta gitmedi ama kimse duymadı" demektir.
 */
class EpostaCagriYerleriTest extends ApiTestCase
{
    #[Test]
    public function bayiye_gonderilen_posta_patronun_gercek_adresine_gider(): void
    {
        ['tenant' => $bayi] = $this->makeTenant('postaci');

        $sonuc = BayiPostacisi::gonder($bayi->id, fn (Tenant $b, User $p): Hosgeldiniz => new Hosgeldiniz(
            isletme: $b->name, yetkili: $p->name, firmaKodu: $b->slug, kullaniciAdi: $p->username,
            denemeBitisi: '11 Eylül 2026', denemeGun: 30, hesapUrl: 'https://sipario.com.tr/hesap',
        ));

        $this->assertTrue($sonuc, 'Postacı gönderemedi.');

        $ileti = $this->sonIleti();
        $this->assertNotNull($ileti, 'Hiç ileti üretilmedi.');

        // ASIL İDDİA — kırılan şey buydu.
        $alicilar = $ileti->getTo();
        $this->assertCount(1, $alicilar, 'İletide alıcı yok.');
        $this->assertSame('postaci-patron@sipario.test', $alicilar[0]->getAddress());

        // Yanıt adresi de gerçek olmalı: bayi "ödemem neden eşleşmedi" diye yanıtladığında
        // cevabın hiçbir yere gitmemesi desteği yok saymaktır.
        $this->assertNotEmpty($ileti->getReplyTo(), 'Yanıt adresi yok.');
    }

    #[Test]
    public function kuryenin_sentetik_adresine_posta_gonderilmez(): void
    {
        ['tenant' => $bayi] = $this->makeTenant('sentetik');

        // Patronun adresini `Provisioning::createCourier`ın ürettiği biçime çeviriyoruz. O adres
        // GERÇEK DEĞİLDİR (`<kullanıcı>@<firma-kodu>.sipario.local`) ve oraya gönderilen posta
        // sekerek geri döner; sürekli sekme gönderen alan adının itibarını düşürür.
        Provisioning::asOwner(fn () => User::on('pgsql_owner')
            ->where('tenant_id', $bayi->id)->where('role', 'patron')
            ->update(['email' => 'patron@'.$bayi->slug.'.sipario.local']));

        $sonuc = BayiPostacisi::gonder($bayi->id, fn (Tenant $b, User $p): Hosgeldiniz => new Hosgeldiniz(
            isletme: $b->name, yetkili: $p->name, firmaKodu: $b->slug, kullaniciAdi: $p->username,
            denemeBitisi: '11 Eylül 2026', denemeGun: 30, hesapUrl: 'https://sipario.com.tr/hesap',
        ));

        $this->assertFalse($sonuc, 'Sentetik adrese gönderim engellenmedi.');
        $this->assertNull($this->sonIleti(), 'Sentetik adrese ileti üretildi.');
    }

    #[Test]
    public function pasif_patronun_adresine_posta_gonderilmez(): void
    {
        ['tenant' => $bayi] = $this->makeTenant('pasif');

        Provisioning::asOwner(fn () => User::on('pgsql_owner')
            ->where('tenant_id', $bayi->id)->where('role', 'patron')
            ->update(['status' => 'disabled']));

        $sonuc = BayiPostacisi::gonder($bayi->id, fn (Tenant $b, User $p): Hosgeldiniz => new Hosgeldiniz(
            isletme: $b->name, yetkili: $p->name, firmaKodu: $b->slug, kullaniciAdi: $p->username,
            denemeBitisi: '11 Eylül 2026', denemeGun: 30, hesapUrl: 'https://sipario.com.tr/hesap',
        ));

        $this->assertFalse($sonuc);
        $this->assertNull($this->sonIleti());
    }

    #[Test]
    public function ic_bildirim_destek_kutusuna_gider(): void
    {
        $sonuc = BayiPostacisi::destege(new IcBildirim(
            baslik: 'Veri dışa aktarma talebi',
            konuEki: 'dışa aktarma talebi · test',
            satirlar: ['Bayi' => 'Test Bayii'],
        ));

        $this->assertTrue($sonuc);

        $ileti = $this->sonIleti();
        $this->assertNotNull($ileti);
        $this->assertCount(1, $ileti->getTo());
        $this->assertSame(
            (string) config('subscription.company.support_email'),
            $ileti->getTo()[0]->getAddress(),
        );

        // İç bildirimde konu ön eki KORUNUR — bizim kutumuzda süzgeç anahtarıdır.
        $this->assertStringStartsWith('Sipario · ', (string) $ileti->getSubject());
    }

    /** Test ortamında `MAIL_MAILER=array` (phpunit.xml) — üretilen ileti belleğe düşer. */
    private function sonIleti(): ?Email
    {
        $mesajlar = Mail::getSymfonyTransport()->messages();

        if ($mesajlar->count() === 0) {
            return null;
        }

        /** @var Email $ileti */
        $ileti = $mesajlar->last()->getOriginalMessage();

        return $ileti;
    }
}
