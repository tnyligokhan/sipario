<?php

namespace App\Eposta;

use App\Enums\UserRole;
use App\Mail\SiparioPostasi;
use App\Models\Tenant;
use App\Models\User;
use App\Support\PostaAdresi;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * BİR BAYİYE POSTA GÖNDERMENİN TEK KAPISI.
 *
 * Üç problemi tek yerde çözer; üçü de her çağrı yerinde ayrı ayrı çözülseydi biri mutlaka
 * unutulurdu:
 *
 * 1. "KİME?" — Bayinin bir e-posta kolonu YOKTUR; adres PATRON kullanıcısındadır. Kuryelerin
 *    adresi ise sahtedir (`Provisioning::createCourier` onu `<kullanıcı>@<kod>.sipario.local`
 *    diye türetir), yani "bayinin kullanıcılarına gönder" demek postayı hiçliğe göndermektir.
 *    Burada yalnız AKTİF PATRON hedeflenir.
 *
 * 2. "HANGİ BAĞLANTIYLA?" — Okuma `pgsql_owner` ile yapılır. Bu kod panelden, konsol
 *    komutundan ve kuyruktan çağrılır; o bağlamlarda RLS kiracı değişkeni KURULU DEĞİLDİR ve
 *    normal `pgsql` bağlantısı boş küme döndürür. Arıza sessizdir: posta gitmez, hata çıkmaz.
 *
 * 3. "PATLARSA NE OLUR?" — Posta gönderimi hiçbir iş akışını düşürmez. Ödeme eşleştirmesi,
 *    kurye açma ya da kayıt bir SMTP arızası yüzünden geri alınamaz — para ve hesap kaydı
 *    postadan önemlidir. İstisna yutulur ama `report()` ile kaydedilir (bu depodaki mevcut
 *    davranışın aynısı: `Hesap::disaAktarTalep`, `Parola::baglantiGonder`).
 *
 * ⚠️ `ShouldQueue` olduğumuz için `Mail::send` yalnız kuyruğa yazar; buradaki try/catch
 * SMTP'yi değil, kuyruk yazımını ve adres çözümlemesini korur. Gerçek gönderim hatası
 * `queue:work` tarafında yaşanır ve orada yeniden denenir.
 */
class BayiPostacisi
{
    /**
     * Bayinin patronunu döndürür (aktif değilse null).
     *
     * `status = active` kapısı bilinçli: pasifleştirilmiş bir patronun adresine abonelik
     * hatırlatması göndermek, hesabı kapatılmış birine satış yapmaya çalışmaktır.
     */
    public static function patron(string $tenantId): ?User
    {
        /** @var User|null $patron */
        $patron = User::on('pgsql_owner')
            ->where('tenant_id', $tenantId)
            ->where('role', UserRole::Patron->value)
            ->where('status', 'active')
            ->first();

        return $patron;
    }

    public static function bayi(string $tenantId): ?Tenant
    {
        /** @var Tenant|null $bayi */
        $bayi = Tenant::on('pgsql_owner')->find($tenantId);

        return $bayi;
    }

    /**
     * Postayı bayinin patronuna gönderir. Patron yoksa ya da gönderim hazırlığı patlarsa
     * SESSİZ döner — çağıranın iş akışı bundan etkilenmez.
     *
     * @param  callable(Tenant, User): SiparioPostasi  $kur  Postayı bayi+patron elde edilince kurar;
     *                                                       böylece çağıran taraf adres çözmek için
     *                                                       ikinci bir sorgu atmak zorunda kalmaz.
     */
    public static function gonder(string $tenantId, callable $kur): bool
    {
        try {
            $bayi = self::bayi($tenantId);
            $patron = self::patron($tenantId);

            if ($bayi === null || $patron === null || trim((string) $patron->email) === '') {
                return false;
            }

            // Sahte kurye adresine posta gitmesin — patron rolünde olmaması gerekir ama bu
            // ucuz kapı, ileride patron hesabının nasıl yaratıldığı değişirse tutar.
            // Kural `PostaAdresi`ye taşındı (2026-08-13): parola sıfırlama da aynı soruyu
            // soruyor ve iki kopya, alan adı değiştiğinde birinin unutulması demekti.
            if (! PostaAdresi::gercekMi($patron->email)) {
                return false;
            }

            return self::postala($patron->email, $patron->name, $kur($bayi, $patron));
        } catch (Throwable $e) {
            report($e);

            return false;
        }
    }

    /**
     * Bilinen bir adrese gönderir — çağıran taraf bayi ve patronu ZATEN elinde tutuyorsa
     * (kayıt akışı gibi) `gonder()`in ikinci sorgusuna gerek yoktur. Hata politikası aynıdır.
     */
    public static function postala(string $adres, ?string $ad, SiparioPostasi $posta): bool
    {
        try {
            if (trim($adres) === '') {
                return false;
            }

            Mail::to($adres, $ad)->send($posta);

            return true;
        } catch (Throwable $e) {
            report($e);

            return false;
        }
    }

    /**
     * BİZE (destek kutusuna) iç bildirim gönderir.
     *
     * Ayrı bir metot çünkü hedef bayiye değil bize gider ve adres çözümlemesi yoktur; ortak
     * olan yalnız "patlarsa iş akışını düşürme" politikasıdır.
     */
    public static function destege(SiparioPostasi $posta): bool
    {
        try {
            $hedef = (string) config('subscription.company.support_email', 'destek@sipario.com.tr');

            Mail::to($hedef)->send($posta);

            return true;
        } catch (Throwable $e) {
            report($e);

            return false;
        }
    }
}
