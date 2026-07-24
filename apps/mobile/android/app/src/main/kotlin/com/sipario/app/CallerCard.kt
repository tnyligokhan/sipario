package com.sipario.app

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Arayan kartının görünümü. Tek yerde tanımlı; hem kilitsiz ekrandaki overlay penceresi
 * hem de kilit ekranındaki tam ekran Activity bunu kullanır. İki yolun farklı görünmesi,
 * bayinin aynı bilgiyi iki ayrı yerde araması demek olurdu.
 *
 * Tamamen programatik: XML şişirme ve Flutter engine yok, soğuk başlangıç bütçesi 1 sn.
 *
 * EKRAN 6 — yeniden tasarım (design_handoff, 3 mockup): s2 yüzey + line2 kenar + 22dp köşe,
 * "GELEN ÇAĞRI" başlık şeridi (nabızlı Azur nokta), isim baskın, dolgulu bakiye şeridi
 * (borçlu kırmızı / temiz yeşil — liste rozetiyle aynı dil), Kapat düğmesi.
 * Kapat düğmesi kök görünümün click listener'ına delege eder; kapatma davranışı (dokunmadan
 * kapanmaz, 120 sn emniyet) çağıran taraftadır ve DEĞİŞMEDİ.
 */
object CallerCard {

    // ── Renk token'ları — lib/theme/tokens.dart (SipColors) AYNASI ──────────────────────────
    // Native taraf Dart okuyamaz; değerler elle senkron tutulur. tokens.dart'ta bir değer
    // değişirse BURADA da değişmeli (tek senkron noktası bu blok).
    private val S2 = Color.parseColor("#FF1C242D") // popup kartı yüzeyi
    private val S3 = Color.parseColor("#FF28323C") // nötr şerit / ikincil buton
    private const val LINE2 = 0x1FFFFFFF // beyaz %12 — belirgin kenar
    private val T1 = Color.parseColor("#FFEEF2F5")
    private val T2 = Color.parseColor("#FF9AA6B2")
    private val T3 = Color.parseColor("#FF5F6975")
    private val ACC = Color.parseColor("#FF23A9E0")
    private val ACC_FG = Color.parseColor("#FF54C4EE")
    private val DEBT = Color.parseColor("#FFE85640")
    private val OK = Color.parseColor("#FF41B883")
    private val OK_INK = Color.parseColor("#FF06231B")
    private val WARN = Color.parseColor("#FFE7A93C")
    private const val WARN_SOFT = 0x26E7A93C // %15

