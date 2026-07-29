<?php

namespace Database\Seeders;

use App\Enums\TenantStatus;
use App\Enums\UserRole;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Database\Seeders\Demo\DemoFabrika;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * İÇİ DOLU DEMO BAYİSİ — hem mağaza incelemesi (Faz 6, BRIEF: "içi dolu bir demo hesabı") hem de
 * geliştirici/saha denemesi için. Uygulamanın HER ekranı bu veriyle dolu görünmelidir: boş liste,
 * boş defter, boş çağrı geçmişi kalmamalı; her durum (borçlu · temiz · alacaklı, konumlu ·
 * konumsuz, açık · teslim · iptal, atanmış · atanmamış) en az bir kez geçmeli.
 *
 * GİRİŞ (tasarım `s-giris.jsx`: firma kodu + kullanıcı adı + parola):
 *   Firma Kodu `111` · Kullanıcı Adı `111` · Parola `1111`   (patron)
 *
 * ⚠️ GEÇİCİ — SAHA TESTİ KOLAYLIĞI (kullanıcı isteği 2026-07-29). Öncesi `demo/demo/demo1234`.
 * MAĞAZA BAŞVURUSUNDAN ÖNCE GERİ ALINMALI: `docs/magaza/inceleme-notlari.md` incelemeciye bu
 * bilgileri veriyor ve "1111" parolalı bir hesap, incelemeden geçse bile üçüncü kişilerin
 * kolayca gireceği bir kapıdır (depo PUBLIC, saha sunucusu tünelle dışarı açık).
 * PLAN.md "İnsan gerektiren işler" listesine borç olarak yazıldı.
 *
 * NEDEN `1/1/1` DEĞİL: `LoginRequest` firma kodu ve kullanıcı adı için `{3,}`, parola için
 * `min:4` istiyor (mobil tarafta `login_screen.dart` aynı kuralı tekrarlıyor). Tek karakterli
 * değerler doğrulamaya takılır ve giriş DENEMESİ bile yapılmaz. Kuralları gevşetmek ürünün
 * kimlik kurallarına dokunmak olurdu — kolaylık için kalıcı bir kapı açılmaz; kuralları geçen
 * en kısa değerler seçildi (3+3+4 dokunuş, hepsi aynı tuş).
 * Rol denemeleri için aynı parolayla: `nazli` (operator), `emre` / `hakan` (kurye).
 *
 * AKTİF + uzun valid_until (inceleme sırasında kilitlenmez). İDEMPOTENT: demo bayisi varsa
 * yeniden kurmaz — sıfırdan kurmak için önce veritabanını tazele
 * (`php artisan migrate:fresh --database=pgsql_owner --force`).
 *
 * BU SAHTE VERİDİR: adlar, telefonlar, adresler uydurmadır (KVKK — gerçek kişi verisi değil,
 * gerçek bir bayiye verilmez).
 */
class DemoSeeder extends Seeder
{
    public const DEMO_EMAIL = 'demo@sipario.com.tr';

    /**
     * Mağaza inceleme hesabının GİRİŞ kimliği (tasarım `s-giris.jsx`).
     * ⚠️ GEÇİCİ değerler — gerekçe ve geri alma borcu sınıf başlığında.
     */
    public const DEMO_TENANT_CODE = '111';

    public const DEMO_USERNAME = '111';

    public const DEMO_PASSWORD = '1111';

    public function run(): void
    {
        Provisioning::asOwner(function () {
            if (Tenant::query()->where('slug', self::DEMO_TENANT_CODE)->exists()) {
                $this->command->info('Demo bayisi zaten var — atlandı.');

                return;
            }

            $tenant = $this->bayi();
            $f = new DemoFabrika($tenant->id);
            $ekip = $this->ekip($f);
            $urun = $this->katalog($f);
            $musteri = $this->musteriler($f);

            $this->isletme($f);
            $this->siparisler($f, $ekip, $urun, $musteri);
            $this->defterHareketleri($f, $ekip, $musteri);
            $this->cagriGunlugu($f, $musteri);
            $this->gecmisKapanis($f, $ekip);

            $f->bakiyeTazele(...array_values($musteri));

            $this->command->info(
                'Demo bayisi kuruldu — Firma Kodu: '.self::DEMO_TENANT_CODE
                .' · Kullanıcı: '.self::DEMO_USERNAME.' · Parola: '.self::DEMO_PASSWORD
            );
        });
    }

