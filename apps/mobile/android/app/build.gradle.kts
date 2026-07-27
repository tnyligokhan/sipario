import java.io.ByteArrayOutputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Depodaki commit sayısı — yapı numarasının (versionCode) tek kaynağı.
 *
 * Başarısızlığın HER türü null döner ve çağıran yedek değere düşer: git kurulu değil, depo
 * dışında derleniyor, sığ klon, komut hata verdi. Bu fonksiyon derlemeyi ASLA kırmamalı —
 * sürüm numarası uğruna APK üretilememesi, elle yönetilen sürümden daha kötüdür.
 */
fun gitCommitSayisi(): Int? = try {
    val cikti = ByteArrayOutputStream()
    val sonuc = exec {
        commandLine("git", "rev-list", "--count", "HEAD")
        workingDir = rootProject.projectDir
        standardOutput = cikti
        errorOutput = ByteArrayOutputStream()
        isIgnoreExitValue = true
    }
    if (sonuc.exitValue == 0) cikti.toString().trim().toIntOrNull() else null
} catch (_: Exception) {
    null
}

android {
    namespace = "com.sipario.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ÇEKİRDEK KÜTÜPHANE ŞEKERSİZLEŞTİRME (core library desugaring) — ZORUNLU.
        //
        // `flutter_local_notifications` 10+ zamanlanmış bildirimleri eski Android sürümlerinde
        // de çalıştırmak için `java.time` API'lerini kullanıyor ve bunu desugaring'e dayandırıyor.
        // Açık olmadan `:app:checkReleaseAarMetadata` şu hatayla DÜŞER:
        //   "Dependency ':flutter_local_notifications' requires core library desugaring"
        //
        // BU KAPI TESTLERDE GÖRÜNMEZ: 622 Dart testi yeşilken ve `flutter analyze` temizken
        // release APK derlenmiyordu (2026-07-27). Bildirim bağlaması bittiğinde "Faz 1 bitti"
        // sanmamızın tek engeli lead'in her tur APK derlemesi oldu.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.sipario.app"
        // CallScreeningService Android 10 (API 29) ile geldi. Arayan tanıma bu ürünün
        // varlık sebebi olduğu için altındaki sürümleri desteklemiyoruz.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // YAPI NUMARASI GİT COMMIT SAYISINDAN TÜRER — elle yönetilmez (kullanıcı kararı 2026-07-27:
        // "artık versiyon ile uğraşmak istemiyorum"). Her commit'te kendiliğinden artar, monoton
        // ilerler, atlamaz. Elle yönetilen bir sayı er geç unutulur: 2026-07-27'de dört ayrı APK
        // derlendi ve DÖRDÜ DE `1.0.0+1` idi — sahadaki bayi hangi APK'yı test ettiğini
        // söyleyemiyordu.
        //
        // Git yoksa/başarısızsa pubspec'teki yedek değere düşülür — derleme ASLA bu yüzden kırılmaz
        // (depo dışı derleme, sığ klon, git kurulu olmayan CI makinesi hepsi olağan durumlardır).
        versionCode = gitCommitSayisi() ?: flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Faz 6'da kendi imza anahtarımız gelecek.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Sürüm paketin kendi dokümanından ve örnek uygulamasından: 2.1.4. Rastgele seçilmedi —
    // desugaring kütüphanesi AGP ile eşleşmek zorunda ve paket AGP 8.11.1'i asgari sayıyor
    // (bizdeki sürüm de tam olarak 8.11.1, `settings.gradle.kts`).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // SAVUNMA AMAÇLI — CİHAZDA DOĞRULANMADI.
    //
    // `flutter_local_notifications` README'si, desugaring açıldığında bazı Flutter
    // uygulamalarının Android 12L ve ÜSTÜNDE çöktüğünü bildiriyor (sorun Flutter'ın, paketin
    // değil) ve belgelenmiş çözüm bu iki kütüphane. Pilot cihazlarımız Android 14 ve 16, yani
    // tam risk aralığında.
    //
    // Neden şimdi ekliyoruz (lead kararı, risk asimetrisi): çökme AÇILIŞTA olur, yani "bir
    // özellik çalışmıyor" değil "ürün hiç açılmıyor" demektir; saha testi tamamen durur ve
    // uzaktan teşhisi saatler alır. Eklemenin maliyeti ise iki satır ve birkaç yüz KB.
    // Kaybın büyüklüğü ile maliyetin büyüklüğü arasında mertebe farkı var.
    //
    // Sürümler paketin README'sindeki çözümün birebir aynısı (1.0.0). Cihazda çökme
    // gözlenmezse bu bağımlılıklar sessizce ölü kalır — zararı yok.
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
}

flutter {
    source = "../.."
}
