import java.io.ByteArrayOutputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    /*
     * PUSH (Firebase). `google-services.json` ÜÇ TADI DA taşımak zorundadır: `saha` ve `magaza`
     * `com.sipario.app`, `deneme` ise `com.sipario.app.test` paket adıyla derlenir (aşağıdaki
     * `applicationIdSuffix`). Eksik paket adı derlemeyi "No matching client found for package
     * name" ile kırar — yani hata sessiz değildir, derleme kapısında yakalanır.
     */
    id("com.google.gms.google-services")
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

    /**
     * İKİ KANAL — aynı uygulama, iki dağıtım yolu.
     *
     * `saha`: pilot bayilere doğrudan APK ile gider ve UYGULAMA İÇİ GÜNCELLEME yapar.
     *         Kurulum izni ve FileProvider YALNIZ bu kanalın manifest katmanındadır
     *         (`src/saha/AndroidManifest.xml`) — ana manifest'e sızmaz.
     * `magaza`: Play Store yolu. Güncelleme kodu davranış olarak KAPALI (Dart tarafı
     *         `SIPARIO_KANAL` derleme sabitine bakar) ve `REQUEST_INSTALL_PACKAGES` izni
     *         APK'sında BULUNMAZ — `scripts/check_permissions.sh` bunu kırmızıya çevirir.
     *
     * applicationId İKİSİNDE DE AYNI ve bu pazarlıksız: farklı olsaydı `saha` sürümünün
     * güncellemesi kendi üstüne kurulamaz, iki ayrı uygulama olarak yan yana dururdu.
     * Bu yüzden `applicationIdSuffix` KULLANILMIYOR.
     */
    flavorDimensions += "kanal"
    productFlavors {
        create("saha") { dimension = "kanal" }
        create("magaza") { dimension = "kanal" }
        /**
         * DENEME KANALI (2026-08-09) — geliştirme ekibinin cihazına giden sürüm.
         *
         * `applicationIdSuffix` PAZARLIKSIZ: sonek olmasaydı deneme APK'sı saha APK'sının
         * ÜSTÜNE kurulurdu. Bir bayinin telefonuna yanlışlıkla deneme sürümü kurulması,
         * uygulamasının silinmesi ve GÖNDERİLMEMİŞ kayıtlarının kaybolması demekti. Sonekle
         * ikisi yan yana durur, ayrı verilerle çalışır, biri diğerini göremez.
         *
         * Flavor adı `test` DEĞİL: Android Gradle eklentisi `test`/`androidTest`/`main`
         * adlarını kendi kaynak kümeleri için ayırır ve o adla flavor derlemeyi kırar.
         * Release etiketi yine `test` — yalnız flavor adı Türkçeleşti.
         *
         * İMZA saha ile AYNI anahtardır (aşağıdaki `signingConfigs`). Bilinçli: kanal içi
         * güncelleme aynı imzayı şart koşar. Farklı applicationId taşıdıkları için aynı
         * anahtarla imzalanmaları iki uygulamayı birbirine karıştırmaz.
         */
        create("deneme") {
            dimension = "kanal"
            applicationIdSuffix = ".test"
        }
    }

    /**
     * SAHA İMZASI — CI sözleşmesi.
     *
     * CI şu ortam değişkenlerini verir: `SAHA_KEYSTORE_YOLU` · `SAHA_KEYSTORE_SIFRE` ·
     * `SAHA_ANAHTAR_SIFRE` (alias sabit: `saha`). Değişken TANIMSIZSA imza yapılandırması hiç
     * kurulmaz ve release bugünkü gibi debug anahtarıyla imzalanır — yerel derleme hiçbir sır
     * istemez, geliştiricinin makinesinde akış değişmez.
     *
     * NEDEN ÖNEMLİ: uygulama içi güncelleme, yeni APK'nın eskisiyle AYNI anahtarla imzalanmasını
     * ŞART koşar. İmza değişirse Android kurulumu "uygulama zaten var, imza uyuşmuyor" diye
     * reddeder ve bayi uygulamayı elle silmek zorunda kalır — sahada veri kaybı riski.
     */
    val sahaKeystore = System.getenv("SAHA_KEYSTORE_YOLU")
    if (!sahaKeystore.isNullOrBlank()) {
        signingConfigs {
            create("saha") {
                storeFile = file(sahaKeystore)
                storePassword = System.getenv("SAHA_KEYSTORE_SIFRE")
                keyAlias = "saha"
                keyPassword = System.getenv("SAHA_ANAHTAR_SIFRE")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (!sahaKeystore.isNullOrBlank()) {
                signingConfigs.getByName("saha")
            } else {
                // Yerel derleme: anahtar yok, bugünkü davranış korunur.
                // TODO: Faz 6'da mağaza anahtarı da gelecek.
                signingConfigs.getByName("debug")
            }
        }
    }
}

// ── ABI SAPMASI: DENENDİ, GERİ ALINDI — tekrar denemeyin ─────────────────────────────────────
//
// ÖLÇÜM (2026-07-28): `--split-per-abi` ile Flutter'ın gradle eklentisi versionCode'a ABI'ye
// özel sapma ekliyor — v7a `+1000`, arm64 `+2000`, x86_64 `+4000`. Git sayacı 128 iken üretilen
// APK'lar 1128 / 2128 / 4128 bildiriyor (aapt2 ile doğrulandı).
//
// `androidComponents.onVariants { it.versionCode.set(...) }` ile geri almayı DENEDİM: ETKİSİZ.
// Flutter eklentisi eski `applicationVariants.all { output.versionCodeOverride = ... }` API'sini
// `afterEvaluate` içinde uyguluyor ve bizim geç yazımımızı eziyor. Yeniden derleyip aapt ile
// doğruladım, sapma aynen duruyor.
//
// SONUÇ — GÜNCELLEME KARŞILAŞTIRMASI `PackageInfo.buildNumber`A DAYANDIRILAMAZ: arm64 cihaz
// kendini 2128, `surum.json`daki `yapim` alanını 128 görür, "zaten güncelim" deyip bir daha
// ASLA güncellenmez. Sessiz ve teşhisi zor bir arıza olurdu.
// Bu yüzden yapı numarası uygulamaya `--dart-define=SIPARIO_YAPIM=<git sayısı>` ile geçilir
// (kanal bilgisiyle aynı mekanizma); tanımsızsa güncelleme kontrolü hiç koşmaz.

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
