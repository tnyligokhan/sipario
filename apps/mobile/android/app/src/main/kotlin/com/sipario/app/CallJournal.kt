package com.sipario.app

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Çağrı günlüğünün NATIVE ucu — "Son Aramalar" listesinin cihazdaki kaynağı.
 *
 * NEDEN DOĞRUDAN `call_logs` TABLOSUNA YAZMIYORUZ: yazma yolu daima repo → outbox'tır
 * (SÖZLEŞME, kırmızı çizgi). Native taraf tabloya elle satır atsa outbox kaydı, LWW damgası,
 * kimlik biçimi ve senkron sözleşmesi ikinci bir yerde daha kopyalanmış olurdu — ilk şema
 * değişiminde sessizce bozulacak bir kopya. Onun yerine çağrı, düz metin bir kuyruğa
 * eklenir; uygulama açıldığında Dart tarafı ([cagri_kuyrugu.dart]) kuyruğu boşaltıp
 * `CallLogRepository.log()` ile normal yoldan yazar.
 *
 * Yan fayda: yazma işi tek `appendText` çağrısı — çağrı anındaki 1 saniyelik bütçeye
 * SQLite açmaktan çok daha ucuz.
 *
 * Biçim: satır başına `<iso8601-utc>|<yon>|<numara>`; `yon` ∈ incoming | outgoing | missed
 * (Dart tarafındaki `CallDirection.wire` ile aynı sözcükler).
 */
object CallJournal {

    private const val TAG = "SiparioJournal"

    /** Dart tarafındaki `kCagriKuyrukDosyasi` aynası. */
    const val DOSYA = "sipario_cagri_kuyrugu.txt"

    /** Kuyruk bu boyutu aşarsa baştan kırpılır — uygulama aylarca açılmasa da dosya şişmesin. */
    private const val MAX_BAYT = 64 * 1024L
    private const val TUTULAN_SATIR = 200

    fun kaydet(context: Context, phone: String, yon: String) {
        val dosya = kuyrukDosyasi(context) ?: return
        runCatching {
            kirpGerekirse(dosya)
            dosya.appendText("${simdiIso()}|$yon|${phone.filter(Char::isDigit)}\n")
        }.onFailure {
            // Günlük bir kolaylıktır; yazılamaması çağrı kartını etkilemez.
            Log.w(TAG, "cagri kuyruga yazilamadi: ${it.javaClass.simpleName}")
        }
    }

    private fun kuyrukDosyasi(context: Context): File? {
        val dizin = context.getDatabasePath(CustomerLookup.DB_NAME).parentFile ?: return null
        if (!dizin.exists() && !dizin.mkdirs()) return null
        return File(dizin, DOSYA)
    }

    private fun kirpGerekirse(dosya: File) {
        if (!dosya.exists() || dosya.length() <= MAX_BAYT) return
        val satirlar = dosya.readLines()
        dosya.writeText(satirlar.takeLast(TUTULAN_SATIR).joinToString("\n", postfix = "\n"))
    }

    /**
     * ISO8601 UTC. `occurredAt` sözleşmesi metin ISO8601'dir; cihaz saati kaysa bile Dart
     * tarafı kuyruğu boşaltırken sunucu saat farkını uygulayamaz (çağrı geçmişte oldu),
     * bu yüzden çağrı ANINDAKİ cihaz saati yazılır.
     */
    private fun simdiIso(): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            .apply { timeZone = TimeZone.getTimeZone("UTC") }
            .format(Date())
}
