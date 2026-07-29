package com.sipario.app

import android.Manifest
import android.app.NotificationManager
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Faz 0 spike kabuğu: izin/rol akışı ve ölçüm sonuçlarını Flutter tarafına açar.
 * Arayan tanımanın kendisi bu sınıftan tamamen bağımsız çalışır — telefon
 * çaldığında bu Activity yaşamıyor olabilir, ki sahada çoğu zaman yaşamıyor.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "sipario/phase0"

    /** Çağrı kartı eylemleri için AYRI kanal — bkz. `lib/screens/cagri/cagri_eylem_kanali.dart`. */
    private val cagriChannelName = "sipario/cagri"

    private val roleRequestCode = 4711
    private val contactsRequestCode = 4712
    private val notificationsRequestCode = 4713

    private var cagriKanali: MethodChannel? = null

    /**
     * Native karttan gelen, henüz Flutter'a devredilmemiş eylem.
     *
     * Neden BEKLETİLİR: kart telefon çalarken çizilir ve o an Flutter motoru YAŞAMIYOR olur.
     * Düğmeye dokunulduğunda bu Activity başlar; niyet ekstraları burada tutulur ve Dart
     * hazır olduğunda `bekleyen` çağrısıyla çekilir. Çekildiği anda silinir — iki kez
     * tüketilmesi imkânsızdır.
     */
    private var bekleyen: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        eylemiAl(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        eylemiAl(intent)
        // Uygulama ZATEN önplandaysa (bayi çağrı sırasında uygulamayı kullanıyordu) hiçbir
        // yaşam döngüsü olayı doğmaz; Dart tarafına "bekleyen var" diye dürtmek şart.
        if (bekleyen != null) cagriKanali?.invokeMethod("eylem", null)
    }

    /**
     * Niyetteki eylemi alır. Ekstra HEMEN SİLİNİR: Activity yeniden kurulduğunda (dönme,
     * süreç öldürülüp geri gelme) sistem aynı niyeti tekrar verir ve eylem ikinci kez
     * tetiklenirdi — bayi bir kez dokundu, bir kez sipariş formu açılmalı.
     */
    private fun eylemiAl(i: Intent?) {
        val eylem = i?.getStringExtra(CallerCard.EXTRA_EYLEM) ?: return
        val numara = i.getStringExtra(CallerCard.EXTRA_NUMARA).orEmpty()
        // Numara KVKK gereği loglanmaz.
        bekleyen = mapOf("eylem" to eylem, "numara" to numara)
        i.removeExtra(CallerCard.EXTRA_EYLEM)
        i.removeExtra(CallerCard.EXTRA_NUMARA)
        // EYLEM SEÇİLDİ → HER İKİ YÜZEY DE KAPANIR (DECISIONS: "eylem ve kapatma tek işlemdir").
        // Artık iki yüzey var: karttan basıldıysa bildirim, bildirimden basıldıysa kart açık
        // kalırdı. Kapatmayı BURAYA koymak ikisini de kapatır, çünkü her iki düğme de aynı
        // köprüden ([CallerCard.eylemNiyeti]) buraya geliyor. `kapat` üç yüzeyi birden kaldırır
        // (overlay penceresi, kilit ekranı Activity'si, bildirim) ve idempotenttir — kart yolu
        // kendi tarafında da çağırıyor, ikinci çağrı zararsız.
        CallerOverlay.kapat(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        cagriKanali = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, cagriChannelName)
            .apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "bekleyen" -> {
                            result.success(bekleyen)
                            bekleyen = null
                        }

                        else -> result.notImplemented()
                    }
                }
            }

        // Uygulama içi güncelleme köprüsü (GEÇİCİ, yalnız `saha` kanalı — bkz. GuncellemeKoprusu).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GuncellemeKoprusu.KANAL)
            .setMethodCallHandler { call, result -> GuncellemeKoprusu.isle(this, call, result) }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(
                        mapOf(
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "hasScreeningRole" to hasScreeningRole(),
                            "canDrawOverlays" to Settings.canDrawOverlays(this),
                            "hasContactsPermission" to hasContactsPermission(),
                            "hasNotificationPermission" to hasNotificationPermission(),
                            "canUseFullScreenIntent" to canUseFullScreenIntent(),
                        )
                    )

                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationsRequestCode)
                        }
                        result.success(null)
                    }

                    "openOtherPermissions" -> {
                        OemBatteryGuide.openOtherPermissions(this)
                        result.success(null)
                    }

                    "requestContactsPermission" -> {
                        requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), contactsRequestCode)
                        result.success(null)
                    }

                    "requestFullScreenIntent" -> {
                        openFullScreenIntentSettings()
                        result.success(null)
                    }

                    "requestScreeningRole" -> {
                        requestScreeningRole()
                        result.success(null)
                    }

                    "requestOverlayPermission" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success(null)
                    }

                    "batteryGuide" -> result.success(OemBatteryGuide.stepsFor(Build.MANUFACTURER))

                    // ADI NE DİYORSA ONU AÇAR (2026-07-29 düzeltmesi): eskiden bu metot
                    // OEM'in OTOMATİK BAŞLATMA ekranını açıyordu, yani sihirbazda "pil"
                    // yazarken başka bir ayar geliyordu ve pil kısıtlaması hiç kaldırılmıyordu.
                    "openBatterySettings" -> {
                        OemBatteryGuide.openBatterySettings(this)
                        result.success(null)
                    }

                    "openAutostartSettings" -> {
                        OemBatteryGuide.openAutostartSettings(this)
                        result.success(null)
                    }

                    // Sihirbaz ikinci düğmeyi YALNIZ böyle bir ekranı olan cihazda çizer:
                    // Pixel'de "Otomatik başlatmayı aç" düğmesi hiçbir yere gitmezdi.
                    "hasAutostartSettings" ->
                        result.success(OemBatteryGuide.hasAutostartSettings(this))

                    "measurements" -> result.success(LatencyLog.readAllJson(this))

                    "clearMeasurements" -> {
                        LatencyLog.clear(this)
                        result.success(null)
                    }

                    // Gerçek çağrı beklemeden overlay yolunu uçtan uca denemek için.
                    // Ölçüm kaydına "simulated" olarak işaretlenir, go/no-go sayımına girmez.
                    "simulateCall" -> {
                        val phone = call.argument<String>("phone").orEmpty()
                        val t0 = System.nanoTime()
                        val customer = CustomerLookup.find(this, phone)
                        CallerOverlay.show(this, customer, phone, t0, simulated = true)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasScreeningRole(): Boolean {
        val rm = getSystemService(Context.ROLE_SERVICE) as RoleManager
        return rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
    }

    /**
     * Telecom, rehberde kayıtlı numaralarda tarama servisimizi yalnız bu izin verilmişse çağırır.
     * İzni rehberi okumak için değil, çağrıyı GÖREBİLMEK için istiyoruz.
     */
    private fun hasContactsPermission(): Boolean =
        checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED

    /** API 33+ çalışma zamanı izni; kilitli ekran yolunun taşıyıcısı bildirimdir. */
    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    /** Kilit ekranında kart gösterebilmenin şartı. Android 14 öncesinde her zaman verili. */
    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val nm = getSystemService(NotificationManager::class.java)
        return nm.canUseFullScreenIntent()
    }

    private fun openFullScreenIntentSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                Uri.parse("package:$packageName"),
            )
        )
    }

    private fun requestScreeningRole() {
        val rm = getSystemService(Context.ROLE_SERVICE) as RoleManager
        if (rm.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) && !rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
            startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING), roleRequestCode)
        }
    }
}
