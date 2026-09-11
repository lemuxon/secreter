import java.io.FileInputStream
import java.util.Properties

// ---------------------------------------------------------------
// İMZA: key.properties varsa release GERÇEK anahtarla imzalanır.
// ---------------------------------------------------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val hasSigning = keystorePropertiesFile.exists()

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    // ⚠️ PAKET ADI DEĞİŞTİ: com.gizlichat.gizli_chat → com.secreter.app
    // Play'de yayınlandıktan SONRA bir daha değiştirilemez.
    namespace = "com.secreter.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.secreter.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasSigning) {
                // GİZLİ BİLGİ: parolalar öncelikle ORTAM DEĞİŞKENİNDEN okunur.
                // Böylece CI'da ve paylaşılan makinelerde parolayı diske düz
                // metin yazmak zorunda kalmazsın; key.properties yalnızca
                // yerel geliştirme için yedek yoldur (ve .gitignore'dadır).
                keyAlias = System.getenv("SECRETER_KEY_ALIAS")
                    ?: keystoreProperties["keyAlias"] as String
                keyPassword = System.getenv("SECRETER_KEY_PASSWORD")
                    ?: keystoreProperties["keyPassword"] as String
                storeFile = file(
                    System.getenv("SECRETER_STORE_FILE")
                        ?: keystoreProperties["storeFile"] as String
                )
                storePassword = System.getenv("SECRETER_STORE_PASSWORD")
                    ?: keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // İMZA: gerçek anahtar yoksa release'i DEBUG anahtarıyla
            // imzalayıp "yayına hazır" görüntüsü vermek tehlikeliydi
            // (CI böyle bir APK'yı artefakt olarak yayınlıyordu).
            // Anahtar yoksa imzasız bırakılır; yükleme adımı açıkça patlar.
            signingConfig =
                if (hasSigning) signingConfigs.getByName("release") else null

            // R8 AÇIK: Dart kodu zaten AOT derlenir, ancak Java/Kotlin
            // katmanının karartılması + kaynak küçültme APK boyutunu ve
            // tersine mühendislik kolaylığını azaltır.
            // Kurallar proguard-rules.pro içinde; sürüm öncesi gerçek
            // cihazda release testi yapılmalıdır.
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled = false
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
