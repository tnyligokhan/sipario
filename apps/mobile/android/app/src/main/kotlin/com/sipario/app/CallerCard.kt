package com.sipario.app

import android.content.Context
import android.database.sqlite.SQLiteException
import android.graphics.drawable.GradientDrawable
import android.util.Log
import android.view.View
import android.widget.LinearLayout

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

    fun build(context: Context, customer: CustomerLookup.Customer?, phone: String): View {
        CallerTema.fontlariYukle(context)
        val p = CallerTema.palet(context)

        // CSS `.cagri-kart`: surface zemin, r3 köşe, 18/18/18/20 iç boşluk, yanlardan 16 boşluk.
        val kok = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 22).toFloat()
                setColor(p.surface)
            }
            setPadding(dp(context, 18), dp(context, 18), dp(context, 18), dp(context, 20))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                val yan = dp(context, 16)
                setMargins(yan, 0, yan, 0)
            }
            // Tasarımda kart, düz yüzey kuralının tek istisnası: perde üstünde yüzer.
            elevation = dp(context, 14).toFloat()
        }

        kok.addView(CallerCardViews.ustSerit(context, p, kok))
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
