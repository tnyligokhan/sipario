<?php

declare(strict_types=1);

namespace App\Support;

/**
 * STATİK VARLIK ADRESİ — parmak izli (2026-08-28).
 *
 * ── BU SINIFI DOĞURAN ÜRETİM ARIZASI ─────────────────────────────────────────────────────────
 * Canlıda ölçüldü: `https://sipario.com.tr/css/site.css` yanıtı
 * `Cache-Control: public, max-age=31536000, immutable` taşıyor (uygulama imajının kendi nginx
 * ayarı) ve Cloudflare'de `cf-cache-status: HIT`, `Age: 168463` — yani **47 saatlik bayat CSS**.
 * Görünümler ise dosyayı `asset('css/site.css')` ile, SORGUSUZ basıyordu.
 *
 * Sonucu şuydu: deploy HTML'i yeniler, CSS'i yenilemez. Ziyaretçi YENİ İŞARETLEMEYİ ESKİ
 * BİÇEMLE görür. 2026-08-28'de tam olarak bu yaşandı — yeni çerez penceresinin işaretlemesi
 * canlıya gitti, biçemi gitmedi ve pencere biçemsiz hâlde tam ekranı kapladı. Kullanıcının
 * gördüğü "rezalet" ekranın sebebi tasarım değil, bu önbellekti.
 *
 * ── ÇÖZÜM: ADRESİ DEĞİŞTİR, BAŞLIĞI DEĞİL ────────────────────────────────────────────────────
 * `immutable` YANLIŞ BİR BAŞLIK DEĞİLDİR; yalnız bir SÖZ verir: "bu adresteki içerik asla
 * değişmez". Sözü tutmanın yolu dosya değiştiğinde ADRESİ değiştirmektir. Başlığı gevşetmek
 * (ör. `max-age=300`) her ziyaretçiye sürekli yeniden indirme yükü bindirirdi ve asıl kusuru —
 * "HTML ile CSS'in sürümleri ayrışabiliyor" — kapatmazdı.
 *
 * Damga dosyanın kendi değişiklik zamanıdır: dosya değişince adres değişir, değişmeyince
 * ziyaretçi bir yıl boyunca hiç indirmez. Uygulama sürümünü (`config('app.version')`) damga
 * yapmak CAZİPTİ ama yanlış olurdu — yalnız CSS düzelten bir vardiya sürümü artırmayabilir
 * (kural: kullanıcıya görünmeyen iç düzenleme artış almaz) ve o gün damga sabit kalıp arıza
 * geri gelirdi.
 *
 * ── NEDEN `Vite::asset` DEĞİL ────────────────────────────────────────────────────────────────
 * Bu iki dosya Vite hattından GEÇMİYOR: `public/css/site.css` tasarım paketinden birebir
 * kopyalanmış bir kaynaktır (dosyanın kendi belge başlığı "sınıf adları BİREBİR korunmuştur,
 * sözleşmedir" diyor) ve `public/js/*.js` derlemesiz, CSP dostu düz betiklerdir. Onları Vite'a
 * taşımak bu vardiyanın işi değildi ve tek satırlık kusuru büyük bir göçe çevirirdi.
 */
final class Varlik
{
    /**
     * `public/` altındaki bir dosyanın parmak izli genel adresi.
     *
     * Dosya yoksa damga uygulama sürümünden türetilir: eksik dosya için `?s=0` basmak, ilk
     * deployda tüm ziyaretçileri aynı bayat adrese kilitlerdi.
     */
    public static function url(string $yol): string
    {
        return asset($yol).'?s='.self::damga($yol);
    }

    private static function damga(string $yol): string
    {
        $tam = public_path($yol);

        // filemtime PHP'nin stat önbelleğine düşer; aynı istekte tekrar çağırmak diske gitmez.
        if (is_file($tam) && ($zaman = @filemtime($tam)) !== false) {
            return dechex($zaman);
        }

        return substr(sha1((string) config('app.version')), 0, 8);
    }
}
