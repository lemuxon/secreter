# ============================================================
# SECRETER — ProGuard/R8 kuralları
#
# Release'te minify + resource shrink AÇIK. Bu dosya, yansıma (reflection)
# kullanan ve bu yüzden karartılamayan sınıfları korur.
# ============================================================

# ─────────────────────────────────────────────────────────────
# WorkManager + Room — AÇILIŞ ÇÖKMESİNİN SEBEBİ, SİLMEYİN
#
# ⚠️ Bu kurallar bir kez "proje WorkManager kullanmıyor" denilerek
# kaldırıldı ve uygulama release'te AÇILIŞTA çöktü:
#
#   java.lang.RuntimeException: Failed to create an instance of
#   androidx.work.impl.WorkDatabase
#       at androidx.work.WorkManagerInitializer.a(SourceFile:69)
#
# NEDEN: WorkManager `pubspec.yaml`'da GÖRÜNMEZ — firebase_messaging ve
# flutter_local_notifications üzerinden TRANSİTİF bir Android bağımlılığı
# olarak gelir ve `androidx.startup.InitializationProvider` ile daha
# `Application.onCreate` aşamasında başlatılır.
#
# Room, veritabanı uygulamasını YANSIMA ile bulur:
#     Class.forName(dbClass.getCanonicalName() + "_Impl")
# R8 `WorkDatabase_Impl` sınıfını yeniden adlandırdığında bu arama
# başarısız olur ve süreç daha ilk karede ölür.
# ─────────────────────────────────────────────────────────────
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class androidx.sqlite.** { *; }
-keep class androidx.startup.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public **[] *;
}
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# --- Firebase / Google Play Services ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- Flutter WebRTC (native köprü, yansıma kullanır) ---
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# --- Flutter eklenti kayıt sistemi ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Yerel bildirimler (GSON ile tip bilgisi gerekir) ---
-keep class com.dexterous.** { *; }

# --- GSON TypeToken (§4as) ---
#
# 🐞 CIHAZ TESTINDE BULUNDU. Yukaridaki iki kural (-keep com.dexterous.**
# ve -keepattributes Signature) VARDI ama YETMIYORDU; yayin derlemesinde
# her bildirim iptalinde su firliyordu:
#
#   PlatformException(error, TypeToken must be created with a type
#   argument: new TypeToken<...>() {}; When using code shrinkers
#   (ProGuard, R8, ...) make sure that generic signatures are preserved.
#     at com.dexterous.flutterlocalnotifications...loadScheduledNotifications
#
# Sebep: R8 "full mode" (AGP 8+ varsayilani) TypeToken'in ANONIM ALT
# SINIFLARINI kucultup/karartabiliyor; -keepattributes Signature tek
# basina yalnizca imzayi korur, sinifin kendisini degil. Asagidaki iki
# kural Gson'un resmi R8 3.0+ onerisidir.
#
# ⚠️ Bu blok silinirse yayin derlemesinde bildirim iptali PATLAR ve
# bunun testi YOKTUR — yalnizca gercek cihazda gorunur.
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Gson'un @SerializedName alanlari R8 tarafindan null birakilmasin
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn sun.misc.**

# --- image_cropper / uCrop ---
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# --- Uygulamanın kendi native köprüleri (MethodChannel + AppWidget) ---
-keep class com.secreter.app.MainActivity { *; }
-keep class com.secreter.app.UnreadWidgetProvider { *; }

# --- Tiink/AndroidX Security (flutter_secure_storage EncryptedSharedPreferences) ---
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# --- Yansıma için gerekli üst veriler ---
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Yığın izlerinin okunabilir kalması (Crashlytics eşleme dosyası yükler)
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
