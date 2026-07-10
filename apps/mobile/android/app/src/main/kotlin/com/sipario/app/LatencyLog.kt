package com.sipario.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Faz 0 go/no-go kanıt defteri: her tanıma denemesinin gecikmesi.
 *
 * KVKK (kırmızı çizgi #4): telefon numarası veya müşteri adı BURAYA YAZILMAZ.
 * Yalnız gecikme, eşleşip eşleşmediği, ekranın kilitli olup olmadığı ve hangi yolun
 * kullanıldığı tutulur. `matched` alanı bile kişiyi işaret etmez, yalnız rehberde
 * var/yok bilgisidir.
 *
 * `locked` alanı sonradan eklendi ve zorunludur: kilit ekranındayken overlay çiziliyor,
 * `onDraw` tetikleniyor ve ölçüm "başarılı" kaydediliyordu — ama kart keyguard'ın altında
 * kaldığı için kullanıcı hiçbir şey görmüyordu. Metrik başarısızlığı başarı sayıyordu.
 */
object LatencyLog {

    private const val PREFS = "sipario_phase0"
    private const val KEY = "measurements"
    private const val MAX_ENTRIES = 100

    fun record(
        context: Context,
        ms: Long,
        matched: Boolean,
        simulated: Boolean,
        path: String,
        locked: Boolean,
        direction: String = "in",
    ) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val list = JSONArray(prefs.getString(KEY, "[]"))

        val entry = JSONObject().apply {
            put("ms", ms)
            put("matched", matched)
            put("simulated", simulated)
            put("path", path)
            put("locked", locked)
            put("dir", direction)
            put("at", System.currentTimeMillis())
        }

        val trimmed = JSONArray()
        val start = maxOf(0, list.length() - (MAX_ENTRIES - 1))
        for (i in start until list.length()) trimmed.put(list.get(i))
        trimmed.put(entry)

        prefs.edit().putString(KEY, trimmed.toString()).apply()
    }

    fun readAllJson(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]") ?: "[]"

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).apply()
    }
}
