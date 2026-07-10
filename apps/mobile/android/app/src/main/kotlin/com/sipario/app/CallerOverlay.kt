package com.sipario.app

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewTreeObserver
import android.view.WindowManager

/**
 * Arayan kartını gösterir. Ekranın kilitli olup olmamasına göre iki ayrı yol vardır ve
 * bu bir tercih değil, zorunluluktur:
 *
 *  - Kilitli DEĞİLSE: `TYPE_APPLICATION_OVERLAY` penceresi. Hızlı, Activity açmaz,
 *    kullanıcının o an yaptığı işi bölmez.
 *  - Kilitliyse: tam ekran niyetli bildirim → [CallerActivity]. Overlay penceresi
 *    keyguard'ın ALTINDA kalır; çizilir, `onDraw` tetiklenir, ama kimse görmez.
 *    Sahada telefon çoğu zaman kilitli olduğu için asıl yol budur.
 *
 * Her iki yol da başarısız olursa yüksek öncelikli bildirime düşülür.
 * Flutter engine hiçbir yolda başlatılmaz.
 */
object CallerOverlay {

    private const val CHANNEL_ID = "sipario_caller"

    /**
     * Kart dokunulmadan kapanmaz; bu yalnız unutulan kartlara karşı emniyet süresi.
     * Saha geri bildirimi: 12 sn'lik otomatik kapanma, adres konuşma sırasında lazımken
     * kartı erken kaçırıyordu. Rakip uygulama da kapat'a basılmadan kapanmıyor.
     */
    private const val SAFETY_DISMISS_MS = 120_000L
    private const val TAG = "SiparioOverlay"

    /** Yanıt/kapanış anında kartı yeniden gösterebilmek için son çağrının bilgisi. */
    @Volatile private var lastCustomer: CustomerLookup.Customer? = null
    @Volatile private var lastPhone: String? = null

    /** Eski bir kapatma zamanlayıcısı yeni gösterilen kartı öldürmesin diye nesil sayacı. */
    private var generation = 0

    /** Kart tam ekran açıldığında [CallerActivity] bu bildirimi kaldırır. */
    const val NOTIFICATION_ID = 6100

    // Not: tam ekran niyet GECİKTİRİLEMEZ. Sistem, Activity'yi yalnız ekran kapalı/kilitliyken
    // doğrudan açar; 600 ms beklendiğinde çağrı ekranı ekranı yakıyor, niyet o pencereyi
    // kaçırıyor ve sıradan bildirime düşüyordu (Xiaomi HyperOS'ta ölçüldü: bildirim gönderildi,
    // kart hiç açılmadı). Çağrı ekranının üstüne çıkma işi [CallerActivity]'nin sorumluluğunda.

    private val main = Handler(Looper.getMainLooper())
    private var current: View? = null

