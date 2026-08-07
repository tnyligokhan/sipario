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

    /**
     * OEM'in "otomatik başlatma" (autostart / background start) ekranının bileşeni — yoksa null.
     *
     * SAHA HATASI (2026-07-29): bu bileşenler eskiden `openBestSettingsScreen` içindeydi ve
     * sihirbazın **"Pil optimizasyonu muafiyeti"** adımı onları açıyordu. Yani ekranda pil yazıyor,
     * açılan ekran OTOMATİK BAŞLATMA oluyordu. İki zarar birden: (1) kullanıcı adı verilen ayarı
     * bulamayıp "uygulama bozuk" diyor, (2) pil kısıtlaması HİÇ kaldırılmıyor — oysa MIUI'de
     * arayan tanımayı öldüren iki ayrı mekanizma var ve ikisi de gerekli.
     *
     * İkisi artık AYRI metottur; sihirbaz aynı adımda iki düğme gösterir.
     */
    fun autostartComponent(context: Context): ComponentName? {
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

        return candidates.firstOrNull { component ->
            Intent().setComponent(component).resolveActivity(context.packageManager) != null
        }
    }

    /** Cihazda ayrı bir "otomatik başlatma" ekranı var mı? Sihirbaz düğmeyi buna göre çizer. */
    fun hasAutostartSettings(context: Context): Boolean = autostartComponent(context) != null

    /**
     * OEM'in otomatik başlatma listesini açar. Bulunamazsa uygulama ayrıntılarına düşer —
     * boş bir dokunuş bırakmaktansa kullanıcıyı doğru uygulamanın sayfasına götürmek iyidir.
     */
    fun openAutostartSettings(context: Context) {
        val component = autostartComponent(context)
        if (component != null) {
            val intent = Intent().setComponent(component).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            runCatching { context.startActivity(intent) }.onSuccess { return }
        }
        openAppDetails(context)
    }

    /**
     * PİL ayarını açar — adı ne diyorsa onu (2026-07-29 düzeltmesi).
     *
     * MIUI'de uygulama başına pil kısıtlaması `HiddenAppsConfigActivity`de yaşar ve paket adını
     * ekstra olarak alır; oraya gidebilirsek kullanıcı listede uygulama ARAMAZ. Bulunamazsa
     * Android'in standart "pil optimizasyonu" listesine, o da yoksa uygulama ayrıntılarına düşülür.
     *
     * REQUEST_IGNORE_BATTERY_OPTIMIZATIONS izni İSTENMEZ — Play'in kısıtlı izinlerindendir
     * (kırmızı çizgi #6 ile aynı red riski); yalnız izin gerektirmeyen AYAR EKRANI açılır.
     */
    fun openBatterySettings(context: Context) {
        if (android.os.Build.MANUFACTURER.lowercase() in setOf("xiaomi", "redmi", "poco")) {
            val miuiBattery = Intent()
                .setComponent(
                    ComponentName(
                        "com.miui.powerkeeper",
                        "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"
                    )
                )
                .putExtra("package_name", context.packageName)
                .putExtra("package_label", "Sipario")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (miuiBattery.resolveActivity(context.packageManager) != null) {
                runCatching { context.startActivity(miuiBattery) }.onSuccess { return }
            }
        }

        val standart = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (standart.resolveActivity(context.packageManager) != null) {
            runCatching { context.startActivity(standart) }.onSuccess { return }
        }
        openAppDetails(context)
    }

    /** Son çare: uygulamanın kendi ayar sayfası. Her Android'de vardır. */
    private fun openAppDetails(context: Context) {
        val details = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            android.net.Uri.parse("package:${context.packageName}")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { context.startActivity(details) }.onFailure {
            runCatching {
                context.startActivity(
                    Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
        }
    }
}
