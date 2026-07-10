package com.sipario.app

import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log

/**
 * Kırmızı çizgi #6: arayan tanıma YALNIZ burada yapılır.
 *
 * `CallScreeningService` çağrı numarasını `Call.Details.getHandle()` üzerinden verir ve
 * bunun için READ_PHONE_STATE / READ_CALL_LOG / PROCESS_OUTGOING_CALLS izinlerinin
 * HİÇBİRİ gerekmez. Bu izinler Play'in kısıtlı izin beyan formunu tetikler; manifest'e
 * hiçbiri girmeyecek (scripts/check_permissions.sh bunu birleştirilmiş manifest üzerinde denetler).
 *
 * Servis, rol verilmişse çağrı geldiği anda sistem tarafından ayağa kaldırılır — uygulama
 * süreci ölü olsa bile. Bu yüzden buradaki yol Flutter'a hiç dokunmaz.
 */
class SiparioCallScreeningService : CallScreeningService() {

    private val tag = "SiparioScreening"

    override fun onCreate() {
        super.onCreate()
        Log.i(tag, "servis olusturuldu (sistem bagladi)")
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val t0 = System.nanoTime()

        // KVKK: numara loglanmaz, yalnız var/yok bilgisi.
        Log.i(tag, "onScreenCall: yon=${callDetails.callDirection}, handleVar=${callDetails.handle != null}")

        // Çağrıyı hiçbir şekilde engellemiyoruz; yalnız tanıyoruz.
        // respondToCall ÖNCE çağrılır: sistem yanıtı beklerken çağrıyı tutar ve
        // yavaş kalırsak zil gecikir. Tanıma işi yanıttan sonra yapılır.
        respondToCall(callDetails, CallResponse.Builder().build())

        // Giden aramada da kart gösterilir: bayi müşteriyi geri aradığında da borcu görmek ister.
        val direction = when (callDetails.callDirection) {
            Call.Details.DIRECTION_INCOMING -> "in"
            Call.Details.DIRECTION_OUTGOING -> "out"
            else -> {
                Log.i(tag, "yon bilinmiyor, atlaniyor")
                return
            }
        }

        val phone = callDetails.handle?.schemeSpecificPart
        if (phone.isNullOrBlank()) {
            // Gizli numara. Bilgi kartı gösterilmez; sessizce geçilir.
            Log.i(tag, "gizli numara, atlaniyor")
            return
        }

        val customer = CustomerLookup.find(this, phone)
        Log.i(tag, "rehber sorgusu bitti, eslesme=${customer != null}, yon=$direction")
        CallerOverlay.show(this, customer, phone, t0, simulated = false, direction = direction)

        // Yanıt ve kapanış anlarında kartı yeniden göstermek için (MIUI'de zil sırasında
        // çağrı ekranının altında kalıyoruz; asıl gösterim yanıt anında olur).
        CallSessionWatcher.start(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(tag, "servis kapatildi")
    }
}
