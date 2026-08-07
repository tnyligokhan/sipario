package com.sipario.app

import android.content.Context
import android.content.res.Configuration
import android.graphics.Typeface
import android.util.Log
import android.util.TypedValue
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.io.File

/**
 * Çağrı kartının TASARIM KATMANI: renk aynası, tema seçimi, fontlar ve çizim yardımcıları.
 * Görünümün kendisi [CallerCard] (iskelet) ve [CallerCardViews] (parçalar) içindedir.
 *
 * Ayrı dosya olmasının sebebi 500 satır sınırı değil yalnız; bu dosya `DESIGN_SYSTEM.md` ile
 * ELLE senkron tutulan tek yerdir — bir jeton değişince bakılacak dosya budur.
 */
internal object CallerTema {

    private const val TAG = "SiparioCardTema"
    private const val FONT_KOK = "flutter_assets/assets/fonts"

    // ── Renk token'ları — lib/theme/tokens.dart AYNASI ──────────────────────────────────────
    // Native taraf Dart okuyamaz; değerler ELLE senkron tutulur. tokens.dart'ta bir jeton
    // değişirse BURADA da değişmeli (tek senkron noktası bu blok).
    internal class Palet(
        val surface: Int,
        val surface2: Int,
        val ink: Int,
        val ink2: Int,
        val muted: Int,
        val accent: Int,
        val accentInk: Int,
        val accentSoft: Int,
        val danger: Int,
        val dangerSoft: Int,
        val ok: Int,
        val okSoft: Int,
        val warn: Int,
        val warnSoft: Int,
    )

    /** `SipTokens.acik` — tasarımın varsayılanı. */
    private val ACIK = Palet(
        surface = 0xFFFFFFFF.toInt(),
        surface2 = 0xFFEAE8F0.toInt(),
        ink = 0xFF17141F.toInt(),
        ink2 = 0xFF47434F.toInt(),
        muted = 0xFF8B8794.toInt(),
        accent = 0xFF5A45F0.toInt(),
        accentInk = 0xFFFFFFFF.toInt(),
        accentSoft = 0xFFECE9FE.toInt(),
        danger = 0xFFDF3F45.toInt(),
        dangerSoft = 0xFFFCE9EA.toInt(),
        ok = 0xFF1E9E6A.toInt(),
        okSoft = 0xFFE3F4EC.toInt(),
        warn = 0xFFC08415.toInt(),
        warnSoft = 0xFFF9F0DC.toInt(),
    )

    /** `SipTokens.koyu` — accent/danger/ok/warn ana tonları AYNI kalır (tasarım kararı). */
    private val KOYU = Palet(
        surface = 0xFF1E1B26.toInt(),
        surface2 = 0xFF2A2634.toInt(),
        ink = 0xFFF2F0F7.toInt(),
        ink2 = 0xFFC9C5D4.toInt(),
        muted = 0xFF8D8999.toInt(),
        accent = 0xFF5A45F0.toInt(),
        accentInk = 0xFFFFFFFF.toInt(),
        accentSoft = 0xFF2C2650.toInt(),
        danger = 0xFFDF3F45.toInt(),
        dangerSoft = 0xFF3A1D22.toInt(),
        ok = 0xFF1E9E6A.toInt(),
        okSoft = 0xFF17332A.toInt(),
        warn = 0xFFC08415.toInt(),
        warnSoft = 0xFF332A16.toInt(),
    )

    fun palet(context: Context): Palet = if (koyuTemaMi(context)) KOYU else ACIK

    // ── Tema tercihi ────────────────────────────────────────────────────────────────────────

    /**
     * Tema tercihini `lib/theme/tema_deposu.dart` ile AYNI yerden okur: sqflite'in veritabanı
     * dizinindeki [TEMA_DOSYA] düz metin dosyası, içeriği `acik` | `koyu`.
     *
     * Neden SharedPreferences değil: Dart tarafı bilerek paket eklemedi, tercihi bu dosyaya
     * yazıyor — native taraf başka bir yere bakarsa koyu tema kullanan bayiye BEYAZ kart çıkar.
     * Dosya yoksa/okunamazsa AÇIK tema (tasarımın varsayılanı, Dart tarafıyla aynı düşüş).
     */
    private fun koyuTemaMi(context: Context): Boolean {
        val dizin = context.getDatabasePath(CustomerLookup.DB_NAME).parentFile ?: return false
        val dosya = File(dizin, TEMA_DOSYA)
        val deger = runCatching {
            if (!dosya.exists()) null else dosya.readText().trim().lowercase()
        }.getOrElse {
            Log.w(TAG, "tema tercihi okunamadi: ${it.javaClass.simpleName}")
            null
        } ?: return false

        return when (deger) {
            "koyu" -> true
            "acik" -> false
            // Dart tarafı bugün yalnız iki değer yazıyor; "sistem" eklenirse cihazın gece
            // kipine uyalım ki native taraf sessizce açık temada donup kalmasın.
            "sistem", "system" -> sistemKoyuMu(context)
            else -> false
        }
    }

