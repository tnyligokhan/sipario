package com.sipario.app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.os.Bundle
import android.provider.Settings

/**
 * Bildirimin gövdesine dokunulduğunda arayan kartını YENİDEN açar. Hiçbir şey çizmez:
 * açılır, [CallerOverlay.reshow]'u çağırır ve kapanır.
 *
 * NEDEN ACTIVITY (BroadcastReceiver değil): kilitli ekranda kart bir Activity'dir
 * ([CallerActivity]) ve Android 12+ bildirimden başlatılan bir alıcının ya da servisin
 * Activity başlatmasını engeller ("notification trampoline"). Activity'den Activity
 * başlatmak bu kısıtın dışındadır, yani kilitli ekran yolu ancak böyle çalışır.
 *
 * NEDEN DOĞRUDAN [CallerActivity] DEĞİL: kilitsiz ekranda kart overlay penceresi olarak
 * gösterilir — Activity açmak bayinin o an yaptığı işi böler. Kilitli/kilitsiz ayrımını
 * zaten [CallerOverlay.reshow] biliyor; burada o karar yeniden verilmez.
 *
 * Flutter engine burada da başlatılmaz.
 */
class KartiAcActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)

        val phone = intent.getStringExtra(EXTRA_PHONE)?.takeIf(String::isNotBlank)
        // Yön verilmemişse çağrının kendi yönü korunur; `kuyruktan(null)` GELEN'e çivilerdi.
        val yon = intent.getStringExtra(EXTRA_DIRECTION)?.let(CagriYonu::kuyruktan)

        val kilitli = (getSystemService(KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked
        if (phone != null && !kilitli && !Settings.canDrawOverlays(this)) {
            // Üstte çizme izni yoksa kilitsiz yol overlay'i kuramaz ve dokunuş SESSİZCE ölür.
            // Kart Activity'si o izne bağlı değil; bildirime dokunmak karşılıksız kalmasın.
            startActivity(
                Intent(this, CallerActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    .putExtra(CallerActivity.EXTRA_PHONE, phone)
                    .putExtra(CallerActivity.EXTRA_DIRECTION, (yon ?: CagriYonu.GELEN).kuyrukKodu)
                    .putExtra(CallerActivity.EXTRA_RECORD, false)
            )
        } else {
            CallerOverlay.reshow(this, yon, phone)
        }

        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    companion object {
        const val EXTRA_PHONE = "phone"
        const val EXTRA_DIRECTION = "direction"
    }
}