    private function bayi(): Tenant
    {
        $tenant = Tenant::create([
            'name' => 'Merkez Su Bayii',
            'slug' => self::DEMO_TENANT_CODE,
            'status' => TenantStatus::Active->value,
            'trial_ends_at' => now()->addDays(30),
            'valid_until' => now()->addYears(10),   // inceleme boyunca kilitlenmesin
            'phone' => '02423441100',
            // Oto sıralama kontörü: incelemeci/geliştirici özelliği GERÇEKTEN deneyebilsin.
            // Kontörsüz hesapta düğme hiç çizilmez ve "özellik yok" sanılır.
            'route_credits' => 34,
            'route_credits_monthly' => 50,
        ]);

        DB::table('tenant_sync_state')->insertOrIgnore(['tenant_id' => $tenant->id, 'last_seq' => 0]);

        return $tenant;
    }

    /**
     * Patron + operator + iki AKTİF kurye + bir PASİF kurye.
     * Pasif kurye bilerek var: "Pasif" rozeti ve "atama kapalı" davranışı boş ekranla sınanamaz.
     *
     * @return array<string, User>
     */
    private function ekip(DemoFabrika $f): array
    {
        $patron = $f->kullanici('Mehmet Usta', self::DEMO_USERNAME, UserRole::Patron->value,
            self::DEMO_PASSWORD, '0532 344 11 00');
        // Mağaza incelemesi bu e-postayı bekliyor (docs/magaza/inceleme-notlari.md).
        $patron->forceFill(['email' => self::DEMO_EMAIL])->save();

        return [
            'patron' => $patron,
            'nazli' => $f->kullanici('Nazlı Tezgâhtar', 'nazli', UserRole::Operator->value,
                self::DEMO_PASSWORD, '0533 344 11 01'),
            'emre' => $f->kullanici('Emre Kurye', 'emre', UserRole::Kurye->value,
                self::DEMO_PASSWORD, '0532 415 90 11'),
            'hakan' => $f->kullanici('Hakan Kurye', 'hakan', UserRole::Kurye->value,
                self::DEMO_PASSWORD, '0533 415 90 22'),
            'eski' => $f->kullanici('Kemal Kurye', 'kemal', UserRole::Kurye->value,
                self::DEMO_PASSWORD, null, 'disabled'),
        ];
    }

    /**
     * Sektöre kilitlenmeyen katalog: farklı birimler (adet/koli/kasa/kg/hizmet), barkodlu ve
     * barkodsuz ürünler (POS'ta okutma ile aramanın ikisi de denenebilsin) ve bir PASİF ürün.
     *
     * @return array<string, Product>
     */
    private function katalog(DemoFabrika $f): array
    {
        return [
            'damacana19' => $f->urun('Damacana 19 L', 4500, 'adet', '8690521000117'),
            'damacana10' => $f->urun('Damacana 10 L', 3000, 'adet', '8690521000100'),
            'paket05' => $f->urun('Paket Su 0,5 L (12li)', 9000, 'koli', '8690521000124'),
            'paket5' => $f->urun('Paket Su 5 L (6lı)', 6000, 'koli'),
            'tup' => $f->urun('Tüp 12 kg', 78000, 'adet'),
            'domates' => $f->urun('Kasa Domates', 16000, 'kasa', '8690521000148'),
            'kuruyemis' => $f->urun('Karışık Kuruyemiş', 32000, 'kg'),
            'pompa' => $f->urun('Damacana Pompası', 12000, 'adet', '8690521000155'),
            'sebil' => $f->urun('Sebil Temizliği', 20000, 'hizmet'),
            'bardak' => $f->urun('Bardak Su (eski)', 500, 'adet', null, aktif: false),
        ];
    }

