package com.sipario.app

import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteException
import android.graphics.drawable.GradientDrawable
import android.util.Log
import android.view.View
import android.widget.LinearLayout
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeParseException
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * Arayan kartının İSKELETİ. Tek yerde tanımlı; hem kilitsiz ekrandaki overlay penceresi
 * ([CallerOverlay]) hem de kilit ekranındaki tam ekran [CallerActivity] bunu kullanır.
 *
 * Tamamen programatik: XML şişirme ve Flutter engine YOK — çağrı anında soğuk başlangıç
 * bütçesi 1 saniyedir (DECISIONS Faz 0). Görsel yükleme, ağ çağrısı, bakiye toplama yapılmaz.
 *
 * SİPARİO 3.0 kimliği (tasarım s-cagri.jsx + Sipario.html `.cagri-*`):
 * açık yüzey · r3 (22dp) köşe · elektrik moru vurgu · Sora (başlık/rakam) + Hanken Grotesk
 * (gövde). Üstte nabızlı nokta + "GELEN ÇAĞRI" + süre + kapat; altında avatar/ad/numara,
 * bakiye şeridi, bilgi satırları ve eylem düğmeleri.
 *
 * Dosya üçe bölündü (500 satır sınırı):
 *  - [CallerTema]      renk aynası + tema tercihi + font + biçimleme
 *  - [CallerCardViews] kartın parçaları (üst şerit, kim satırı, bakiye, bilgi, eylemler)
 *  - burası           iskelet, muaf kontrolü ve dışarıya açık API
 *
 * Kapatma DAVRANIŞI çağıran taraftadır (overlay/Activity kök görünüme listener koyar);
 * kapat düğmesi o listener'a delege eder — API değişmedi.
 */
object CallerCard {

    private const val TAG = "SiparioCard"

    /** Kart eylemleri uygulamayı bu ekstralarla açar; karşılayan taraf [MainActivity]'dir. */
    const val EXTRA_EYLEM = "sipario_cagri_eylem"
    const val EXTRA_NUMARA = "sipario_cagri_numara"

    /** Kartın ve bildirimin ortak eylemi. [kod] Dart tarafındaki `CagriEylemi` ile eşleşir. */
    data class Eylem(val etiket: String, val kod: String, val ikonId: Int)

    /**
     * Eylemlerin TEK KAYNAĞI — hem kart düğmeleri hem bildirim düğmeleri buradan üretilir.
     *
     * NEDEN TEK LİSTE (2026-07-27, bildirim düğmeleri eklenirken): iki yüzey iki ayrı listeden
     * beslenseydi, bir eylem eklendiğinde ya da etiketi değiştiğinde biri sessizce geride
     * kalırdı. Bayi kartta gördüğü düğmeyi bildirimde bulamazsa bu bir hata olarak döner.
     *
     * VARYANT: kayıtsız numarada "Defteri Aç" anlamsızdır (açılacak defter yok), o yüzden
     * yalnız kaydetme eylemi çıkar — kartın bugünkü davranışının aynısı.
     *
     * Liste EN FAZLA 2 eleman döner; Android bildirimde en çok 3 düğme gösterir (bazı
     * kabuklarda daha az), yani hepsi sığar ve seçme/eleme kuralına gerek kalmaz.
     */
    fun eylemListesi(customer: CustomerLookup.Customer?): List<Eylem> =
        if (customer != null) {
            listOf(
                Eylem("Sipariş Oluştur", "siparis", R.drawable.sip_ic_plus),
                Eylem("Defteri Aç", "defter", R.drawable.sip_ic_book),
            )
        } else {
            listOf(Eylem("Müşteri Olarak Kaydet", "kaydet", R.drawable.sip_ic_user_plus))
        }

    /**
     * Eylemi uygulamaya taşıyan niyet — KÖPRÜNÜN TEK YERİ.
     *
     * Kart düğmesi de bildirim düğmesi de bunu kullanır; ikinci bir transfer yolu YOKTUR
     * (DECISIONS: "native taraf eylemi BEKLETİR, itmez" — karşılayan `MainActivity.bekleyen`,
     * Dart'a `sipario/cagri` kanalından geçer). İki ayrı niyet kurulsaydı iki yol zamanla
     * sessizce ayrışırdı.
     */
    fun eylemNiyeti(context: Context, eylem: String, phone: String): Intent =
        Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(EXTRA_EYLEM, eylem)
            .putExtra(EXTRA_NUMARA, phone)

