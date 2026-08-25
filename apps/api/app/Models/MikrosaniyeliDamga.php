<?php

namespace App\Models;

/**
 * KARAR VEREN DAMGALARI MİKROSANİYEYLE YAZAN MODELLER İÇİN.
 *
 * NEDEN VAR (2026-08-17, LWW saniye-altı borcu kapatılırken bulundu): çakışma çözümünün
 * saniye-altı ayrımı YOKTU ve sebebi İKİ AYRI KIRPICIYDI — biri veritabanı, biri Eloquent:
 *
 *   1. Kolonlar `timestamptz(0)` idi; Postgres yazarken değeri saniyeye yuvarluyordu.
 *      (Migration `2026_08_17_004012` ile karar veren 19 kolon `timestamptz(6)` yapıldı.)
 *   2. Eloquent'in varsayılan damga biçimi `Y-m-d H:i:s`tir — mikrosaniye YOKTUR. Model
 *      `updated_occurred_at`i `datetime` cast'ıyla Carbon'a çevirip KAYDEDERKEN bu biçimle
 *      geri diziyordu. Yani kolon düzeltilse bile saniye-altı yine kaybolurdu.
 *
 * İkinci kırpıcı gözden kaçmaya YATKINDIR: `SyncPayload::zaman()` damgayı `.u` ile üretiyor
 * (yani veri sunucuya mikrosaniyeli GELİYOR), veritabanı kolonu da artık saklayabiliyor —
 * arada yalnız modelin serileştirmesi duruyor ve o hiçbir yerde görünmüyordu. Depodaki
 * `markTestIncomplete` notu bu yüzden tek sebep olarak kolonu yazıyordu; ölçüldü, eksikti.
 *
 * ⚠️ TÜM DAMGALARI ETKİLER (`created_at`/`updated_at` dahil) ve bu zararsızdır: mikrosaniyeli
 * bir dize `timestamptz(0)` kolona yazıldığında Postgres onu kendi yuvarlar. Yani bu trait'i
 * eklemek, karar VERMEYEN kolonların davranışını değiştirmez.
 *
 * ⚠️ OKUMA TARAFI: Eloquent ham dizeyi bu biçimle ayrıştıramazsa Carbon'un genel
 * ayrıştırıcısına düşer, yani `timestamptz(0)` kolonlardan gelen ".u"suz değerler de sorunsuz
 * okunur.
 */
trait MikrosaniyeliDamga
{
    /**
     * Eloquent'in bu model için kullandığı damga biçimi.
     *
     * Varsayılan `Y-m-d H:i:s`e mikrosaniye (`.u`) eklenmiştir — LWW'nin "son yazan kazanır"
     * kuralı aynı saniyeye düşen iki yazımı ancak böyle ayırabilir.
     *
     * ⚠️ PROPERTY DEĞİL METOT EZİLİR ve bunun teknik bir zorunluluğu var: trait içinde
     * `protected $dateFormat = ...` yazmak PHP'de ölümcül hatadır — "Model and
     * MikrosaniyeliDamga define the same property ($dateFormat) in the composition". PHP,
     * bir trait'in ÜST SINIFTA zaten tanımlı bir property'yi farklı varsayılanla yeniden
     * tanımlamasına izin vermez (alt SINIF yapabilir, trait yapamaz). Hata testlerde
     * "Premature end of PHP process" kılığında, yani sebebini söylemeden çıkıyor.
     *
     * Metodu ezmek hem bu kısıttan kaçınır hem tek tanım bırakır: on dört modele aynı satırı
     * kopyalamak yerine kural tek yerde durur.
     */
    public function getDateFormat(): string
    {
        return 'Y-m-d H:i:s.u';
    }
}
