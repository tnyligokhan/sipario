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
 * Biçim: satır başına `<iso8601-utc>|<yon>|<numara>|<anahtar>`; `yon` ∈ incoming | outgoing |
 * missed (Dart tarafındaki `CallDirection.wire` ile aynı sözcükler).
 *
 * DÖRDÜNCÜ ALAN — ÇAĞRI ANAHTARI (2026-07-27): bir çağrı kuyruğa İKİ KEZ yazılabilir. Zil
 * anında "incoming" yazılır (süreç konuşma ortasında ölse bile kayıt durur), çağrı
 * yanıtlanmadan biterse aynı anahtarla "missed" yazılır. Dart tarafı anahtardan deterministik
 * bir `call_logs.id` türetir; ikinci satır yeni bir çağrı değil, aynı çağrının güncellenmiş
 * hâlidir. Alan OPSİYONELDİR: anahtarsız eski satırlar (sürüm yükseltmesinde kuyrukta kalmış
 * olabilir) bugünkü gibi tek seferlik kayıt olarak işlenir.
 */
object CallJournal {

    private const val TAG = "SiparioJournal"

    /** Dart tarafındaki `kCagriKuyrukDosyasi` aynası. */
    const val DOSYA = "sipario_cagri_kuyrugu.txt"

    /** Kuyruk bu boyutu aşarsa baştan kırpılır — uygulama aylarca açılmasa da dosya şişmesin. */
    private const val MAX_BAYT = 64 * 1024L
    private const val TUTULAN_SATIR = 200

    /**
     * Çağrıyı kuyruğa ekler.
     *
     * [zamanIso] ÇAĞRININ BAŞLADIĞI andır, satırın yazıldığı an değil: cevapsız güncellemesi
     * çağrı bittiğinde yazılır ve aynı çağrı günlükte 40 saniye ileri kaymamalıdır.
     */
    fun kaydet(context: Context, phone: String, yon: CagriYonu, anahtar: String, zamanIso: String) {
        val dosya = kuyrukDosyasi(context) ?: return
        runCatching {
            kirpGerekirse(dosya)
            val haneler = phone.filter(Char::isDigit)
            dosya.appendText("$zamanIso|${yon.kuyrukKodu}|$haneler|$anahtar\n")
        }.onFailure {
            // Günlük bir kolaylıktır; yazılamaması çağrı kartını etkilemez.
            Log.w(TAG, "cagri kuyruga yazilamadi: ${it.javaClass.simpleName}")
        }
    }

    /**
     * Bir çağrı oturumunun anahtarı. Numara + başlangıç anı: aynı numaradan gelen iki ayrı
     * çağrı ayrı kayıt olur, aynı çağrının iki satırı ise aynı kayda düşer.
     *
     * KVKK: anahtar kuyruk dosyasında durur (numara zaten aynı satırda), LOGA YAZILMAZ.
     */
    fun yeniAnahtar(phone: String): String =
        "${CustomerLookup.last10(phone)}-${System.currentTimeMillis()}"

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
    fun simdiIso(): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            .apply { timeZone = TimeZone.getTimeZone("UTC") }
            .format(Date())
}