    fun build(
        context: Context,
        customer: CustomerLookup.Customer?,
        phone: String,
        yon: CagriYonu = CagriYonu.GELEN,
    ): View {
        CallerTema.fontlariYukle(context)
        val p = CallerTema.palet(context)

        // CSS `.cagri-kart`: surface zemin, r3 köşe, 18/18/18/20 iç boşluk, genişlik %100.
        //
        // YAN BOŞLUK BURADA DEĞİL, PENCEREDEDİR (2026-07-27 saha bulgusu). Burada bir zamanlar
        // `LinearLayout.LayoutParams` ile 16dp kenar payı veriliyordu ama ikisi de SESSİZCE
        // düşüyordu: `WindowManager.addView` görünümün layoutParams'ını kendi params'ıyla
        // DEĞİŞTİRİR (ve `WindowManager.LayoutParams` bir MarginLayoutParams değildir, kenar
        // payı diye bir alanı yoktur), `Activity.setContentView(View)` de MATCH_PARENT'lık düz
        // bir `ViewGroup.LayoutParams` dayatır. Sonuç: kart iki uçta da ekran kenarına
        // dayanıyordu. Boşluk artık pencere genişliğinden geliyor — bkz. [kartGenisligi].
        val kok = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 22).toFloat()
                setColor(p.surface)
            }
            setPadding(dp(context, 18), dp(context, 18), dp(context, 18), dp(context, 20))
            // Tasarımda kart, düz yüzey kuralının tek istisnası: perde üstünde yüzer.
            elevation = dp(context, 14).toFloat()
        }

        kok.addView(CallerCardViews.ustSerit(context, p, kok, yon))
        kok.addView(CallerCardViews.kimSatiri(context, p, customer, phone))

        if (customer != null) {
            if (customer.balanceKurus != 0L) {
                kok.addView(CallerCardViews.bakiyeSeridi(context, p, customer.balanceKurus))
            }
            CallerCardViews.bilgiSatirlari(context, p, customer)?.let { kok.addView(it) }
        }

        kok.addView(CallerCardViews.eylemler(context, p, customer, phone))
        return kok
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════
    // Kartın penceresi
    // ═══════════════════════════════════════════════════════════════════════════════════════

    /**
     * Kartın iki yanındaki boşluk. Tasarımın kendi ölçüsü: `.cagri-overlay { padding: 0 16px }`
     * (`design_handoff_sipario/_cozulmus/_sayfa.html:774`); kartın kendisi o kabın içinde
     * `width: 100%`tür. Flutter kartı da aynı değeri `SipSpace.x3` ile uyguluyor.
     */
    const val YAN_BOSLUK_DP = 16

    /**
     * Kart penceresinin genişliği — ekran eksi iki yandan [YAN_BOSLUK_DP].
     *
     * Boşluğu KART yerine PENCERE veriyor olmamızın sebebi: yan şeritlerde hiç görünüm olmuyor,
     * dolayısıyla oradaki dokunuşlar alttaki çağrı ekranına düşmeye devam ediyor (kilitli yolda
     * `FLAG_NOT_TOUCH_MODAL` + `setFinishOnTouchOutside(false)` sözleşmesi bozulmasın). Şeffaf
     * dolgulu bir sarmalayıcı görünüm koysaydık o şeritler dokunuşu yutardı.
     *
     * Alt sınır yalnız EMNİYETTİR (tasarım ölçüsü değil): `widthPixels` beklenmedik bir bağlamda
     * 0 dönerse kart negatif genişlikle hiç çizilmesin.
     */
    fun kartGenisligi(context: Context): Int {
        val ekran = context.resources.displayMetrics.widthPixels
        return (ekran - 2 * dp(context, YAN_BOSLUK_DP)).coerceAtLeast(dp(context, 240))
    }

    // ═══════════════════════════════════════════════════════════════════════════════════════
    // Muaf numara kontrolü
    // ═══════════════════════════════════════════════════════════════════════════════════════

    /**
     * Numara muaf listesindeyse kart HİÇ gösterilmemelidir (s-uygulama.jsx kuralı).
     * Kurye kendi hattından aradığında bayiye kart çıkmasın diye var.
     *
     * Eşleşme son 10 hane üzerinden; `customer_phones` ile aynı kural. Bağlantı
     * [CustomerLookup.openForRead] ile açılır — WAL kurtarma düşüşü tek yerde tanımlı olsun.
     *
     * HATA DURUMUNDA `false` DÖNER (tablo yoksa, DB açılamıyorsa): kartı susturmak yerine
     * göstermeyi seçiyoruz — arayan tanıma ürünün kendisi, muaf listesi yalnız bir rahatlık.
     * Bu yüzden sorgudan önce `sqlite_master` ile tablonun varlığı da denetlenir: eski şemalı
     * bir cihazda "no such table" istisnası atmaktansa sessizce muaf-değil demek daha ucuz.
     */
    fun muafMi(context: Context, rawPhone: String): Boolean {
        val anahtar = CustomerLookup.last10(rawPhone)
        if (anahtar.length < 10) return false

        val dosya = context.getDatabasePath(CustomerLookup.DB_NAME)
        if (!dosya.exists()) return false

        val db = CustomerLookup.openForRead(dosya.absolutePath) ?: return false
        return try {
            if (!tabloVarMi(db)) {
                Log.i(TAG, "exempt_numbers tablosu yok, muaf kontrolu atlandi")
                return false
            }
            db.rawQuery(
                "SELECT 1 FROM exempt_numbers WHERE phone_last10 = ? AND deleted_at IS NULL LIMIT 1",
                arrayOf(anahtar),
            ).use { imlec -> imlec.moveToFirst() }
        } catch (e: SQLiteException) {
            Log.w(TAG, "muaf sorgusu basarisiz: ${e.javaClass.simpleName}")
            false
        } finally {
            db.close()
        }
    }

    private fun tabloVarMi(db: android.database.sqlite.SQLiteDatabase): Boolean =
        db.rawQuery(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'exempt_numbers' LIMIT 1",
            null,
        ).use { it.moveToFirst() }

    // ═══════════════════════════════════════════════════════════════════════════════════════
    // Dışarıya açık biçimleme (CallerOverlay bildirim metnini bunlarla kurar)
    // ═══════════════════════════════════════════════════════════════════════════════════════

    /**
     * "Son sipariş: Yolda · 10:24" — kartın son sipariş satırı ve bildirimin aynı satırı.
     *
     * Bayi telefonda "siparişim nerede" sorusuna kartı okuyarak cevap verir; durum bu yüzden
     * sipariş dökümünden ÖNCE gelir. Sözcükler cümle içinde okunacak biçimde uzun tutuldu
     * (liste rozetindeki "Açık/Teslim/İptal" kısaltmaları kartta anlamı taşımıyordu).
     */
    fun sonSiparisSatiri(s: CustomerLookup.SonSiparis): String {
        val saat = saatMetni(s.occurredAt)
        val durum = siparisDurumEtiketi(s)
        return if (saat.isEmpty()) "Son sipariş: $durum" else "Son sipariş: $durum · $saat"
    }

    /**
     * `orders.status` + kurye ataması → bayinin telefonda söyleyeceği sözcük.
     * "Yolda", `open` bir siparişin kuryeye ATANMIŞ olmasıdır (DECISIONS: `assigned_user_id`
     * bir önbellektir, kaynağı atama olaylarıdır).
     */
    private fun siparisDurumEtiketi(s: CustomerLookup.SonSiparis): String = when (s.durum) {
        "delivered" -> "Teslim edildi"
        "cancelled" -> "İptal edildi"
        else -> if (s.kuryede) "Yolda" else "Hazırlanıyor"
    }

    /**
     * ISO8601 UTC → "10:24" · "Dün" · "Per" · "02.07". Dart `cagriSaatMetni` ile AYNI kurallar
     * (iki kart aynı çağrıda aynı metni yazmalı). Okunamayan zaman boş döner; kart o zaman
     * yalnız durumu yazar, " · " ayracı asılı kalmaz.
     */
    fun saatMetni(iso: String, bugun: LocalDate = LocalDate.now()): String = try {
        val yerel = Instant.parse(iso).atZone(ZoneId.systemDefault())
        val gun = yerel.toLocalDate()
        val fark = ChronoUnit.DAYS.between(gun, bugun)
        val saat = String.format(Locale.US, "%02d:%02d", yerel.hour, yerel.minute)
        when {
            // İleri tarihli kayıt (cihaz saati geri alınmış) saat gibi gösterilir — Dart tarafı
            // da öyle yapar; "-3 gün" saçmalığından en az yanıltıcı olan bu.
            fark <= 0L -> saat
            fark == 1L -> "Dün"
            fark < 7L -> gunAdlari[gun.dayOfWeek.value - 1]
            else -> String.format(Locale.US, "%02d.%02d", gun.dayOfMonth, gun.monthValue)
        }
    } catch (e: DateTimeParseException) {
        ""
    }

    private val gunAdlari = listOf("Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz")

    /** Pozitif bakiye müşterinin borcudur (veresiye); negatif bakiye onun alacağıdır. */
    fun balanceLine(kurus: Long): String = when {
        kurus > 0 -> "Borç: ${CallerTema.para(kurus)}"
        kurus < 0 -> "Alacak: ${CallerTema.para(-kurus)}"
        else -> "Bakiye temiz"
    }

    /** "05327710863" → "0532 771 08 63" (yalnız gösterim; eşleşme phone_last10 ile). */
    fun formatPhone(raw: String): String {
        val haneler = raw.filter(Char::isDigit)
        val yerel = when {
            haneler.length == 12 && haneler.startsWith("90") -> "0" + haneler.drop(2)
            haneler.length == 10 -> "0$haneler"
            haneler.length == 11 && haneler.startsWith("0") -> haneler
            else -> return raw
        }
        return "${yerel.substring(0, 4)} ${yerel.substring(4, 7)} " +
            "${yerel.substring(7, 9)} ${yerel.substring(9, 11)}"
    }

    fun dp(context: Context, value: Int): Int = CallerTema.dp(context, value)
}
