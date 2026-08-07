<?php

namespace App\Panel;

use Illuminate\Http\Response;

/**
 * CSV okuma/yazma (5c-3 · D4). Bu dosyanın tamamı "Excel'den gelen gerçek dosya" ile "tarifteki
 * temiz CSV" arasındaki farkı kapatmak içindir.
 *
 * YAZARKEN — FORMÜL ENJEKSİYONU: `=`, `+`, `-`, `@` (ve sekme/CR) ile başlayan bir hücre, dosya
 * Excel/LibreOffice'te açıldığında FORMÜL olarak yorumlanır. `=HYPERLINK(...)` ya da `=cmd|...`
 * içeren bir müşteri adı, dışa aktarımı açan kişinin makinesinde çalışabilir — veriyi biz üretmiyoruz,
 * bayinin kullanıcıları giriyor. Tehlikeli başlangıçlar tek tırnakla kaçırılır.
 *
 * Ama SAYILAR kaçırılmaz: `-1500` gibi negatif tutarlar tehlikeli değildir ve tırnaklanırsa
 * elektronik tablo onları metin sayar — dışa aktarımın işe yaramaz hâle gelmesi de bir arızadır.
 * Kural bu yüzden "tehlikeli karakterle başlıyor VE sayı değil" biçiminde dar tutulmuştur.
 *
 * OKURKEN — TÜRKÇE EXCEL GERÇEĞİ: ayırıcı `;` de olabilir `,` da (Windows bölge ayarına göre),
 * dosya UTF-8 BOM'lu ya da Windows-1254 kodlu gelebilir. Üçü de sessizce düzeltilir; düzeltilmezse
 * "Şükrü" satırı bozuk okunur ve içe aktarım kullanıcının hatası sanılırdı.
 */
class Csv
{
    /** Dışa aktarımda kullanılan ayırıcı — TR Excel varsayılanı. */
    public const AYIRAC = ';';

    /** Formül olarak yorumlanabilecek başlangıçlar (OWASP CSV injection). */
    private const TEHLIKELI = ['=', '+', '-', '@', "\t", "\r"];

    /**
     * Bir hücreyi elektronik tablo için güvenli hâle getirir.
     * Sayısal değerler DOKUNULMADAN geçer (bkz. sınıf açıklaması).
     */
    public static function hucre(string|int|float|null $deger): string
    {
        $metin = (string) ($deger ?? '');
        if ($metin === '') {
            return '';
        }

        if (! in_array($metin[0], self::TEHLIKELI, true)) {
            return $metin;
        }

        // Negatif sayı / ondalık: formül değil, veri.
        if (preg_match('/^-?\d+(?:[.,]\d+)?$/', $metin) === 1) {
            return $metin;
        }

        return "'".$metin;
    }

    /**
     * Başlık + satırlardan CSV metni üretir. BOM eklenir: BOM'suz UTF-8'i Excel bölge kod sayfasıyla
     * açar ve Türkçe karakterler bozulur.
     *
     * @param  list<string>  $basliklar
     * @param  iterable<int, list<string|int|float|null>>  $satirlar
     */
    public static function olustur(array $basliklar, iterable $satirlar): string
    {
        $akis = fopen('php://temp', 'r+');
        fwrite($akis, "\xEF\xBB\xBF");

        fputcsv($akis, array_map(self::hucre(...), $basliklar), self::AYIRAC, '"', '\\');
        foreach ($satirlar as $satir) {
            fputcsv($akis, array_map(self::hucre(...), $satir), self::AYIRAC, '"', '\\');
        }

        rewind($akis);
        $icerik = (string) stream_get_contents($akis);
        fclose($akis);

        return $icerik;
    }

    /**
     * CSV indirme cevabı. `text/csv; charset=utf-8` başlığı ve BOM (olustur() ekler) BİRLİKTE
     * gerekir: biri eksikse Excel dosyayı bölge kod sayfasıyla açar ve "Şükrü" bozuk görünür.
     */
    public static function indirme(string $icerik, string $dosyaAdi): Response
    {
        return response($icerik, 200, [
            'Content-Type' => 'text/csv; charset=utf-8',
            'Content-Disposition' => 'attachment; filename="'.$dosyaAdi.'"',
        ]);
    }

    /**
     * CSV metnini satırlara ayırır. BOM temizlenir, kodlama UTF-8'e çevrilir, ayırıcı sezilir.
     * Tamamen boş satırlar atılır (Excel dosya sonuna sıklıkla boş satır bırakır).
     *
     * @return list<list<string>>
     */
    public static function ayikla(string $icerik): array
    {
        $icerik = self::utf8(ltrim($icerik, "\xEF\xBB\xBF"));
        $ayirac = self::ayiracSez($icerik);

        $akis = fopen('php://temp', 'r+');
        fwrite($akis, $icerik);
        rewind($akis);

        $satirlar = [];
        while (($satir = fgetcsv($akis, 0, $ayirac, '"', '\\')) !== false) {
            $satir = array_map(fn ($h) => trim((string) $h), $satir);
            if (implode('', $satir) !== '') {
                $satirlar[] = $satir;
            }
        }
        fclose($akis);

        return $satirlar;
    }

    /**
     * İlk satırdaki `;` ve `,` sayısına bakar. Beraberlikte `;` seçilir — TR Excel varsayılanı odur
     * ve şablonu da biz `;` ile veriyoruz.
     */
    private static function ayiracSez(string $icerik): string
    {
        $ilkSatir = strtok($icerik, "\r\n") ?: '';

        return substr_count($ilkSatir, ',') > substr_count($ilkSatir, ';') ? ',' : ';';
    }

    /**
     * Geçerli UTF-8 değilse Windows-1254'ten (TR Excel'in "ANSI"si) çevirir. Sırayla denemek
     * yerine geçerlilik sınamak önemli: geçerli UTF-8'i tekrar çevirmek Türkçe harfleri bozardı.
     */
    private static function utf8(string $icerik): string
    {
        return mb_check_encoding($icerik, 'UTF-8')
            ? $icerik
            : (string) mb_convert_encoding($icerik, 'UTF-8', 'Windows-1254');
    }
}