    /**
     * 11 müşteri. Bakiyeler defterden TÜRETİLİR — burada yalnız kim/nerede tanımlanır.
     * Konumu olan ve olmayan bilerek karışık: "Konum Al" akışı ve rota sıralamasındaki
     * "konumsuz sona alınır" kuralı ancak böyle görülebilir.
     *
     * @return array<string, Customer>
     */
    private function musteriler(DemoFabrika $f): array
    {
        return [
            'ahmet' => $f->musteri('Ahmet Yılmaz', ['0532 415 22 90', '0242 344 11 05'],
                'Cumhuriyet Mah. 5. Sk. No:12/4', 'Kepez', [36.9125, 30.6689],
                'Zil çalışmıyor, gelince arayın.'),
            'selin' => $f->musteri('Selin Kaya', ['0533 220 78 41'],
                'Bahçelievler Mah. 118. Sk. No:3', 'Muratpaşa', [36.8841, 30.7056]),
            'murat' => $f->musteri('Murat Öz', ['0542 907 63 22'],
                'Fener Mah. Deniz Cad. No:44/2', 'Lara', null,
                'Kapıda kart geçmiyor.', adresEtiketi: 'İş'),
            'hatice' => $f->musteri('Hatice Demir', ['0505 118 40 77'],
                'Şirinyalı Mah. 42. Sk. No:9', 'Muratpaşa', [36.8790, 30.7290]),
            'ibrahim' => $f->musteri('İbrahim Şahin', ['0555 632 09 18'],
                'Güzeloba Mah. 2312. Sk. No:1', 'Lara', [36.8632, 30.7809],
                'Sabah 9 öncesi aramayın.'),
            'zeynep' => $f->musteri('Zeynep Aydın', ['0544 771 30 62'],
                'Liman Mah. Akdeniz Blv. No:88', 'Konyaaltı', [36.8608, 30.6284]),
            'osman' => $f->musteri('Osman Çelik', ['0537 402 15 73'],
                'Varsak Mah. 105. Cad. No:7', 'Kepez', null),
            'elif' => $f->musteri('Elif Kurt', ['0546 018 92 34'],
                'Hurma Mah. 356. Sk. No:22', 'Konyaaltı', [36.8672, 30.6047]),
            'huseyin' => $f->musteri('Hüseyin Arslan', ['0507 663 24 09'],
                'Yeniköy Mah. 1. Sk. No:3', 'Döşemealtı', [37.0089, 30.6021]),
            'serife' => $f->musteri('Şerife Yıldız', ['0538 145 77 26'],
                'Meltem Mah. 3806. Sk. No:14', 'Muratpaşa', null),
            'kadir' => $f->musteri('Kadir Doğan', ['0553 289 61 40', '0242 316 88 12'],
                'Çağlayan Mah. 2039. Sk. No:6', 'Lara', [36.8564, 30.7601],
                'Kapı kodu 1907.'),
        ];
    }

    private function isletme(DemoFabrika $f): void
    {
        $f->isletmeProfili([
            'business_name' => 'Merkez Su Bayii',
            'owner_name' => 'Mehmet Usta',
            'phone' => '0242 344 11 00',
            'whatsapp' => '0532 344 11 00',
            'address_text' => 'Yeşilbahçe Mah. Portakal Çiçeği Blv. No:21/A, Muratpaşa / Antalya',
            'tax_office' => 'Muratpaşa',
            'tax_number' => '1234567890',
            'opens_at' => '08:00',
            'closes_at' => '19:00',
            'receipt_note' => 'Bizi tercih ettiğiniz için teşekkürler.',
        ]);
    }

