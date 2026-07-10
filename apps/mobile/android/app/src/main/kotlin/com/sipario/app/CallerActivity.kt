package com.sipario.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewTreeObserver
import android.view.WindowManager

/**
 * Kilit ekranının ÜSTÜNDE gösterilen arayan kartı.
 *
 * Neden Activity: `TYPE_APPLICATION_OVERLAY` penceresi keyguard'ın altında kalır — hiçbir
 * pencere bayrağı bunu değiştirmez (FLAG_SHOW_WHEN_LOCKED API 27'de kaldırıldı ve zaten
 * yalnız Activity pencerelerinde çalışıyordu). Keyguard'ı geçebilen tek yüzey
 * `setShowWhenLocked(true)` olan bir Activity'dir.
 *
 * Neden tam ekran DEĞİL: bu Activity, sistemin çağrı ekranının (Reddet/Yanıtla düğmeleri)
 * üstünde durur. Tam ekran olsaydı o düğmeleri yutardı. Bunun yerine ortada duran bir
 * pencere olarak açılır ve `FLAG_NOT_TOUCH_MODAL` ile kart dışına yapılan her dokunma
 * alttaki çağrı ekranına geçer. Bayi kartı okur, çağrıyı normal şekilde açar.
 *
 * Flutter engine burada da başlatılmaz.
 */
class CallerActivity : Activity() {

    private val main = Handler(Looper.getMainLooper())

    // Dokunmadan kapanmaz; bu yalnız unutulan kartlara karşı emniyet süresi.
    private val autoDismissMs = 120_000L
    private var reordered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        active = this

        // Manifest'te de beyan edildi; bazı OEM kabuklarında ikisi birden gerekiyor.
        setShowWhenLocked(true)
        setTurnScreenOn(true)

        // Bildirim bilerek KALDIRILMIYOR: kart, sistemin çağrı ekranının altında kalırsa
        // bayinin müşteriyi ve borcunu görebileceği tek yer o bildirim olur.
        // Aynı bilgiyi iki yerde görmek, hiç görmemekten iyidir.

        window.apply {
            setLayout(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
            )
            setGravity(Gravity.CENTER)
            // Kart dışındaki dokunmalar bize gelmez, alttaki çağrı ekranına düşer.
            addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL)
            // Arkadaki çağrı ekranı kararmasın; bayi düğmeleri net görsün.
            clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        }
        // Kart dışına dokunmak kartı kapatmasın — o dokunma çağrıyı yanıtlıyor olabilir.
        setFinishOnTouchOutside(false)

        val phone = intent.getStringExtra(EXTRA_PHONE).orEmpty()
        val t0 = intent.getLongExtra(EXTRA_T0, System.nanoTime())
        val simulated = intent.getBooleanExtra(EXTRA_SIMULATED, false)
        val direction = intent.getStringExtra(EXTRA_DIRECTION) ?: "in"

        // Yanıt/kapanış anındaki yeniden gösterimler ölçüm yazmaz — tanıma değil,
        // aynı çağrının devamı.
        val record = intent.getBooleanExtra(EXTRA_RECORD, true)

        val customer = CustomerLookup.find(this, phone)
        val card = CallerCard.build(this, customer, phone)
        card.setOnClickListener { finish() }
        setContentView(card)

        // Ölçüm noktası: kart ilk kez EKRANA ÇİZİLDİĞİ an.
        if (record) {
            card.viewTreeObserver.addOnDrawListener(object : ViewTreeObserver.OnDrawListener {
                private var recorded = false
                override fun onDraw() {
                    if (recorded) return
                    recorded = true
                    val ms = (System.nanoTime() - t0) / 1_000_000
                    card.post {
                        @Suppress("DEPRECATION")
                        card.viewTreeObserver.removeOnDrawListener(this)
                    }
                    LatencyLog.record(
                        this@CallerActivity,
                        ms,
                        matched = customer != null,
                        simulated = simulated,
                        path = "fullscreen",
                        locked = true,
                        direction = direction,
                    )
                }
            })
        }

        main.postDelayed({ if (!isFinishing) finish() }, autoDismissMs)

        // Xiaomi kilitli ekranda tam ekran çağrı ekranı açar ve bizim üstümüze biner
        // (Samsung bunun yerine bildirim gösterdiği için orada sorun çıkmıyor). Çağrı
        // ekranı hiç odak almadan da açılabildiği için focus sinyaline tek başına güvenmiyoruz.
        main.postDelayed({ bringToFrontOnce() }, FALLBACK_REORDER_MS)
    }

    /**
     * Çağrı ekranı üstümüze bindiğinde odağı kaybederiz; bir kez öne dönüyoruz.
     * Tek sefer, çünkü çağrı yanıtlandığında kullanıcının konuşma ekranını inatla
     * örtmek kartı faydalı olmaktan çıkarır.
     */
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) main.postDelayed({ bringToFrontOnce() }, FOCUS_LOST_REORDER_MS)
    }

    private fun bringToFrontOnce() {
        if (reordered || isFinishing) return
        reordered = true
        // Arka plandan Activity başlatma kısıtından SYSTEM_ALERT_WINDOW izniyle muafız.
        startActivity(
            Intent(this, CallerActivity::class.java)
                .addFlags(
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_NEW_TASK
                )
                .putExtra(EXTRA_PHONE, intent.getStringExtra(EXTRA_PHONE))
                .putExtra(EXTRA_RECORD, false)
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        if (active === this) active = null
    }

    companion object {
        const val EXTRA_PHONE = "phone"
        const val EXTRA_T0 = "t0"
        const val EXTRA_SIMULATED = "simulated"
        const val EXTRA_DIRECTION = "direction"
        const val EXTRA_RECORD = "record"

        private const val FOCUS_LOST_REORDER_MS = 150L
        private const val FALLBACK_REORDER_MS = 900L

        /**
         * Yaşayan kart Activity'si. Overlay ile yeniden gösterim yapılırken bu kapatılır;
         * yoksa keyguard arkasında bekleyen Activity kartı + overlay kartı, kilit açılınca
         * üst üste iki kart olarak çıkıyor (sahada görüldü).
         */
        @Volatile var active: CallerActivity? = null
    }
}
