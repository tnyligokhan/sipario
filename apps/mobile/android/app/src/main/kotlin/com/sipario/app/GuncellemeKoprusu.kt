package com.sipario.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * UYGULAMA İÇİ GÜNCELLEMENİN NATIVE UCU — `sipario/guncelleme` kanalı.
 *
 * GEÇİCİ: yalnız `saha` kanalı için. Dart tarafı `magaza` derlemesinde bu köprüyü HİÇ
 * çağırmaz (`guncellemeKapaliMi`), üstelik `REQUEST_INSTALL_PACKAGES` izni ve FileProvider
 * beyanı da yalnız `src/saha/AndroidManifest.xml` katmanındadır. Mağaza sürümünde bu sınıf
 * derlenir ama ölü kalır — çağrılsa bile izin/provider olmadığı için sessizce başarısız olur.
 *
 * DÖRT METOT:
 *  • `abiler`            — `Build.SUPPORTED_ABIS`; Dart'ta güvenilir ABI bilgisi YOKTUR ve
 *                          indirilecek APK'yı (arm64 mi evrensel mi) bu belirler.
 *  • `onbellekYolu`      — FileProvider'ın paylaştığı TEK dizin. Dart başka yere yazarsa
 *                          kurucu dosyayı göremez ve kurulum sessizce ölür.
 *  • `kurulumIzniVar`    — Android 8+ "bilinmeyen kaynak" izni, uygulama başına verilir.
 *  • `kurulumIzniIste`   — o iznin ayar ekranını açar (paket adıyla doğrudan).
 *  • `kur`               — indirilen APK'yı sistemin kurulum ekranına devreder.
 */
object GuncellemeKoprusu {

    private const val TAG = "SiparioGuncelleme"
    const val KANAL = "sipario/guncelleme"

    /** FileProvider yetkisi — `src/saha/AndroidManifest.xml` ile birebir aynı olmalı. */
    private const val SAGLAYICI_EKI = ".guncelleme"

    /** Dart'ın APK'yı yazdığı dizin; `saha_guncelleme_yollari.xml` ile birebir aynı. */
    private const val ALT_DIZIN = "guncelleme"

    fun isle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "abiler" -> result.success(Build.SUPPORTED_ABIS?.toList() ?: emptyList<String>())

            "onbellekYolu" -> result.success(File(context.cacheDir, ALT_DIZIN).absolutePath)

            "kurulumIzniVar" -> result.success(kurulumIzniVar(context))

            "kurulumIzniIste" -> {
                kurulumIzniIste(context)
                result.success(null)
            }

            "kur" -> {
                val yol = call.argument<String>("yol")
                result.success(kur(context, yol))
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Android 8+ "bilinmeyen kaynaklardan kurulum" izni UYGULAMA BAŞINA verilir; eski
     * sürümlerdeki cihaz geneli ayarın yerini aldı. minSdk 29 olduğu için sürüm dalı yok.
     */
    private fun kurulumIzniVar(context: Context): Boolean = try {
        context.packageManager.canRequestPackageInstalls()
    } catch (e: Exception) {
        Log.w(TAG, "kurulum izni okunamadi: ${e.javaClass.simpleName}")
        false
    }

    /**
     * İzin ekranını AÇAR ama izni VEREMEZ — kullanıcı anahtarı kendisi çevirir. Dönüşte Dart
     * tarafı izni yeniden sorar; hâlâ yoksa güncellemeden sessizce vazgeçilir.
     *
     * Paket adıyla doğrudan gidilir (`package:` verisi): genel ayar listesinde bayiyi
     * uygulamayı aratmak, kurulum sürtünmesi demektir (BRIEF korku #3).
     */
    private fun kurulumIzniIste(context: Context) {
        runCatching {
            context.startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                    .setData(Uri.parse("package:${context.packageName}"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }.onFailure { Log.w(TAG, "izin ekrani acilamadi: ${it.javaClass.simpleName}") }
    }

    /**
     * İndirilen APK'yı sistemin kurulum ekranına verir.
     *
     * `content://` ZORUNLU: Android 7'den beri `file://` paylaşmak `FileUriExposedException`
     * atar. URI'yi FileProvider üretir ve okuma izni niyetle birlikte geçici olarak verilir.
     *
     * Dosya yoksa/başka dizindeyse ya da (magaza derlemesinde) provider beyan edilmemişse
     * `false` döner — çökmez, Dart tarafı durumu `hata`ya çeker.
     */
    private fun kur(context: Context, yol: String?): Boolean {
        val dosya = yol?.let(::File)
        if (dosya == null || !dosya.exists()) {
            Log.w(TAG, "kurulacak dosya yok")
            return false
        }
        return try {
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}$SAGLAYICI_EKI",
                dosya,
            )
            context.startActivity(
                Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, "application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (e: Exception) {
            // En olası sebep: `magaza` derlemesinde provider beyanı yok (bilinçli).
            Log.w(TAG, "kurulum baslatilamadi: ${e.javaClass.simpleName}")
            false
        }
    }
}