    fun show(
        context: Context,
        customer: CustomerLookup.Customer?,
        phone: String,
        t0: Long,
        simulated: Boolean,
        direction: String = "in",
    ) {
        val app = context.applicationContext
        val locked = (app.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked

        lastCustomer = customer
        lastPhone = phone

        main.post {
            val shown = if (locked) {
                // İki yol BİRDEN denenir, çünkü kilitli ekranda kabuklar ikiye ayrılıyor:
                //  - Samsung tarzı: çağrı bildirimle gelir, keyguard örtülmez → kartı
                //    tam ekran Activity gösterir; overlay keyguard altında kalır, zararsız.
                //  - MIUI tarzı: tam ekran çağrı ekranı keyguard'ı örter ve Activity'mizin
                //    üstüne biner → keyguard örtüldüğü anda SAW overlay'i çağrı ekranının
                //    ÜSTÜNDE görünür olur (MIUI'nin "Kilit ekranında göster" izni tam bunu açar).
                // Overlay burada ölçüm YAZMAZ; yazsaydı tek çağrı iki kayıt üretirdi.
                val fsi = showFullScreen(app, customer, phone, t0, simulated, direction)
                if (Settings.canDrawOverlays(app)) {
                    showOverlay(app, customer, phone, t0, simulated, direction, locked = true, record = false)
                }
                fsi
            } else {
                Settings.canDrawOverlays(app) &&
                    showOverlay(app, customer, phone, t0, simulated, direction, locked = false, record = true)
            }
            if (!shown) showNotification(app, customer, phone, t0, simulated, locked, direction)
        }
    }

    /**
     * Son gösterilen kartı yeniden gösterir — [CallSessionWatcher] yanıt ve kapanış
     * anlarında çağırır. Ölçüm YAZILMAZ: bu bir tanıma değil, aynı çağrının devamı.
     *
     * Kilitliyken YOL AYRIMI kritik ve sahada kanıtlandı:
     *  - Overlay, keyguard örtülü olsa bile MIUI'de ASLA üste çizilmiyor (kilit açılınca
     *    ortaya çıkıyordu). Kilitliyken overlay KULLANILMAZ.
     *  - En son başlayan showWhenLocked Activity en üstte çizilir. Çağrı ekranından SONRA
     *    başlarsak onun üstüne çıkarız — rakip uygulamanın yanıt anında yaptığı tam bu.
     */
    fun reshow(context: Context) {
        val phone = lastPhone ?: return
        val customer = lastCustomer
        val app = context.applicationContext
        val locked = (app.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked
        main.post {
            if (locked) {
                val i = Intent(app, CallerActivity::class.java)
                    .addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                    )
                    .putExtra(CallerActivity.EXTRA_PHONE, phone)
                    .putExtra(CallerActivity.EXTRA_RECORD, false)
                // Arka plandan başlatma muafiyeti: SYSTEM_ALERT_WINDOW iznimiz var.
                runCatching { app.startActivity(i) }
                    .onFailure { Log.w(TAG, "yeniden gosterim reddedildi: ${it.javaClass.simpleName}") }
            } else {
                if (!Settings.canDrawOverlays(app)) return@post
                showOverlay(app, customer, phone, System.nanoTime(), simulated = false, direction = "in", locked = false, record = false)
            }
        }
    }

    // --- Kilitli ekran yolu: tam ekran niyetli bildirim ---

    /**
     * Bildirimi gönderir; sistem kilit ekranında [CallerActivity]'yi doğrudan açar.
     * Ölçüm kaydını Activity'nin kendisi yazar (kart gerçekten çizildiğinde), burada değil —
     * bildirimin gönderilmiş olması kartın görüldüğü anlamına gelmez.
     */
    private fun showFullScreen(
        context: Context,
        customer: CustomerLookup.Customer?,
        phone: String,
        t0: Long,
        simulated: Boolean,
        direction: String,
    ): Boolean {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Android 14+: bu izin yalnız arama ve alarm uygulamalarına otomatik verilir.
        // Yoksa bildirim tam ekran açılmaz, sıradan bir bildirime düşer.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && !nm.canUseFullScreenIntent()) {
            Log.w(TAG, "tam ekran niyet izni yok, kilit ekraninda kart gosterilemez")
            return false
        }

        ensureChannel(nm)

        val intent = Intent(context, CallerActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
            .putExtra(CallerActivity.EXTRA_PHONE, phone)
            .putExtra(CallerActivity.EXTRA_T0, t0)
            .putExtra(CallerActivity.EXTRA_SIMULATED, simulated)
            .putExtra(CallerActivity.EXTRA_DIRECTION, direction)

        val pi = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = buildNotification(context, customer, phone)
            .setFullScreenIntent(pi, true)
            .build()

        return try {
            nm.notify(NOTIFICATION_ID, notification)
            Log.i(TAG, "tam ekran niyet gonderildi (kilitli ekran)")
            true
        } catch (e: SecurityException) {
            Log.e(TAG, "bildirim gonderilemedi: POST_NOTIFICATIONS reddedilmis")
            false
        }
    }

    // --- Kilitsiz ekran yolu: overlay penceresi ---

    private fun showOverlay(
        context: Context,
        customer: CustomerLookup.Customer?,
        phone: String,
        t0: Long,
        simulated: Boolean,
        direction: String,
        locked: Boolean,
        record: Boolean,
    ): Boolean {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        dismiss(wm)
        // Keyguard arkasında bekleyen kart Activity'si varsa kapat — kilit açılınca
        // overlay ile üst üste iki kart çıkmasın.
        CallerActivity.active?.finish()

        val card = CallerCard.build(context, customer, phone)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            // NOT_FOCUSABLE: altındaki çağrı ekranı kullanılabilir kalır, tuşları biz yutmayız.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            android.graphics.PixelFormat.TRANSLUCENT,
        ).apply {
            // Ekranın ORTASI. Üstte sistemin heads-up çağrı bildirimi, altta tam ekran
            // çağrı arayüzünün Cevapla/Reddet düğmeleri var; ikisi de bizim değil.
            gravity = Gravity.CENTER
        }

        return try {
            wm.addView(card, params)
            Log.i(TAG, if (locked) "pencere eklendi (kilitli, sessiz)" else "pencere eklendi (kilitsiz ekran)")
            current = card

            if (record) {
                val observer = card.viewTreeObserver
                observer.addOnDrawListener(object : ViewTreeObserver.OnDrawListener {
                    private var recorded = false
                    override fun onDraw() {
                        if (recorded) return
                        recorded = true
                        val ms = (System.nanoTime() - t0) / 1_000_000
                        card.post {
                            @Suppress("DEPRECATION")
                            card.viewTreeObserver.removeOnDrawListener(this)
                        }
                        LatencyLog.record(context, ms, customer != null, simulated, "overlay", locked, direction)
                    }
                })
            }

            card.setOnClickListener { dismiss(wm) }
            val gen = ++generation
            main.postDelayed({ if (generation == gen) dismiss(wm) }, SAFETY_DISMISS_MS)
            true
        } catch (e: WindowManager.BadTokenException) {
            // İzin çalışma anında geri alınmış olabilir (bazı OEM'ler yapıyor).
            false
        } catch (e: SecurityException) {
            false
        }
    }

