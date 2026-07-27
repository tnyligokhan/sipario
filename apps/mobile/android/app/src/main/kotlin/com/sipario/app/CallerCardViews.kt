package com.sipario.app

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.graphics.drawable.GradientDrawable
import android.util.Log
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import com.sipario.app.CallerTema.basHarfler
import com.sipario.app.CallerTema.dp
import com.sipario.app.CallerTema.ikon
import com.sipario.app.CallerTema.para
import com.sipario.app.CallerTema.satirParams
import com.sipario.app.CallerTema.yazi

/**
 * Çağrı kartının PARÇALARI — CSS `.cagri-top` / `.cagri-kim` / `.cagri-bal` / `.cagri-bilgi` /
 * `.cagri-acts` (tasarım Sipario.html). İskeleti [CallerCard] kurar.
 *
 * Tamamen programatik: XML şişirme ve Flutter engine YOK — çağrı anında soğuk başlangıç
 * bütçesi 1 saniyedir (DECISIONS Faz 0).
 */
internal object CallerCardViews {

    private const val TAG = "SiparioCardViews"

    /** CSS `.cagri-top` — nabızlı nokta + "GELEN ÇAĞRI" + süre + kapat düğmesi. */
    fun ustSerit(context: Context, p: CallerTema.Palet, kok: View): View {
        val satir = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        satir.addView(canliNokta(context, p))
        satir.addView(
            yazi(context, "GELEN ÇAĞRI", 11f, p.accent, agirlik = 700, harfAralik = 0.12f)
                .apply { setPadding(dp(context, 7), 0, 0, 0) }
        )
        satir.addView(View(context).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1f) // esnek boşluk
        })

        // CSS `.cagri-since` — tasarımda sabit "şimdi"; kart çizildiği an çağrı henüz yeni.
        satir.addView(ikon(context, R.drawable.sip_ic_clock, 12, p.muted))
        satir.addView(
            yazi(context, "şimdi", 11.5f, p.muted, agirlik = 600)
                .apply { setPadding(dp(context, 4), 0, 0, 0) }
        )

        // CSS `.sheet-x` — 34'lük yuvarlak nötr düğme.
        satir.addView(
            ikon(context, R.drawable.sip_ic_x, 20, p.muted).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(p.surface2)
                }
                layoutParams = LinearLayout.LayoutParams(dp(context, 34), dp(context, 34))
                    .apply { setMargins(dp(context, 10), 0, 0, 0) }
                setPadding(dp(context, 7), dp(context, 7), dp(context, 7), dp(context, 7))
                contentDescription = "Kapat"
                // Kapatma mantığı çağıranda; düğme yalnız kökün listener'ını tetikler.
                setOnClickListener { kok.performClick() }
            }
        )
        return satir
    }

    /**
     * CSS `.cagri-live i` — accent nokta ve etrafında nefes alan hale.
     * Animatör görünümden ayrılınca DURDURULUR: overlay penceresi kaldırıldığında
     * çalışmaya devam eden bir animatör pencereyi canlı tutar.
     */
    private fun canliNokta(context: Context, p: CallerTema.Palet): View {
        val cap = dp(context, 22)
        val kutu = FrameLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(cap, cap)
        }

        val hale = View(context).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(p.accent)
            }
            alpha = 0.15f
            layoutParams = FrameLayout.LayoutParams(cap, cap, Gravity.CENTER)
        }
        val nokta = View(context).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(p.accent)
            }
            layoutParams = FrameLayout.LayoutParams(
                dp(context, 8), dp(context, 8), Gravity.CENTER,
            )
        }
        kutu.addView(hale)
        kutu.addView(nokta)

        val nabiz = ObjectAnimator.ofPropertyValuesHolder(
            hale,
            PropertyValuesHolder.ofFloat(View.SCALE_X, 0.62f, 1f),
            PropertyValuesHolder.ofFloat(View.SCALE_Y, 0.62f, 1f),
            PropertyValuesHolder.ofFloat(View.ALPHA, 0.15f, 0.04f),
        ).apply {
            duration = 700
            repeatMode = ValueAnimator.REVERSE
            repeatCount = ValueAnimator.INFINITE
        }
        kutu.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) = nabiz.start()
            override fun onViewDetachedFromWindow(v: View) = nabiz.cancel()
        })
        return kutu
    }

    /** CSS `.cagri-kim` — avatar + ad/numara + bakiye rozeti. */
    fun kimSatiri(
        context: Context,
        p: CallerTema.Palet,
        customer: CustomerLookup.Customer?,
        phone: String,
    ): View {
        val satir = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = satirParams(context, ust = 16)
        }

        // CSS `.cagri-av` (46/r16) — kayıtsızda `.kayitsiz` nötr zemin + telefon ikonu.
        val cap = dp(context, 46)
        if (customer != null) {
            satir.addView(
                yazi(context, basHarfler(customer.name), 15f, p.accent, agirlik = 700, baslik = true).apply {
                    gravity = Gravity.CENTER
                    background = GradientDrawable().apply {
                        cornerRadius = dp(context, 16).toFloat()
                        setColor(p.accentSoft)
                    }
                    layoutParams = LinearLayout.LayoutParams(cap, cap)
                }
            )
        } else {
            satir.addView(
                ikon(context, R.drawable.sip_ic_phone, 20, p.muted).apply {
                    background = GradientDrawable().apply {
                        cornerRadius = dp(context, 16).toFloat()
                        setColor(p.surface2)
                    }
                    layoutParams = LinearLayout.LayoutParams(cap, cap)
                    val ic = dp(context, 13)
                    setPadding(ic, ic, ic, ic)
                }
            )
        }

        // CSS `.cagri-kim-mid` — kayıtlıda ad baskın, kayıtsızda numara baskın.
        val orta = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                .apply { setMargins(dp(context, 12), 0, dp(context, 10), 0) }
        }
        if (customer != null) {
            orta.addView(
                yazi(context, customer.name, 20f, p.ink, agirlik = 800, baslik = true, harfAralik = -0.02f, tekSatir = true)
            )
            orta.addView(
                yazi(context, CallerCard.formatPhone(phone), 12.5f, p.muted, agirlik = 500, tabular = true, tekSatir = true)
                    .apply { setPadding(0, dp(context, 3), 0, 0) }
            )
        } else {
            orta.addView(
                yazi(context, CallerCard.formatPhone(phone), 20f, p.ink, agirlik = 800, baslik = true, harfAralik = -0.02f, tabular = true, tekSatir = true)
            )
            orta.addView(
                yazi(context, "Bu numara defterinizde yok", 12.5f, p.muted, agirlik = 500, tekSatir = true)
                    .apply { setPadding(0, dp(context, 3), 0, 0) }
            )
        }
        satir.addView(orta)
        satir.addView(bakiyePili(context, p, customer))
        return satir
    }

    /** CSS `.cagri-kim .pill` — Borç / Alacak / Temiz / Kayıtsız. */
    private fun bakiyePili(context: Context, p: CallerTema.Palet, customer: CustomerLookup.Customer?): View {
        val (etiket, renk, zemin) = when {
            customer == null -> Triple("Kayıtsız", p.ink2, p.surface2)
            customer.balanceKurus > 0 -> Triple("Borç", p.danger, p.dangerSoft)
            customer.balanceKurus < 0 -> Triple("Alacak", p.ok, p.okSoft)
            // Temiz müşteride tasarım nötr değil YEŞİL rozet gösterir.
            else -> Triple("Temiz", p.ok, p.okSoft)
        }
        return yazi(context, etiket, 11f, renk, agirlik = 700).apply {
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 999).toFloat()
                setColor(zemin)
            }
            setPadding(dp(context, 10), dp(context, 4), dp(context, 10), dp(context, 4))
        }
    }

    /** CSS `.cagri-bal` — yalnız bakiye 0 değilken çizilir. */
    fun bakiyeSeridi(context: Context, p: CallerTema.Palet, kurus: Long): View {
        val borc = kurus > 0
        val renk = if (borc) p.danger else p.ok
        val satir = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 16).toFloat()
                setColor(if (borc) p.dangerSoft else p.okSoft)
            }
            setPadding(dp(context, 15), dp(context, 12), dp(context, 15), dp(context, 12))
            layoutParams = satirParams(context, ust = 14)
        }
        satir.addView(
            yazi(context, if (borc) "AÇIK BORÇ" else "ALACAĞI VAR", 11.5f, renk, agirlik = 700, harfAralik = 0.06f)
        )
        satir.addView(View(context).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
        })
        satir.addView(
            yazi(context, para(kotlin.math.abs(kurus)), 20f, renk, agirlik = 800, baslik = true, tabular = true, harfAralik = -0.01f)
        )
        return satir
    }

    /** CSS `.cagri-bilgi` — adres ve müşteri notu. Hiçbiri yoksa satır kutusu hiç kurulmaz. */
    fun bilgiSatirlari(context: Context, p: CallerTema.Palet, c: CustomerLookup.Customer): View? {
        val adres = c.address?.takeIf { it.isNotBlank() }
        val not = c.note?.takeIf { it.isNotBlank() }
        if (adres == null && not == null) return null

        val kutu = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = satirParams(context, ust = 13)
        }
        if (adres != null) {
            kutu.addView(bilgiSatiri(context, p, R.drawable.sip_ic_pin, p.muted, adres, p.ink2, uyari = false, ustBosluk = 0))
        }
        if (not != null) {
            // CSS `.cagri-brow.warn` — sarı zeminli not satırı.
            kutu.addView(bilgiSatiri(context, p, R.drawable.sip_ic_info, p.warn, not, p.warn, uyari = true, ustBosluk = if (adres != null) 8 else 0))
        }
        return kutu
    }

    private fun bilgiSatiri(
        context: Context,
        p: CallerTema.Palet,
        ikonId: Int,
        ikonRenk: Int,
        metin: String,
        metinRenk: Int,
        uyari: Boolean,
        ustBosluk: Int,
    ): View {
        val satir = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.TOP
            layoutParams = satirParams(context, ust = ustBosluk)
            if (uyari) {
                background = GradientDrawable().apply {
                    cornerRadius = dp(context, 12).toFloat()
                    setColor(p.warnSoft)
                }
                setPadding(dp(context, 11), dp(context, 9), dp(context, 11), dp(context, 9))
            }
        }
        satir.addView(
            ikon(context, ikonId, 14, ikonRenk).apply {
                layoutParams = LinearLayout.LayoutParams(dp(context, 14), dp(context, 14))
                    .apply { setMargins(0, dp(context, 2), dp(context, 8), 0) }
            }
        )
        satir.addView(
            yazi(context, metin, 12.5f, metinRenk, agirlik = 600, satirlar = 3).apply {
                setLineSpacing(0f, 1.45f)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
        )
        return satir
    }

    /** CSS `.cagri-acts` — 50 yüksekliğinde eylem düğmeleri. */
    fun eylemler(
        context: Context,
        p: CallerTema.Palet,
        customer: CustomerLookup.Customer?,
        phone: String,
    ): View {
        val kutu = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = satirParams(context, ust = 16)
        }
        if (customer != null) {
            kutu.addView(dugme(context, "Sipariş Oluştur", R.drawable.sip_ic_plus, p.accent, p.accentInk, "siparis", phone, 0))
            kutu.addView(dugme(context, "Defteri Aç", R.drawable.sip_ic_book, p.surface2, p.ink, "defter", phone, 8))
        } else {
            kutu.addView(dugme(context, "Müşteri Olarak Kaydet", R.drawable.sip_ic_user_plus, p.accent, p.accentInk, "kaydet", phone, 0))
        }
        return kutu
    }

    /**
     * Eylem düğmesi. Dokunulduğunda uygulamayı açar — Flutter motoru YALNIZ burada, yani
     * bayi bilerek dokunduğunda başlar; kartın çizim bütçesi etkilenmez.
     */
    private fun dugme(
        context: Context,
        etiket: String,
        ikonId: Int,
        zemin: Int,
        murekkep: Int,
        eylem: String,
        phone: String,
        ustBosluk: Int,
    ): View {
        val satir = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 16).toFloat()
                setColor(zemin)
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(context, 50),
            ).apply { setMargins(0, dp(context, ustBosluk), 0, 0) }
            isClickable = true
            contentDescription = etiket
            setOnClickListener { eylemiAc(context, eylem, phone) }
        }
        satir.addView(
            ikon(context, ikonId, 18, murekkep).apply {
                layoutParams = LinearLayout.LayoutParams(dp(context, 18), dp(context, 18))
                    .apply { setMargins(0, 0, dp(context, 7), 0) }
            }
        )
        satir.addView(yazi(context, etiket, 14.5f, murekkep, agirlik = 700))
        return satir
    }

    /**
     * Eylemi uygulamaya devreder ve KARTI KAPATIR. İkisi bir arada olmak zorunda:
     * kart açık kalırsa bayi açtığı ekranı kartın altında görür, kapanıp eylem iletilmezse
     * dokunuş boşa gider. İkisi de ayrı ayrı kırıktı (2026-07-26).
     *
     * Eylemi MainActivity karşılar; motor yaşamıyorsa niyet ekstraları orada BEKLETİLİR
     * (bkz. `MainActivity.bekleyen`), Flutter ayağa kalkınca çekilir.
     */
    private fun eylemiAc(context: Context, eylem: String, phone: String) {
        val niyet = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(CallerCard.EXTRA_EYLEM, eylem)
            .putExtra(CallerCard.EXTRA_NUMARA, phone)
        runCatching { context.startActivity(niyet) }
            .onFailure { Log.w(TAG, "eylem acilamadi: ${it.javaClass.simpleName}") }
        CallerOverlay.kapat(context)
    }
}
