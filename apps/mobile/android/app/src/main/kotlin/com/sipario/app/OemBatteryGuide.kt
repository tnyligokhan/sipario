package com.sipario.app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings

/**
 * Korku #1'in ikinci yarısı: `CallScreeningService`'i sistem başlatır, ama bazı OEM
 * kabukları (özellikle MIUI/HyperOS) uygulamanın arka planda ayağa kalkmasını
 * "otomatik başlatma" listesinden çıkararak engeller. Rol verilmiş olsa bile kart çıkmaz.
 *
 * Buradaki adımlar kurulum sihirbazının gövdesidir; kurulum→ilk tanıma süresi (korku #3)
 * büyük ölçüde bu ekranda geçen zamandır.
 */
object OemBatteryGuide {

    fun stepsFor(manufacturer: String): List<String> = when (manufacturer.lowercase()) {
        // MIUI/HyperOS arayan tanımayı üç ayrı yerden öldürebilir: otomatik başlatma kapalıysa
        // servis hiç uyanmaz, pil kısıtlaması Doze'da süreci keser, "kilit ekranında göster"
        // kapalıysa showWhenLocked Activity açılmaz. Üçü de gerekli.
        "xiaomi", "redmi", "poco" -> listOf(
            "Ayarlar → Uygulamalar → Sipario → Otomatik başlatma: AÇ",
            "Ayarlar → Uygulamalar → Sipario → Pil tasarrufu: Kısıtlama yok",
            "Ayarlar → Uygulamalar → Sipario → Diğer izinler → Arka planda açılır pencere: AÇ",
            "Ayarlar → Uygulamalar → Sipario → Diğer izinler → Kilit ekranında göster: AÇ",
            "Son uygulamalar ekranında Sipario'yu aşağı çekip kilit simgesine dokunun",
        )

        "samsung" -> listOf(
            "Ayarlar → Pil → Arka plan kullanım sınırları → Uyuyan uygulamalar: Sipario listede OLMASIN",
            "Ayarlar → Uygulamalar → Sipario → Pil → Kısıtlanmamış",
        )

        "oppo", "realme", "oneplus" -> listOf(
            "Ayarlar → Pil → Yüksek arka plan pil kullanımı: Sipario için izin ver",
            "Ayarlar → Uygulamalar → Sipario → Otomatik başlatmaya izin ver",
        )

        "vivo" -> listOf(
            "Ayarlar → Pil → Yüksek arka plan güç tüketimi: Sipario'ya izin ver",
            "Ayarlar → Diğer ayarlar → Uygulama yöneticisi → Sipario → Otomatik başlat: AÇ",
        )

        "huawei", "honor" -> listOf(
            "Ayarlar → Pil → Uygulama başlatma → Sipario → Elle yönet: üç seçeneği de AÇ",
        )

        else -> listOf(
            "Ayarlar → Uygulamalar → Sipario → Pil → Kısıtlanmamış",
        )
    }

    /**
     * OEM'e özel ekranı en iyi çabayla açar. Bu Activity'ler belgelenmemiştir ve
     * sürümden sürüme kaybolur; bulunamazsa genel pil ayarlarına düşeriz.
     *
     * REQUEST_IGNORE_BATTERY_OPTIMIZATIONS izni ALINMAZ — Play'in kısıtlı izinlerindendir.
     * Onun yerine izin gerektirmeyen ayar listesi ekranı açılır.
     */
    /**
     * MIUI'nin "Diğer izinler" ekranını açar — "Kilit ekranında görüntüle" ve "Arka planda
     * çalışırken yeni pencereler açın" burada yaşar. Cihazda doğrulandı: bunlar kapalıyken
     * sistem tam ekran niyeti sessizce yutuyor ve bu izinler adb/appops ile VERİLEMİYOR;
     * MIUI kendi izin veritabanından denetliyor. Tek yol kullanıcının eliyle açması.
     */
    fun openOtherPermissions(context: Context) {
        if (android.os.Build.MANUFACTURER.lowercase() in setOf("xiaomi", "redmi", "poco")) {
            val miuiPermissions = Intent("miui.intent.action.APP_PERM_EDITOR")
                .setClassName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.AppPermissionsEditorActivity"
                )
                .putExtra("extra_pkgname", context.packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (miuiPermissions.resolveActivity(context.packageManager) != null) {
                runCatching { context.startActivity(miuiPermissions) }.onSuccess { return }
            }
        }
        // MIUI değilse veya ekran bulunamadıysa uygulama ayrıntıları sayfası.
        val details = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            android.net.Uri.parse("package:${context.packageName}")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { context.startActivity(details) }
    }

    fun openBestSettingsScreen(context: Context) {
        val candidates = when (android.os.Build.MANUFACTURER.lowercase()) {
            "xiaomi", "redmi", "poco" -> listOf(
                ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
            )

            "oppo", "realme" -> listOf(
                ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                )
            )

            "vivo" -> listOf(
                ComponentName(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                )
            )

            "huawei", "honor" -> listOf(
                ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                )
            )

            else -> emptyList()
        }

        for (component in candidates) {
            val intent = Intent().setComponent(component).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(context.packageManager) != null) {
                runCatching { context.startActivity(intent) }.onSuccess { return }
            }
        }

        val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { context.startActivity(fallback) }.onFailure {
            context.startActivity(
                Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }
}
