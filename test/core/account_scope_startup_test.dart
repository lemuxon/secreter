import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// HESAP KAPSAMI OTURUM OTURDUĞUNDA YENİDEN KURULMALI (§4bd).
///
/// ── ARIZA ──
/// E2EE oturumları, düz metinler, grup anahtarları ve sohbet kilitleri
/// aktif hesabın uid'siyle ÖNEKLENEREK saklanır:
///
///     e2ee_session_{uid}_{chatId}
///     e2ee_plain_{uid}_{messageId}
///
/// Kapsam `main.dart`'ta **bir kez**, `AuthService.currentUid`'den
/// kuruluyordu. Ama `FirebaseAuth.currentUser`, `initializeApp()` hemen
/// ardından HENÜZ NULL olabilir — kaydedilmiş oturum ASENKRON yüklenir.
///
/// O yarışı kaybeden açılışta kapsam `'_'` kalır ve:
///   • oturum anahtarı `e2ee_session___{chatId}` olur → KAYITLI OTURUM
///     BULUNAMAZ → gelen her mesaj "bu cihazda çözülemiyor",
///   • giden mesajlar `'_'` altında YENİ oturum kurar → bir sonraki
///     açılışta doğru uid ile okunduğunda öksüz kalır ve karşı tarafın
///     cevapları da çözülemez.
///
/// Her açılışta yeniden zar atıldığı için arıza ARALIKLI görünür:
/// "bir ara düzeldi, sonra yine bozuldu."
///
/// ── NEDEN KAYNAK TARAMASI ──
/// Arıza açılış SIRALAMASINDA; birim testinde Firebase Auth'un geri
/// yükleme gecikmesi taklit edilemez. O yüzden sınanan şey davranış
/// değil, ONU SAĞLAYAN YAPI: kapsam tek bir yerden kuruluyor mu ve
/// oturum değişimlerine abone olunuyor mu? (Aynı yöntem
/// `test/tooling/secret_scan_test.dart` ve GIF kapısında da kullanılıyor.)
void main() {
  final main_ = File('lib/main.dart');
  final auth = File('lib/services/auth_service.dart');

  test('kapsam TEK yerden kuruluyor', () {
    final kaynak = main_.readAsStringSync();
    expect(kaynak, contains('void _hesapKapsaminiKur(String? uid)'),
        reason: 'dört servis ayrı ayrı elle ayarlanırsa biri unutulur ve '
            'o servisin verisi yanlış önekle okunur');

    for (final servis in [
      'E2EESessionService.setActiveAccount(uid)',
      'GroupKeyService.setActiveAccount(uid)',
      'ChatLockService.setActiveAccount(uid)',
      'KeyManagementService.setActiveAccount(uid)',
    ]) {
      expect(kaynak, contains(servis), reason: '$servis kapsamlanmıyor');
    }
  });

  test('🔴 oturum değişimine ABONE olunuyor', () {
    final kaynak = main_.readAsStringSync();
    expect(kaynak, contains('AuthService.activeUidChanges.listen'),
        reason: 'yalnızca açılışta bir kez kurmak YETMEZ: o an '
            '`currentUser` null ise kapsam tüm çalışma boyunca "_" kalır '
            've hiçbir mesaj çözülemez');
  });

  test('uid akışı AuthService üzerinden veriliyor', () {
    final kaynak = auth.readAsStringSync();
    expect(kaynak, contains('static Stream<String?> get activeUidChanges'),
        reason: 'akış kaldırılırsa main.dart abone olamaz');
    expect(kaynak, contains('authStateChanges()'),
        reason: 'kaynak Firebase oturum akışı olmalı');
  });
}
