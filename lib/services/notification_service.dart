import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/observability/handled_error.dart';
import '../features/security/presentation/app_lock_wrapper.dart';
import 'auth_service.dart';
import 'privacy_service.dart';

/// Push bildirim yönetimi (Firebase Cloud Messaging).
///
/// NOT: Gerçek push gönderimi sunucu tarafı gerektirir (Cloud Functions
/// veya kendi backend'in). Bu servis cihaz tokenını kaydeder, izin alır
/// ve gelen bildirimleri gösterir. Sunucu kurulumu README'de açıklanmıştır.
class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  static final _db = FirebaseFirestore.instance;

  static bool _initialized = false;

  /// Uygulama açılışında çağrılır
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Bildirim izni iste
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Yerel bildirim kanalı (Android)
    const androidChannel = AndroidNotificationChannel(
      'gizlichat_channel',
      'SECRETER Mesajları',
      description: 'Yeni mesaj bildirimleri',
      importance: Importance.high,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotif.initialize(initSettings);

    // Android 13+ icin bildirim iznini calisma zamaninda iste
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Token'ı kaydet
    await _saveToken();
    _fcm.onTokenRefresh.listen((_) => _saveToken());

    // Ön planda gelen mesajları yerel bildirim olarak göster
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  /// Cihaz FCM token'ını GİZLİ alt dokümana kaydet.
  ///
  /// ⚠️ Eskiden token, `users/{uid}` dokümanına yazılıyordu ve o doküman
  /// giriş yapmış HERKES tarafından okunabiliyordu — yani her kullanıcının
  /// push kimliği tüm kullanıcılara açıktı. Artık yalnızca sahibinin
  /// erişebildiği `users/{uid}/private/push` altında; Cloud Functions
  /// Admin SDK ile kurallardan bağımsız okur.
  static Future<void> _saveToken() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    try {
      final token = await _fcm.getToken();
      if (token == null) return;

      await _db.doc('users/$uid/private/push').set({
        'fcmToken': token,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));

      // Eski konumdaki token'ı temizle (güvenlik kuralı artık bu alanı
      // kullanıcı dokümanında kabul etmiyor).
      await _db.collection('users').doc(uid).set({
        'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true)).catchError((_) {});
    } catch (e, s) {
      // ⚠️ SESSİZ VE TAM İŞLEVSİZLİK: token kaydedilmezse bu cihaza HİÇ
      // push gelmez. Arayüzde hiçbir belirti yoktur; kullanıcı mesaj
      // gelmediğini sanır ve bunu uygulamanın çalışmadığına yorar.
      reportHandled('Push token kaydedilemedi — BİLDİRİM GELMEYECEK', e,
          stack: s);
    }
  }

  /// Ön planda FCM mesajı gelince: BİLEREK gösterme.
  /// Ön plan bildirimleri uygulama içi dinleyici (HomeShell) gösterir —
  /// aktif sohbet bastırması orada var. Burada da gösterirsek ÇİFT bildirim
  /// olur. Arka plan/kapalı durumda sistem, FCM notification yükünü zaten
  /// otomatik gösterir (Cloud Function gönderir).
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // no-op (çift bildirim önleme)
  }

  /// Aktif kullanıcının FCM token'ını kaydet (hesap değişiminde çağrılır).
  static Future<void> saveTokenForCurrentUser() => _saveToken();

  /// Uygulama içinden yerel bildirim göster (uygulama AÇIKKEN yeni mesaj).
  /// Gizlilik tercihi açıksa içerik gizlenir.
  static Future<void> showLocal(String title, String body,
      {String? chatId}) async {
    // ── SAHTE (PANİK) MOD ──
    // Sahte mod aktifken GERÇEK mesaj bildirimi göstermek, makul inkâr
    // edilebilirliği tamamen kırıyordu: sahte ekranın üstünde gerçek
    // gönderen adı ve mesaj içeriği belirebiliyordu.
    if (isDecoyActive()) return;

    final hideContent = await PrivacyService.isNotificationContentHidden();
    // Sohbet-bazli SABIT kimlik: ayni sohbetten yeni mesaj bildirimi
    // ustune yazar (yigilmaz) ve sohbete girilince tam olarak o bildirim
    // silinebilir. Bildirim, kullanici sohbete girene ya da cubuktan
    // kaydirana kadar durur.
    await _localNotif.show(
      chatId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      hideContent ? 'SECRETER' : title,
      hideContent ? 'Yeni mesaj' : body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gizlichat_channel',
          'SECRETER Mesajları',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Bir sohbetin bildirimini kapat (sohbete girildiginde cagrilir).
  static Future<void> cancelForChat(String chatId) async {
    await _localNotif.cancel(chatId.hashCode);
  }

  /// Çıkışta token'ı sil (yeni ve eski konumdan).
  static Future<void> deleteToken() async {
    final uid = AuthService.currentUid;
    if (uid != null) {
      try {
        await _db.doc('users/$uid/private/push').set({
          'fcmToken': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (e, s) {
        // ⚠️ ÇIKIŞ YAPILMIŞ CİHAZA BİLDİRİM AKMAYA DEVAM EDER: token
        // sunucuda kalırsa yeni mesajlar o telefonun KİLİT EKRANINDA
        // görünmeye devam eder. Ortak/eski bir cihazdan çıkış yapmanın
        // amacı tam olarak bunu durdurmaktı.
        reportHandled(
            'Push token sunucudan silinemedi — ESKİ CİHAZA BİLDİRİM GİDER', e,
            stack: s);
      }
    }
    try {
      await _fcm.deleteToken();
    } catch (e, s) {
      reportHandled('FCM token iptal edilemedi — ESKİ CİHAZA BİLDİRİM GİDER', e,
          stack: s);
    }
  }
}

/// Arka planda mesaj geldiğinde çalışır (top-level fonksiyon olmalı).
/// main.dart'ta FirebaseMessaging.onBackgroundMessage ile kaydedilir.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka plan bildirimi otomatik sistem tarafından gösterilir.
  // Ekstra işlem gerekirse buraya eklenir.
}
