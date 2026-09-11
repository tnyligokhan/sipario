<?php

namespace App\Panel;

use Illuminate\Support\Str;

/**
 * Aktarımdaki FAVORİ ÜRÜN ADLARINI ürün kimliklerine çevirir; bayide olmayan ürünü OLUŞTURUR.
 *
 * NEDEN OTOMATİK OLUŞTURMA (kullanıcı isteği 2026-09-11): bayinin eski listesinde favori,
 * "TOMBUL", "MADRAN" gibi bir ÜRÜN ADIDIR — kimlik değil. `customers.favorite_product_ids`
 * ise kimlik taşır (migration 004010). Arada bir eşleme olmak zorunda ve bunu kullanıcıya
 * yaptırmak, aktarımdan önce altı ürünü elle açmasını ve kimliklerini CSV'ye yapıştırmasını
 * istemek demekti — taşımayı imkânsız kılan tam da bu tür bir el işidir.
 *
 * EŞLEME AD ÜZERİNDEN VE BÜYÜK/KÜÇÜK HARF DUYARSIZ: aynı dosyada "Tombul Tüp" ve "TOMBUL TÜP"
 * geçebilir; iki ayrı ürün açmak bayinin kataloğunu ilk günden ikiye böler. Türkçe kıvrımı
 * gözetilir (`mb_strtolower(..., 'UTF-8')` İ/ı ayrımında ASCII'den doğru davranır).
 *
 * FİYAT SIFIR AÇILIR: dosyada fiyat yoktur ve uydurmak yanlış olurdu — bayi ürün ekranından
 * kendi fiyatını girer. Sıfır fiyat GÖRÜNÜR bir eksikliktir; uydurulmuş bir fiyat ise sessizce
 * yanlış siparişe düşer (order_lines fiyatı satırda saklar — yanlış fiyat kalıcı olur).
 *
 * ÜRÜN OLAYLARI MÜŞTERİLERDEN ÖNCE GÖNDERİLİR. Sunucu tarafı bunu zorlamaz (FavoriUrunler
 * bilinçli olarak ürün varlığını doğrulamaz) ama İSTEMCİ çözemediği kimliği ATLAR: ürünler
 * sonra inseydi, ilk senkron turunda favoriler telefonda boş görünürdü.
 */
final class AktarimUrunleri
{
    /** @var array<string, string> sadeleştirilmiş ad → ürün kimliği */
    private array $harita = [];

    /** @var list<array<string, mixed>> Bayide olmayıp bu aktarımda açılan ürünlerin olayları */
    private array $yeniOlaylar = [];

    /** @var list<string> Açılan ürünlerin adları (sonuç raporunda gösterilir) */
    private array $yeniAdlar = [];

    /**
     * @param  array<string, string>  $mevcutUrunler  ad → kimlik (bayide kayıtlı ürünler)
     * @param  callable(array<string, mixed>): array<string, mixed>  $olayUret  PanelSyncYazici::olay
     */
    public function __construct(array $mevcutUrunler, private readonly mixed $olayUret)
    {
        foreach ($mevcutUrunler as $ad => $id) {
            $this->harita[self::sade((string) $ad)] = (string) $id;
        }
    }

    /**
     * Ürün adının kimliği. Bayide yoksa kimlik ÜRETİLİR ve ürün olayı kuyruğa alınır — aynı ad
     * ikinci kez sorulduğunda aynı kimlik döner (dosyadaki 9.000 satır altı ürüne indirgenir).
     */
    public function kimlik(string $ad): string
    {
        $anahtar = self::sade($ad);
        if (isset($this->harita[$anahtar])) {
            return $this->harita[$anahtar];
        }

        $id = (string) Str::uuid7();
        $this->harita[$anahtar] = $id;
        $this->yeniAdlar[] = $ad;
        $this->yeniOlaylar[] = ($this->olayUret)([
            'id' => $id,
            'name' => $ad,
            'unit_price_kurus' => 0, // bayi kendi fiyatını girer (bkz. sınıf açıklaması)
            'unit' => 'adet',
            'is_active' => true,
        ]);

        return $id;
    }

    /**
     * Bir satırın favori ad listesini kimlik listesine çevirir.
     *
     * @param  list<string>  $adlar
     * @return list<string>
     */
    public function kimlikler(array $adlar): array
    {
        return array_map($this->kimlik(...), $adlar);
    }

    /**
     * Bekleyen ürün olaylarını VERİR VE KUYRUĞU BOŞALTIR. Tek adım olması bilinçli: okuyup
     * temizlemeyi iki çağrıya bölmek, aradan dönen bir `continue` yüzünden aynı ürünü ikinci
     * kez göndermeye açık bırakırdı (aynı kimlikle ikinci upsert zararsızdır ama olay tavanını
     * boşuna yer ve "neden iki kere yazıldı" sorusunu doğurur).
     *
     * @return list<array<string, mixed>>
     */
    public function kuyruguBosalt(): array
    {
        $olaylar = $this->yeniOlaylar;
        $this->yeniOlaylar = [];

        return $olaylar;
    }

    /** @return list<string> */
    public function acilanUrunler(): array
    {
        return $this->yeniAdlar;
    }

    private static function sade(string $ad): string
    {
        return mb_strtolower(preg_replace('/\s+/u', ' ', trim($ad)) ?? '', 'UTF-8');
    }
}
