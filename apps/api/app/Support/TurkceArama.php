<?php

namespace App\Support;

/**
 * TÜRKÇE HARF KATLAMASI — arama kutularının tek kaynağı.
 *
 * NEDEN VAR: bu veritabanı TÜRKÇE harmanlamada çalışıyor ve `lower()` orada Türkçe kurallara göre
 * davranıyor — ölçüldü: `lower('I')` = 'ı', `lower('İ')` = 'i'. Yani katlamayı `lower()`a bırakan
 * her yaklaşım TERS yönde bozuluyor: 'İzmir' önce 'I'ya çevrilip sonra `lower()`lansaydı 'ızmir'
 * çıkardı ve **"izmir" araması sıfır sonuç verirdi** (testte birebir yaşandı).
 *
 * ÇÖZÜM: tehlikeli harflerin HER İKİ büyük/küçük biçimini de DOĞRUDAN küçük ASCII'ye indir, bunu
 * `lower()`'dan ÖNCE yap. Geriye yalnız locale-bağımsız ASCII kalır; kural harmanlamadan bağımsız
 * hâle gelir.
 *
 * NEDEN ORTAK BİR SINIF: kural iki tarafta birden yaşamak zorunda — SQL (`translate`) ve PHP
 * (`strtr`). İkisi AYNI sonucu üretmezse arama sessizce boş döner: hata mesajı yok, günlük kaydı
 * yok, yalnız "kayıt bulunamadı". Kopyalandığı sürece ayrışması an meselesiydi; bu dosya
 * 2026-08-04'te tam olarak o ayrışmayı önlemek için `TenantList` ve `OdemeKayitServisi`'ndeki iki
 * özdeş kopyadan çıkarıldı.
 *
 * SIRA: katlama ÖNCE, joker kaçışı SONRA. İkisi bağımsızdır (katlama `%` `_` `!` üretmez, kaçış
 * Türkçe harf üretmez) ama sıranın yazılı olması, birini değiştirmek isteyenin bağımsızlığı
 * görmesini sağlar.
 *
 * KAÇIŞ KARAKTERİ TERS BÖLÜ DEĞİL: `ESCAPE '\'` Postgres'çe geçerlidir ama PDO'nun placeholder
 * tarayıcısı tırnak içindeki ters bölüyü MySQL tarzı kaçış sanıp string'i kapanmamış kabul eder ve
 * sonraki `?` yer tutucularını yutar → `SQLSTATE[HY093]`. Ünlem kullanılıyor ve kendisi de kaçırılıyor.
 */
final class TurkceArama
{
    /** `translate()` kaynak kümesi — SQL literali olarak gömülür (tırnaklar dahil). */
    public const SQL_KAYNAK = "'İIıiĞğÜüŞşÖöÇç'";

    /** `translate()` hedef kümesi — SQL literali olarak gömülür (tırnaklar dahil). */
    public const SQL_HEDEF = "'iiiigguussoocc'";

    /** `LIKE ... ESCAPE` karakteri. Ters bölü DEĞİL — gerekçe sınıf başlığında. */
    public const KACIS = '!';

    /** @var array<string, string> PHP tarafı katlama — SQL tarafıyla BİREBİR aynı sonucu üretmeli. */
    private const HARFLER = [
        'İ' => 'i', 'I' => 'i', 'ı' => 'i', 'i' => 'i',
        'Ğ' => 'g', 'ğ' => 'g', 'Ü' => 'u', 'ü' => 'u',
        'Ş' => 's', 'ş' => 's', 'Ö' => 'o', 'ö' => 'o',
        'Ç' => 'c', 'ç' => 'c',
    ];

    /**
     * Kullanıcı girdisini katlar (PHP tarafı). SQL tarafındaki `sutun()` ile aynı sonucu verir.
     */
    public static function katla(string $metin): string
    {
        return mb_strtolower(strtr($metin, self::HARFLER), 'UTF-8');
    }

    /**
     * Katlanmış kolon ifadesi (SQL tarafı). Kolon adı ÇAĞIRANDAN gelir ve asla kullanıcı girdisi
     * olmamalıdır — bu ifade sorguya ham gömülür.
     */
    public static function sutun(string $kolon): string
    {
        return 'lower(translate('.$kolon.', '.self::SQL_KAYNAK.', '.self::SQL_HEDEF.'))';
    }

    /**
     * `LIKE` deseni: katlar, jokerleri (`%` `_`) ve kaçış karakterinin kendisini kaçırır, `%…%` sarar.
     * Kaçış karakteri ÖNCE kaçırılır — sonra kaçırılsaydı kendi eklediği `!`leri de kaçırırdı.
     */
    public static function desen(string $arama): string
    {
        $katli = self::katla($arama);
        $kacikli = str_replace(
            [self::KACIS, '%', '_'],
            [self::KACIS.self::KACIS, self::KACIS.'%', self::KACIS.'_'],
            $katli,
        );

        return '%'.$kacikli.'%';
    }
}
