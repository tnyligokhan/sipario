package com.sipario.app

import android.content.Context
import android.media.AudioManager
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
        // Yön ARTIK ATLAMA SEBEBİ DEĞİL: `DIRECTION_UNKNOWN` geldiğinde eskiden buradan erken
        // dönülüyor ve kart hiç çizilmiyordu. Bilinmeyen yönde ses moduna bakılır (izinsiz).
        val yon = cagriYonuBelirle(callDetails.callDirection) {
            (getSystemService(Context.AUDIO_SERVICE) as AudioManager).mode
        }

        val phone = callDetails.handle?.schemeSpecificPart
        if (phone.isNullOrBlank()) {
            // Gizli numara. Bilgi kartı gösterilmez; sessizce geçilir.
            Log.i(tag, "gizli numara, atlaniyor")
            return
        }

        // MUAF NUMARA — kart hiç çizilmez (s-uygulama.jsx kuralı). Kontrol müşteri sorgusundan
        // ÖNCE: muaf bir numarada rehber sorgusu da gereksiz iştir, 1 saniyelik bütçe her
        // okumayı sayıyor. Tablo yoksa `muafMi` false döner ve kart normal çıkar.
        if (CallerCard.muafMi(this, phone)) {
            Log.i(tag, "muaf numara, kart gosterilmiyor")
            return
        }

        // Çağrı günlüğü ("Son Aramalar") kuyruğuna düş; Dart tarafı uygulama açılınca boşaltır.
        // Kayıt ZİL ANINDA atılır (çağrının sonunu beklemeyiz): süreç konuşma ortasında
        // öldürülse bile bayi kimin aradığını görebilmeli. Cevapsıza dönerse aynı anahtarla
        // güncellenir — bkz. [CallSessionWatcher].
        val oturum = CagriOturumu(
            numara = phone,
            anahtar = CallJournal.yeniAnahtar(phone),
            baslangicIso = CallJournal.simdiIso(),
            yon = yon,
        )
        CallJournal.kaydet(this, oturum.numara, oturum.yon, oturum.anahtar, oturum.baslangicIso)

        val customer = CustomerLookup.find(this, phone)
        Log.i(tag, "rehber sorgusu bitti, eslesme=${customer != null}, yon=${yon.kuyrukKodu}")
        CallerOverlay.show(this, customer, phone, t0, simulated = false, yon = yon)

        // Yanıt ve kapanış anlarında kartı yeniden göstermek için (MIUI'de zil sırasında
        // çağrı ekranının altında kalıyoruz; asıl gösterim yanıt anında olur).
        CallSessionWatcher.start(this, oturum)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(tag, "servis kapatildi")
    }
}