    fun build(context: Context, customer: CustomerLookup.Customer?, phone: String): View {
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 22).toFloat() // SipRadius.sheet
                setColor(S2)
                setStroke(dp(context, 1), LINE2)
            }
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            val side = dp(context, 24)
            lp.setMargins(side, 0, side, 0)
            layoutParams = lp
            elevation = dp(context, 14).toFloat()
        }

        root.addView(header(context, customer, phone))

        if (customer == null) {
            // Kayıtsız numara — isim yerine numara baskın (handoff 3. mockup).
            root.addView(
                text(context, formatPhone(phone), 29f, T1, weight = 700, tabular = true)
                    .padded(context, 18, 14, 18, 0)
            )
            root.addView(
                text(context, "Bu numara müşteri kaydında yok.", 14f, T2)
                    .padded(context, 18, 6, 18, 0)
            )
            root.addView(strip(context, S3, "Bakiye / geçmiş kaydı yok", T2, amount = null, amountColor = 0))
        } else {
            root.addView(
                text(context, customer.name, 26f, T1, weight = 700, singleLine = true)
                    .padded(context, 18, 11, 18, 0)
            )
            customer.address?.takeIf { it.isNotBlank() }?.let {
                root.addView(
                    text(context, it, 14f, T2, maxLines = 2)
                        .padded(context, 18, 9, 18, 0)
                )
            }
            root.addView(balanceStrip(context, customer.balanceKurus))
            customer.note?.takeIf { it.isNotBlank() }?.let {
                root.addView(noteStrip(context, it))
            }
        }

        root.addView(closeButton(context, root))
        return root
    }

    // ── Parçalar ────────────────────────────────────────────────────────────────────────────

    /** Başlık şeridi: nabızlı Azur nokta + GELEN ÇAĞRI + sağda numara / "Kayıtlı değil". */
    private fun header(context: Context, customer: CustomerLookup.Customer?, phone: String): View {
        val row = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(context, 18), dp(context, 16), dp(context, 18), 0)
        }

        val dot = View(context).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(ACC)
            }
            layoutParams = LinearLayout.LayoutParams(dp(context, 8), dp(context, 8))
        }
        // Nabız: canlı çağrı hissi (handoff sipPulse). Görünümden ayrılınca durdurulur.
        val pulse = ObjectAnimator.ofFloat(dot, View.ALPHA, 1f, 0.3f).apply {
            duration = 700
            repeatMode = ValueAnimator.REVERSE
            repeatCount = ValueAnimator.INFINITE
        }
        dot.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) = pulse.start()
            override fun onViewDetachedFromWindow(v: View) = pulse.cancel()
        })
        row.addView(dot)

        row.addView(
            text(context, "GELEN ÇAĞRI", 11f, ACC_FG, weight = 700).apply {
                letterSpacing = 0.14f
                setPadding(dp(context, 7), 0, 0, 0)
            }
        )

        row.addView(View(context).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1f) // esnek boşluk
        })

        row.addView(
            if (customer == null) {
                text(context, "Kayıtlı değil", 11.5f, T3, weight = 600)
            } else {
                text(context, formatPhone(phone), 12.5f, T3, weight = 500, tabular = true)
            }
        )
        return row
    }

    /** Dolgulu bakiye şeridi — liste rozetiyle aynı dil: borç kırmızı, temiz/alacak yeşil. */
    private fun balanceStrip(context: Context, kurus: Long): View = when {
        kurus > 0 -> strip(context, DEBT, "Borçlu", Color.WHITE, "${money(kurus)} ₺", Color.WHITE)
        kurus < 0 -> strip(context, OK, "Alacak", OK_INK, "${money(-kurus)} ₺", OK_INK)
        else -> strip(context, OK, "Borcu yok", OK_INK, "0,00 ₺", OK_INK)
    }

    /** Bayi notu — uyarı sarısı yumuşak şerit (kupon eksisi vb. dikkat isteyen bilgiler). */
    private fun noteStrip(context: Context, note: String): View {
        return text(context, note, 13.5f, WARN, weight = 600, maxLines = 2).apply {
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 11).toFloat()
                setColor(WARN_SOFT)
            }
            setPadding(dp(context, 14), dp(context, 11), dp(context, 14), dp(context, 11))
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            lp.setMargins(dp(context, 18), dp(context, 12), dp(context, 18), 0)
            layoutParams = lp
        }
    }

    /** Sol etiket + (varsa) sağ tutar taşıyan dolgulu şerit. */
    private fun strip(
        context: Context,
        bg: Int,
        label: String,
        labelColor: Int,
        amount: String?,
        amountColor: Int,
    ): View {
        val row = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 13).toFloat()
                setColor(bg)
            }
            setPadding(dp(context, 16), dp(context, 13), dp(context, 16), dp(context, 13))
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            lp.setMargins(dp(context, 18), dp(context, 14), dp(context, 18), 0)
            layoutParams = lp
        }
        row.addView(text(context, label, if (amount == null) 14f else 15f, labelColor, weight = 700))
        if (amount != null) {
            row.addView(View(context).apply {
                layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
            })
            row.addView(text(context, amount, 22f, amountColor, weight = 700, tabular = true))
        }
        return row
    }

    /**
     * Kapat düğmesi (çerçeveli, nötr). Kapatma DAVRANIŞI çağıran taraftadır (overlay/Activity
     * kök görünüme click listener koyar); düğme o listener'a delege eder — API değişmedi.
     */
    private fun closeButton(context: Context, root: View): View {
        return text(context, "Kapat", 14.5f, T2, weight = 600).apply {
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 16).toFloat() // SipRadius.card
                setColor(Color.TRANSPARENT)
                setStroke(dp(context, 1), LINE2)
            }
            minimumHeight = dp(context, 52) // dokunma hedefi ≥ 52 (DESIGN_SYSTEM)
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            lp.setMargins(dp(context, 14), dp(context, 18), dp(context, 14), dp(context, 14))
            layoutParams = lp
            setOnClickListener { root.performClick() }
        }
    }

    // ── Yardımcılar ─────────────────────────────────────────────────────────────────────────

    /** Pozitif bakiye müşterinin borcudur (veresiye); negatif bakiye onun alacağıdır. */
    fun balanceLine(kurus: Long): String = when {
        kurus > 0 -> "Borç: ${money(kurus)} ₺"
        kurus < 0 -> "Alacak: ${money(-kurus)} ₺"
        else -> "Bakiye temiz"
    }

    fun balanceColor(kurus: Long): Int = when {
        kurus > 0 -> DEBT
        kurus < 0 -> OK
        else -> T2
    }

    /** "05327710863" → "0532 771 08 63" (yalnız gösterim; eşleşme phone_last10 ile, değişmedi). */
    fun formatPhone(raw: String): String {
        val digits = raw.filter(Char::isDigit)
        val local = when {
            digits.length == 12 && digits.startsWith("90") -> "0" + digits.drop(2)
            digits.length == 10 -> "0$digits"
            digits.length == 11 && digits.startsWith("0") -> digits
            else -> return raw
        }
        return "${local.substring(0, 4)} ${local.substring(4, 7)} " +
            "${local.substring(7, 9)} ${local.substring(9, 11)}"
    }

    private fun money(kurus: Long): String =
        "${kurus / 100},${(kurus % 100).toString().padStart(2, '0')}"

    /**
     * IBM Plex Sans — Flutter asset'inden yüklenir (tipografi tasarım sistemiyle aynı).
     * Asset okunamazsa sistem fontuna düşer; kart HİÇBİR durumda çizimsiz kalmaz.
     */
    private val typefaceCache = HashMap<String, Typeface?>()

    private fun plex(context: Context, weight: Int): Typeface? {
        val file = when {
            weight >= 700 -> "IBMPlexSans-Bold.ttf"
            weight >= 600 -> "IBMPlexSans-SemiBold.ttf"
            else -> "IBMPlexSans-Regular.ttf"
        }
        return typefaceCache.getOrPut(file) {
            runCatching {
                Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/$file")
            }.getOrNull()
        }
    }

    private fun text(
        context: Context,
        value: String,
        sp: Float,
        color: Int,
        weight: Int = 400,
        tabular: Boolean = false,
        singleLine: Boolean = false,
        maxLines: Int = 0,
    ) = TextView(context).apply {
        text = value
        setTextColor(color)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        val plexFace = plex(context, weight)
        when {
            plexFace != null -> typeface = plexFace
            weight >= 600 -> setTypeface(typeface, Typeface.BOLD)
        }
        if (tabular) fontFeatureSettings = "tnum"
        if (singleLine) {
            isSingleLine = true
            ellipsize = android.text.TextUtils.TruncateAt.END
        } else if (maxLines > 0) {
            setMaxLines(maxLines)
            ellipsize = android.text.TextUtils.TruncateAt.END
        }
    }

    private fun View.padded(context: Context, l: Int, t: Int, r: Int, b: Int): View = apply {
        setPadding(dp(context, l), dp(context, t), dp(context, r), dp(context, b))
    }

    fun dp(context: Context, value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()
}