    private fun dismiss(wm: WindowManager) {
        current?.let {
            try {
                wm.removeView(it)
            } catch (_: IllegalArgumentException) {
                // Zaten kaldırılmış.
            }
        }
        current = null
    }

    // --- Son çare: yüksek öncelikli bildirim ---

    private fun showNotification(
        context: Context,
        customer: CustomerLookup.Customer?,
        phone: String,
        t0: Long,
        simulated: Boolean,
        locked: Boolean,
        direction: String,
    ) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(nm)
        try {
            nm.notify(NOTIFICATION_ID, buildNotification(context, customer, phone).build())
            val ms = (System.nanoTime() - t0) / 1_000_000
            LatencyLog.record(context, ms, customer != null, simulated, "notification", locked, direction)
        } catch (_: SecurityException) {
            LatencyLog.record(context, -1, customer != null, simulated, "failed", locked, direction)
        }
    }

    private fun buildNotification(
        context: Context,
        customer: CustomerLookup.Customer?,
        phone: String,
    ): Notification.Builder {
        val title = customer?.name ?: "Kayıtlı olmayan numara"
        val body = customer
            ?.let { "${it.address.orEmpty()}  ·  ${CallerCard.balanceLine(it.balanceKurus)}" }
            ?: phone

        // Kart çağrı ekranının altında kalırsa bilginin tamamını taşıyan tek yer bu
        // bildirim olur; o yüzden genişletilmiş hali kartla aynı içeriği verir.
        val big = customer?.let {
            buildString {
                it.address?.takeIf(String::isNotBlank)?.let { a -> appendLine(a) }
                appendLine(CallerCard.balanceLine(it.balanceKurus))
                it.note?.takeIf(String::isNotBlank)?.let { n -> appendLine(n) }
            }.trimEnd()
        } ?: phone

        return Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(big))
            .setCategory(Notification.CATEGORY_CALL)
            // Kilit ekranında içerik gizlenmesin: kart çağrı ekranının altında kalırsa
            // müşteriyi ve borcu gösteren tek yer bu bildirim olur.
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
    }

    private fun ensureChannel(nm: NotificationManager) {
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Gelen arama", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Arayan müşteri bilgisi"
                setShowBadge(false)
            }
        )
    }
}
