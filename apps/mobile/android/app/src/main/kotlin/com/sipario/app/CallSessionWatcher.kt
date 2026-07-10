package com.sipario.app

import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log

/**
 * Çağrının yanıtlanma ve bitiş anlarını yakalar — READ_PHONE_STATE OLMADAN.
 * `AudioManager.mode` okumak izin gerektirmez: RINGTONE=çalıyor, IN_CALL=açıldı, NORMAL=bitti.
 * Kırmızı çizgi #6 korunur.
 *
 * Neden var: MIUI kilit ekranında tam ekran çağrı arayüzü her şeyin üstüne biner ve bu
 * z-order savaşı kazanılamıyor — Play'deki rakip (Halı Takip) bile zil çalarken altta
 * kalıyor. Rakibin çözümü kartı yanıt ve kapanış anlarında YENİDEN göstermek; aynı deseni
 * uyguluyoruz. Bayi siparişi konuşma SIRASINDA alır; adres ve borç tam o anda lazımdır.
 *
 * Süreç MIUI tarafından konuşma ortasında öldürülürse izleyici de ölür — en iyi çaba.
 * Kart görünür olduğu sürece süreç görünür öncelikte kalır, bu riski azaltır.
 */
object CallSessionWatcher {

    private const val TAG = "SiparioWatcher"
    private const val POLL_MS = 750L
    private const val MAX_WATCH_MS = 10 * 60_000L

    private val main = Handler(Looper.getMainLooper())
    private var running = false

    fun start(context: Context) {
        if (running) return
        running = true

        val app = context.applicationContext
        val audio = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val startedAt = SystemClock.elapsedRealtime()
        var sawCall = false
        var answered = false

        lateinit var tick: Runnable
        tick = Runnable {
            when (audio.mode) {
                AudioManager.MODE_RINGTONE -> sawCall = true

                AudioManager.MODE_IN_CALL, AudioManager.MODE_IN_COMMUNICATION -> {
                    sawCall = true
                    if (!answered) {
                        answered = true
                        Log.i(TAG, "cagri acildi, kart yeniden gosteriliyor")
                        CallerOverlay.reshow(app)
                    }
                }

                AudioManager.MODE_NORMAL -> if (sawCall) {
                    // Yanıtlanmadan NORMAL'e dönüş = cevapsız çağrı; kartı yine göster —
                    // bayi kimin aradığını kaçırmamalı.
                    Log.i(TAG, "cagri bitti (yanitlandi=$answered), kart yeniden gosteriliyor")
                    CallerOverlay.reshow(app)
                    running = false
                    return@Runnable
                }
            }

            if (SystemClock.elapsedRealtime() - startedAt > MAX_WATCH_MS) {
                Log.w(TAG, "izleme zaman asimi")
                running = false
                return@Runnable
            }
            main.postDelayed(tick, POLL_MS)
        }
        main.post(tick)
    }
}