    /**
     * 15 sipariş: 6 açık (atanmış/atanmamış, notlu, serbest satırlı) · 8 teslim (dört ödeme tipi
     * de geçer; biri müşterisiz TEZGÂH satışı) · 1 iptal. Saatler bugüne ve düne yayılır ki
     * "saate göre" sıralama ve gün sonu/arşiv anlamlı görünsün.
     *
     * @param  array<string, User>  $ekip
     * @param  array<string, Product>  $u
     * @param  array<string, Customer>  $m
     */
    private function siparisler(DemoFabrika $f, array $ekip, array $u, array $m): void
    {
        $bugun = fn (int $saat, int $dk = 0) => now()->startOfDay()->setTime($saat, $dk);
        $dun = fn (int $saat, int $dk = 0) => now()->subDay()->startOfDay()->setTime($saat, $dk);

        // ── AÇIK (teslim bekliyor) ──────────────────────────────────────────────────────────
        $f->siparis($m['ahmet'], [['urun' => $u['damacana19'], 'adet' => 2]], $bugun(10, 24),
            kurye: $ekip['emre'], not: 'Zil çalışmıyor, arayın.');
        $f->siparis($m['zeynep'], [['urun' => $u['damacana19'], 'adet' => 4]], $bugun(10, 40),
            kurye: $ekip['hakan']);
        $f->siparis($m['elif'], [['urun' => $u['paket05'], 'adet' => 1],
            ['urun' => $u['damacana10'], 'adet' => 2]], $bugun(11, 5));
        $f->siparis($m['kadir'], [['urun' => $u['tup'], 'adet' => 1]], $bugun(11, 30),
            kurye: $ekip['emre'], not: 'Kapı kodu 1907, 3. kat.',
            serbest: [['ad' => 'Merdiven çıkışı', 'tutar' => 5000]]);
        $f->siparis($m['osman'], [['urun' => $u['domates'], 'adet' => 2]], $bugun(12, 15));
        $f->siparis($m['serife'], [['urun' => $u['sebil'], 'adet' => 1]], $bugun(13, 0),
            kurye: $ekip['hakan'], serbest: [['ad' => 'Filtre değişimi', 'tutar' => 7500]]);

        // ── TESLİM (dört ödeme tipi de temsil edilir) ───────────────────────────────────────
        $f->siparis($m['selin'], [['urun' => $u['domates'], 'adet' => 1]], $bugun(9, 15),
            durum: 'delivered', odeme: 'kart', kurye: $ekip['emre']);
        $f->siparis($m['ibrahim'], [['urun' => $u['damacana19'], 'adet' => 1]], $bugun(9, 5),
            durum: 'delivered', odeme: 'nakit', kurye: $ekip['emre']);
        $f->siparis($m['huseyin'], [['urun' => $u['paket5'], 'adet' => 3]], $bugun(9, 45),
            durum: 'delivered', odeme: 'havale', kurye: $ekip['hakan']);
        $f->siparis($m['hatice'], [['urun' => $u['paket05'], 'adet' => 1],
            ['urun' => $u['kuruyemis'], 'adet' => 1]], $bugun(8, 30),
            durum: 'delivered', odeme: 'veresiye', kurye: $ekip['hakan']);
        $f->siparis($m['ahmet'], [['urun' => $u['tup'], 'adet' => 1]], $dun(16, 20),
            durum: 'delivered', odeme: 'veresiye', kurye: $ekip['emre']);
        $f->siparis($m['zeynep'], [['urun' => $u['damacana19'], 'adet' => 6]], $dun(15, 10),
            durum: 'delivered', odeme: 'veresiye', kurye: $ekip['hakan']);
        $f->siparis($m['kadir'], [['urun' => $u['pompa'], 'adet' => 1]], $dun(11, 40),
            durum: 'delivered', odeme: 'veresiye', kurye: $ekip['emre']);
        // Tezgâh satışı: müşteri YOK → veresiye seçilemez (tasarımın kuralı), nakit kapanır.
        $f->siparis(null, [['urun' => $u['kuruyemis'], 'adet' => 1]], $bugun(8, 40),
            durum: 'delivered', odeme: 'nakit', tahsilEden: $ekip['patron']);

        // ── İPTAL ───────────────────────────────────────────────────────────────────────────
        $f->siparis($m['murat'], [['urun' => $u['damacana19'], 'adet' => 1]], $dun(17, 5),
            durum: 'cancelled', not: 'Müşteri vazgeçti.');
    }

