package com.sipario.app

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Arayan kartının görünümü. Tek yerde tanımlı; hem kilitsiz ekrandaki overlay penceresi
 * hem de kilit ekranındaki tam ekran Activity bunu kullanır. İki yolun farklı görünmesi,
 * bayinin aynı bilgiyi iki ayrı yerde araması demek olurdu.
 *
 * Tamamen programatik: XML şişirme ve Flutter engine yok, soğuk başlangıç bütçesi 1 sn.
 */
object CallerCard {

    fun build(context: Context, customer: CustomerLookup.Customer?, phone: String): View {
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            val pad = dp(context, 16)
            setPadding(pad, pad, pad, pad)
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 16).toFloat()
                setColor(Color.parseColor("#FF1B1B1F"))
                setStroke(dp(context, 1), Color.parseColor("#FF3A3A42"))
            }
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            val side = dp(context, 12)
            lp.setMargins(side, 0, side, 0)
            layoutParams = lp
            elevation = dp(context, 8).toFloat()
        }

        if (customer == null) {
            root.addView(text(context, "Kayıtlı olmayan numara", 18f, Color.WHITE, bold = true))
            root.addView(text(context, phone, 15f, Color.parseColor("#FFB0B0B8")))
            root.addView(text(context, "Sipario · dokunarak kapat", 12f, Color.parseColor("#FF6E6E76")))
            return root
        }

        root.addView(text(context, customer.name, 20f, Color.WHITE, bold = true))
        customer.address?.takeIf { it.isNotBlank() }?.let {
            root.addView(text(context, it, 15f, Color.parseColor("#FFB0B0B8")))
        }
        root.addView(text(context, balanceLine(customer.balanceKurus), 17f, balanceColor(customer.balanceKurus), bold = true))
        customer.note?.takeIf { it.isNotBlank() }?.let {
            root.addView(text(context, it, 14f, Color.parseColor("#FFE0C060")))
        }
        root.addView(text(context, "Sipario · dokunarak kapat", 12f, Color.parseColor("#FF6E6E76")))
        return root
    }

    /** Pozitif bakiye müşterinin borcudur (veresiye); negatif bakiye onun alacağıdır. */
    fun balanceLine(kurus: Long): String = when {
        kurus > 0 -> "Borç: ${money(kurus)} ₺"
        kurus < 0 -> "Alacak: ${money(-kurus)} ₺"
        else -> "Bakiye temiz"
    }

    fun balanceColor(kurus: Long): Int = when {
        kurus > 0 -> Color.parseColor("#FFFF6B6B")
        kurus < 0 -> Color.parseColor("#FF4ECB71")
        else -> Color.parseColor("#FFB0B0B8")
    }

    private fun money(kurus: Long): String =
        "${kurus / 100},${(kurus % 100).toString().padStart(2, '0')}"

    private fun text(context: Context, value: String, sp: Float, color: Int, bold: Boolean = false) =
        TextView(context).apply {
            text = value
            setTextColor(color)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
            if (bold) setTypeface(typeface, Typeface.BOLD)
        }

    fun dp(context: Context, value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()
}
