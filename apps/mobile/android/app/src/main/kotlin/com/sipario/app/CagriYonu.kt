package com.sipario.app

import android.media.AudioManager
import android.telecom.Call

/**
 * Çağrının YÖNÜ — kartın başlığından çağrı günlüğüne kadar TEK kaynak.
 *
 * NEDEN AYRI TİP (2026-07-27 saha bulgusu): yön `onScreenCall`'da doğru okunuyordu ama
 * yolun geri kalanında düz bir `"in"/"out"` dizesiydi ve hiçbir yere ULAŞMIYORDU —
 * kartın üst şeridi "GELEN ÇAĞRI"yı sabit yazıyordu, yeniden gösterimler yönü `"in"`e
 * çiviliyordu, cevapsız çağrı diye bir kavram hiç yoktu. Bayi kendi yaptığı aramada
 * "GELEN ÇAĞRI" görüyordu. Yön artık tip güvenli tek bir enum ve üç kodu da kendisi taşıyor.
 */
enum class CagriYonu(
    /** Çağrı kuyruğu + `call_logs.direction` sözleşmesi — Dart `CallDirection.wire` aynası. */
    val kuyrukKodu: String,
    /**
     * Faz 0 ölçüm defterindeki `dir` alanı. Cevapsız çağrı da GELEN bir çağrıdır: go/no-go
     * sayımı "in" olanlar üzerinden yapılır (DECISIONS), cevapsız kalan çağrı o sayımdan
     * düşmemelidir — bayi telefonu açamadıysa bile kartın çıkmış olması gerekir.
     */
    val olcumKodu: String,
    /** Kartın üst şeridindeki etiket (CSS `.cagri-live b`). */
    val etiket: String,
    /** Bildirimin alt satırı — kart çağrı ekranının altında kalırsa görünen tek yüzey. */
    val kisaEtiket: String,
) {
    GELEN("incoming", "in", "GELEN ÇAĞRI", "Gelen çağrı"),
    GIDEN("outgoing", "out", "GİDEN ÇAĞRI", "Giden çağrı"),
    CEVAPSIZ("missed", "in", "CEVAPSIZ ÇAĞRI", "Cevapsız çağrı");

    companion object {
        /** Kuyruk/niyet kodundan geri çevirir; tanınmayan değer GELEN sayılır (Dart ile aynı kural). */
        fun kuyruktan(kod: String?): CagriYonu =
            entries.firstOrNull { it.kuyrukKodu == kod } ?: GELEN
    }
}

/**
 * Yönü belirler. İZİN GEREKTİRMEZ (kırmızı çizgi #6): `Call.Details.callDirection` taramanın
 * kendi verisidir, `AudioManager.mode` okumak da izinsizdir.
 *
 * Telecom'un söylediğine öncelik verilir — AOSP `ParcelableCallUtils.toParcelableCallForScreening`
 * yönü Android 10'dan beri `call.isIncoming()` üzerinden DOĞRU dolduruyor. Yalnız
 * `DIRECTION_UNKNOWN` geldiğinde ses moduna düşülür:
 *
 *  - GELEN çağrı taranırken telefon HENÜZ çalmamıştır (sistem `respondToCall`'u bekler),
 *    ses oturumu açık olamaz.
 *  - GİDEN çağrıda numara çevrilmiştir; ses oturumu `MODE_IN_CALL`/`MODE_IN_COMMUNICATION`tadır.
 *
 * ESKİ DAVRANIŞ (hata): `DIRECTION_UNKNOWN` gelen çağrıda `onScreenCall` erken dönüyor ve kart
 * HİÇ ÇİZİLMİYORDU. Yönü bilememek, arayanı hiç göstermemek için gerekçe değildir.
 *
 * [sesModu] tembel geçilir: Telecom yönü zaten söylediyse `AudioManager` hiç istenmez —
 * çağrı anındaki bütçe 1 saniyedir ve her sistem servisi çağrısı sayılır.
 */
fun cagriYonuBelirle(telecomYonu: Int, sesModu: () -> Int): CagriYonu = when (telecomYonu) {
    Call.Details.DIRECTION_OUTGOING -> CagriYonu.GIDEN
    Call.Details.DIRECTION_INCOMING -> CagriYonu.GELEN
    else -> if (sesOturumuAcik(sesModu())) CagriYonu.GIDEN else CagriYonu.GELEN
}

/** Hatta açık bir ses oturumu var mı (çalıyor DEĞİL, konuşuluyor/çevriliyor). */
fun sesOturumuAcik(sesModu: Int): Boolean =
    sesModu == AudioManager.MODE_IN_CALL || sesModu == AudioManager.MODE_IN_COMMUNICATION

/**
 * Tek bir çağrı oturumunun kimliği. [CallSessionWatcher] çağrı bittiğinde günlüğü GÜNCELLER
 * (yeni satır değil) — bunun için hangi çağrıyı ve hangi anı güncelleyeceğini bilmek zorunda.
 *
 * [anahtar] çağrı kuyruğuna yazılır; Dart tarafı ondan deterministik bir `call_logs.id`
 * türetir, böylece "gelen" satırı ile onu cevapsıza çeviren satır AYNI kaydı gösterir.
 */
data class CagriOturumu(
    val numara: String,
    val anahtar: String,
    val baslangicIso: String,
    val yon: CagriYonu,
)
