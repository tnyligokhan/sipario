package com.sipario.app

import android.Manifest
import android.app.NotificationManager
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
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
    private val roleRequestCode = 4711
    private val contactsRequestCode = 4712
    private val notificationsRequestCode = 4713

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

                    "openBatterySettings" -> {
                        OemBatteryGuide.openBestSettingsScreen(this)
                        result.success(null)
                    }

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
