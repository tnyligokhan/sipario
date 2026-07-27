plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
        versionCode = flutter.versionCode
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
}

flutter {
    source = "../.."
}
