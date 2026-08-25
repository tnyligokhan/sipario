<?php

namespace App\Support;

/**
 * E-posta adresinin GERÇEK mi yoksa SENTETİK mi olduğunu söyleyen tek kural.
 *
 * ══ NEDEN VAR ═══════════════════════════════════════════════════════════════════════════════
 * Bu üründe her kullanıcının e-postası GERÇEK DEĞİLDİR. Kurye ve operatör hesapları firma
 * kodu + kullanıcı adıyla açılır ve `Provisioning::createCourier` onlara
 * `<kullanıcı>@<firma-kodu>.sipario.local` diye bir adres TÜRETİR — çünkü `users.email`
 * global tekil bir kolondur ve boş bırakılamaz. O adres hiçbir posta kutusuna karşılık
 * gelmez; oraya gönderilen posta sessizce kaybolur.
 *
 * Kural bugüne kadar `BayiPostacisi` içinde tek bir satırda gömülüydü. Parola sıfırlama
 * mobil tarafa açılırken İKİNCİ bir yere daha gerekti (2026-08-13) ve aynı `str_ends_with`
 * ifadesini kopyalamak, ileride alan adı değiştiğinde birinin güncellenip diğerinin
 * unutulması demekti. Bu sınıfın tek işi o kuralı TEK yerde tutmak.
 *
 * ⚠️ SESSİZ BAŞARISIZLIK RİSKİ: bu kontrol atlanırsa parola sıfırlama akışı "gönderdik" der,
 * posta sentetik adrese çıkar, kimse alamaz ve kullanıcı bağlantıyı bekleyerek kilitli kalır.
 * Hata hiçbir yerde görünmez — bu yüzden kapı gönderimden ÖNCE konur.
 */
final class PostaAdresi
{
    /** Sentetik adreslerin alan adı soneki. `Provisioning` ile ELLE senkron. */
    public const SENTETIK_SONEK = '.sipario.local';

    /**
     * Adres gerçek bir posta kutusuna gidebilir mi?
     *
     * Boş/whitespace adres de GERÇEK DEĞİLDİR: `users.email` boş olamaz ama savunma ucuzdur ve
     * boş adrese gönderim denemesi yalnız istisna üretir.
     */
    public static function gercekMi(?string $eposta): bool
    {
        $temiz = mb_strtolower(trim((string) $eposta));

        return $temiz !== '' && ! str_ends_with($temiz, self::SENTETIK_SONEK);
    }
}