    /**
     * Sipariş dışı defter hareketleri: elle tahsilat, fazla ödemeden doğan ALACAK ve bir
     * DÜZELTME (ters kayıt). Üç bakiye durumunun (borç · temiz · alacak) hepsi listede görünsün.
     *
     * @param  array<string, User>  $ekip
     * @param  array<string, Customer>  $m
     */
    private function defterHareketleri(DemoFabrika $f, array $ekip, array $m): void
    {
        // Ahmet dünkü borcunun bir kısmını nakit kapatır — borçlu KALIR (kısmi tahsilat).
        $f->defter($m['ahmet'], 'payment', -30000, odeme: 'nakit',
            zaman: now()->subHours(2), tahsilEden: $ekip['emre'], not: 'Kısmi tahsilat');

        // Murat fazla ödeme yaptı → ALACAKLI duruma geçer (eksi bakiye, tasarımda yeşil "Alacak").
        $f->defter($m['murat'], 'credit', -12000, odeme: 'havale',
            zaman: now()->subHours(5), not: 'Fazla ödeme');

        // Kadir'e yanlış yazılan tutar DÜZELTİLİR: orijinal satır silinmez, ters kayıt eklenir.
        $yanlis = $f->defter($m['kadir'], 'debit', 5000,
            zaman: now()->subHours(6), not: 'Yanlış girilen nakliye');
        $f->defter($m['kadir'], 'correction', -5000,
            zaman: now()->subHours(4), not: 'Nakliye iki kez yazılmış — düzeltildi',
            tersKayit: $yanlis->id);

        // Hüseyin peşin çalışır; hesabı TEMİZ kalsın diye ek hareket YOK (0 bakiye durumu).
    }

    /**
     * Çağrı geçmişi — ana ekrandaki "Son Arama" kutusunu ve Ayarlar→Çağrı Geçmişi listesini
     * besler. Kayıtsız numara BİLEREK var: çağrı kartının "Kayıtsız" varyantı denenebilsin.
     *
     * @param  array<string, Customer>  $m
     */
    private function cagriGunlugu(DemoFabrika $f, array $m): void
    {
        $f->cagri($m['ahmet'], '0532 415 22 90', 'incoming', now()->subMinutes(12), 'Sipariş alındı');
        $f->cagri($m['zeynep'], '0544 771 30 62', 'incoming', now()->subMinutes(48), 'Sipariş alındı');
        $f->cagri(null, '0216 555 01 88', 'missed', now()->subHours(1), 'Kayıtsız numara');
        $f->cagri($m['murat'], '0542 907 63 22', 'incoming', now()->subHours(2), 'Teslim edildi');
        $f->cagri($m['selin'], '0533 220 78 41', 'outgoing', now()->subHours(4), null);
        $f->cagri($m['kadir'], '0553 289 61 40', 'incoming', now()->subHours(6), 'Adres güncellendi');

        // Muaf numaralar: bunlar aradığında çağrı kartı AÇILMAZ.
        $f->muaf('Emre Kurye', '0532 415 90 11');
        $f->muaf('Tedarikçi · Su Fabrikası', '0242 999 10 20');
    }

    /**
     * Dünün kapanışı — Gün Sonu ekranındaki "Arşiv" bölümü boş kalmasın. Fark BİLEREK eksi:
     * eksik paranın kanıt olarak arşivde durduğu (ve kapatmayı engellemediği) görülebilsin.
     *
     * @param  array<string, User>  $ekip
     */
    private function gecmisKapanis(DemoFabrika $f, array $ekip): void
    {
        $dun = now()->subDay()->startOfDay()->setTime(18, 5);

        $f->gunKapanisi($dun->copy()->subMinutes(20), teslimat: 3, nakit: 22500, kart: 0,
            havale: 0, sayilan: 22000, kurye: $ekip['emre'], not: 'Bozuk para eksik çıktı.');
        $f->gunKapanisi($dun, teslimat: 7, nakit: 48000, kart: 16000, havale: 18000,
            sayilan: 48000);
    }
}
