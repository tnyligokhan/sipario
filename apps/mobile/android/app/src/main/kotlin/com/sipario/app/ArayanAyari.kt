package com.sipario.app

import android.content.Context
import android.util.Log
import java.io.File

/**
 * Arayan tanıma AÇIK/KAPALI tercihi — Ayarlar'daki anahtarın native okuyucusu.
 *
 * Dart tarafı (`lib/screens/cagri/arayan_tanima_ayari.dart`) tercihi sqflite veritabanı
 * dizinindeki [DOSYA] düz metin dosyasına yazar; içerik `acik` | `kapali`. Desen tema
 * tercihiyle birebir aynıdır (bkz. [CallerTema.TEMA_DOSYA] gerekçesi): native taraf Dart'ın
 * deposunu okuyamaz ve kart çizilirken Flutter motoru hiç başlamaz — iki taraf ancak düz bir
 * dosyada buluşabilir.
 *
 * VARSAYILAN AÇIK: dosya yoksa ya da okunamazsa kart GÖSTERİLİR. Arayan tanıma ürünün
 * kendisidir; bir okuma arızası onu sessizce kapatmamalı ([CallerCard.muafMi]'nin "hata
 * durumunda göstermeyi seç" duruşunun aynısı). Kapatmak yalnız bayinin AÇIK iradesiyle olur.
 */
internal object ArayanAyari {

    private const val TAG = "SiparioArayanAyari"

    /** `kArayanDosyaAdi` aynası (lib/screens/cagri/arayan_tanima_ayari.dart). */
    const val DOSYA = "sipario_arayan.txt"

    fun acikMi(context: Context): Boolean {
        val dizin = context.getDatabasePath(CustomerLookup.DB_NAME).parentFile ?: return true
        val dosya = File(dizin, DOSYA)
        val deger = runCatching {
            if (!dosya.exists()) null else dosya.readText().trim().lowercase()
        }.getOrElse {
            // KVKK gereği içerik değil yalnız arıza türü loglanır (içerikte zaten koordinat
            // yok ama alışkanlık tek olsun).
            Log.w(TAG, "arayan tercihi okunamadi: ${it.javaClass.simpleName}")
            null
        } ?: return true

        // Tanınmayan içerik AÇIK sayılır: iki taraf ayrışırsa özellik susmak yerine çalışır.
        return deger != "kapali"
    }
}
