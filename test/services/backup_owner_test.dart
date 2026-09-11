import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/backup_service.dart';

/// 🐞 YEDEK SAHİPLİĞİ DOĞRULANMIYORDU (§4ao)
///
/// `BackupService.create` yedeğe `ownerUid` yazıyordu ama
/// `BackupData.fromMap` o alanı **düşürüyordu** — yani yazılıyor,
/// hiç okunmuyordu.
///
/// Neden önemli: geri yükleme tamamen YEREL ve `chatId` ile anahtarlı.
/// Birebir sohbet kimliği `sıralı(uid1,uid2)`den türüyor, yani BAŞKA
/// bir hesabın yedeği geri yüklendiğinde mesajlar bu hesabın hiçbir
/// zaman açmayacağı chatId'lere yazılıyordu. Ekran *"N mesaj geri
/// yüklendi"* diyor, kullanıcı sohbetlere bakıyor ve **hiçbir şey
/// yok.** Hata da yok — projenin imza arıza sınıfı.
BackupData _data({String? ownerUid}) => BackupData.fromMap({
      'createdAt': '2026-09-10T00:00:00.000Z',
      'chatCount': 1,
      'messageCount': 2,
      if (ownerUid != null) 'ownerUid': ownerUid,
      'chats': const [],
    });

void main() {
  group('yedek sahipliği', () {
    test('ownerUid OKUNUR (eskiden düşürülüyordu)', () {
      expect(_data(ownerUid: 'uid-alice').ownerUid, 'uid-alice');
    });

    test('🔒 BAŞKA hesabın yedeği bu hesaba ait sayılmaz', () {
      // Asıl regresyon koruması: bu `false` dönmezse ekran sessizce
      // geri yükler ve kullanıcı boş sohbetlerle kalır.
      expect(_data(ownerUid: 'uid-bob').belongsTo('uid-alice'), isFalse);
    });

    test('kendi yedeği geri yüklenebilir', () {
      expect(_data(ownerUid: 'uid-alice').belongsTo('uid-alice'), isTrue);
    });

    test('ESKİ yedek (ownerUid YOK) reddedilmez', () {
      // ⚠️ §4m'nin dersi: yeni bir alan zorunlu kılınırken eski
      // kayıtların ne olacağı düşünülmeli. Doğrulayamadığımız bir
      // dosyayı reddetmek, çalışan bir kurtarma yolunu kırardı.
      expect(_data().ownerUid, isNull);
      expect(_data().belongsTo('uid-alice'), isTrue);
    });

    test('boş ownerUid, YOK sayılır', () {
      expect(_data(ownerUid: '   ').ownerUid, isNull);
      expect(_data(ownerUid: '').belongsTo('uid-alice'), isTrue);
    });
  });
}
