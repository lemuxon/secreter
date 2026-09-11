import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/models/user_model.dart';

/// Kullanıcı profilindeki ÇEVRİMİÇİ durumunun hangi alandan geldiği.
///
/// 🐞 REGRESYON: Belgede iki alan yan yana duruyordu.
///   • `online`   → gerçek varlık alanı; TEK yazıcısı `PresenceService`,
///                  ve o kullanıcının "varlığımı paylaş" ayarına uyar.
///   • `isOnline` → yalnızca KAYIT anında bir kez `true` yazılıyor,
///                  bir daha güncellenmiyordu.
///
/// `UserModel.fromMap` ölü olanı okuyordu. Sonuç: arama sonucundaki nokta
/// HERKES için hep yeşil yanıyor, kişi aylardır girmemiş olsa bile — ve
/// gizlilik ayarı kapalı olsa bile.
void main() {
  Map<String, dynamic> profil(Map<String, dynamic> ek) => {
        'uid': 'u1',
        'username': 'ayse',
        'lastSeen': DateTime(2026, 9, 10).toIso8601String(),
        'publicKey': '',
        ...ek,
      };

  test('çevrimiçi durumu `online` alanından okunur', () {
    expect(UserModel.fromMap(profil({'online': true})).isOnline, isTrue);
    expect(UserModel.fromMap(profil({'online': false})).isOnline, isFalse);
  });

  test('ÖLÜ `isOnline` alanı çevrimiçi göstermez', () {
    // Kayıt anından kalma `isOnline: true` bulunan eski belgeler var;
    // bunlar kişiyi çevrimiçi göstermemeli.
    final u = UserModel.fromMap(profil({'isOnline': true}));
    expect(u.isOnline, isFalse,
        reason: 'yalnızca PresenceService\'in yazdığı `online` sayılır');
  });

  test('`online` yoksa ÇEVRİMDIŞI sayılır', () {
    expect(UserModel.fromMap(profil({})).isOnline, isFalse);
  });

  test('`online: false` ölü alandan BASKINDIR', () {
    // Gizlilik ayarı kapalıyken PresenceService `online: false` yazar.
    // Eski `isOnline: true` bunu EZMEMELİ.
    final u = UserModel.fromMap(profil({'online': false, 'isOnline': true}));
    expect(u.isOnline, isFalse,
        reason: '"varlığımı paylaşma" ayarı arama sonucunda da geçerli olmalı');
  });

  test('toMap ölü `isOnline` alanını ARTIK YAZMAZ', () {
    final m = UserModel(
      uid: 'u1',
      username: 'ayse',
      isOnline: true,
      lastSeen: DateTime(2026, 9, 10),
      publicKey: '',
    ).toMap();

    expect(m.containsKey('isOnline'), isFalse,
        reason: 'iki alan yan yana durdukça yanlış olanı okunmaya devam eder');
    expect(m['username'], 'ayse', reason: 'diğer alanlar bozulmamalı');
    expect(m['uid'], 'u1');
  });
}