    /** `kTemaDosyaAdi` aynası (lib/theme/tema_deposu.dart). */
    const val TEMA_DOSYA = "sipario_tema.txt"

    private fun sistemKoyuMu(context: Context): Boolean =
        (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    // ── Fontlar ─────────────────────────────────────────────────────────────────────────────
    // Sora ve Hanken Grotesk DEĞİŞKEN font; ağırlık API 28+'ta `Typeface.create(tf, w, false)`
    // ile verilir. Düşük API'de ya da asset okunamazsa sistem fontuna düşülür — kart HİÇBİR
    // durumda çizimsiz kalmaz.
    private var fontlarDenendi = false
    private var soraTemel: Typeface? = null
    private var hankenTemel: Typeface? = null
    private val agirlikCache = HashMap<String, Typeface>()

    fun fontlariYukle(context: Context) {
        if (fontlarDenendi) return
        fontlarDenendi = true
        soraTemel = runCatching {
            Typeface.createFromAsset(context.assets, "$FONT_KOK/Sora.ttf")
        }.getOrNull()
        hankenTemel = runCatching {
            Typeface.createFromAsset(context.assets, "$FONT_KOK/HankenGrotesk.ttf")
        }.getOrNull()
        if (soraTemel == null || hankenTemel == null) {
            Log.w(TAG, "font asset'i okunamadi, sistem fontuna dusuluyor")
        }
    }

    private fun font(baslik: Boolean, agirlik: Int): Typeface? {
        val temel = (if (baslik) soraTemel else hankenTemel) ?: return null
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.P) return temel
        val anahtar = "${if (baslik) "d" else "b"}$agirlik"
        agirlikCache[anahtar]?.let { return it }
        val olusan = runCatching { Typeface.create(temel, agirlik, false) }.getOrNull() ?: temel
        agirlikCache[anahtar] = olusan
        return olusan
    }

    // ── Çizim yardımcıları ──────────────────────────────────────────────────────────────────

    fun yazi(
        context: Context,
        metin: String,
        sp: Float,
        renk: Int,
        agirlik: Int = 400,
        baslik: Boolean = false,
        tabular: Boolean = false,
        harfAralik: Float = 0f,
        tekSatir: Boolean = false,
        satirlar: Int = 0,
    ) = TextView(context).apply {
        text = metin
        setTextColor(renk)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        val yuz = font(baslik, agirlik)
        if (yuz != null) {
            typeface = yuz
        } else if (agirlik >= 600) {
            setTypeface(typeface, Typeface.BOLD)
        }
        if (harfAralik != 0f) letterSpacing = harfAralik
        if (tabular) fontFeatureSettings = "tnum"
        if (tekSatir) {
            isSingleLine = true
            ellipsize = android.text.TextUtils.TruncateAt.END
        } else if (satirlar > 0) {
            maxLines = satirlar
            ellipsize = android.text.TextUtils.TruncateAt.END
        }
    }

    fun ikon(context: Context, id: Int, boyutDp: Int, renk: Int) = ImageView(context).apply {
        setImageResource(id)
        setColorFilter(renk)
        layoutParams = LinearLayout.LayoutParams(dp(context, boyutDp), dp(context, boyutDp))
    }

    fun satirParams(context: Context, ust: Int) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT,
    ).apply { setMargins(0, dp(context, ust), 0, 0) }

    fun dp(context: Context, value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    // ── Biçimleme ───────────────────────────────────────────────────────────────────────────

    /** `sipTutar()` aynası: binlik ayracı nokta, kuruş virgül, sonda ₺. */
    fun para(kurus: Long): String {
        val tam = (kurus / 100).toString()
        val kalan = (kurus % 100).toString().padStart(2, '0')
        val binlikli = StringBuilder()
        for ((i, ch) in tam.withIndex()) {
            if (i > 0 && (tam.length - i) % 3 == 0) binlikli.append('.')
            binlikli.append(ch)
        }
        return "$binlikli,$kalan ₺"
    }

    /** `SipAvatar.basHarfler()` aynası — ilk iki sözcüğün baş harfleri. */
    fun basHarfler(ad: String): String {
        val parcalar = ad.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
        val a = parcalar.getOrNull(0)?.firstOrNull()?.toString().orEmpty()
        val b = parcalar.getOrNull(1)?.firstOrNull()?.toString().orEmpty()
        return (a + b).uppercase()
    }
}
