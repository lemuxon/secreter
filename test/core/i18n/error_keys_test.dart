import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/error/exceptions.dart';
import 'package:gizli_chat/core/error/failures.dart';
import 'package:gizli_chat/core/i18n/app_localizations.dart';
import 'package:gizli_chat/features/conversations/domain/entities/conversation_entity.dart';

/// 🌐 KULLANICIYA DÖNEN HATA METİNLERİ ÇEVRİLEBİLİR OLMALI
///
/// Uygulama 16 dil taşıyor ama data/domain katmanı hataları SABİT TÜRKÇE
/// üretiyordu: bir Alman kullanıcı davet kodunu yanlış girdiğinde
/// "Geçersiz davet kodu" görüyordu. Üstelik `$e` ham Firebase metnini de
/// ekrana basıyordu — hem anlaşılmaz, hem gizlilik uygulamasında iç
/// detay sızıntısı.
///
/// Artık `Failure`/`Exception` bir **i18n anahtarı** taşır; çeviri
/// yalnızca arayüzde (`context.tr`) yapılır.
String _tr(String key, {String lang = 'en'}) =>
    AppLocalizations(Locale(lang)).t(key);

void main() {
  setUp(() => ConversationEntity.labelResolver = null);
  tearDown(() => ConversationEntity.labelResolver = null);

  group('varsayılan hata mesajları anahtardır', () {
    test('her Failure türü çevrilebilir bir anahtar taşır', () {
      const failures = <Failure>[
        ServerFailure(),
        NetworkFailure(),
        AuthFailure(),
        EncryptionFailure(),
        CacheFailure(),
        ValidationFailure(),
        UnexpectedFailure(),
      ];
      for (final f in failures) {
        expect(f.message, startsWith('err_'),
            reason: '${f.runtimeType} anahtar taşımıyor');
        // Anahtarın karşılığı gerçekten TANIMLI olmalı: `t()` bulamazsa
        // anahtarın KENDİSİNİ döndürür, yani kullanıcı "err_server" görür.
        expect(_tr(f.message), isNot(f.message),
            reason: '${f.message} için çeviri yok');
      }
    });

    test('exception varsayılanları da anahtar olmalı', () {
      // ⚠️ Bunlar repository tarafından `Failure(e.message)` ile aynen
      // taşınıp ekrana çıkıyor.
      final exceptions = <String>[
        const ServerException().message,
        const NetworkException().message,
        const AuthException().message,
        const EncryptionException().message,
        const CacheException().message,
      ];
      for (final m in exceptions) {
        expect(m, startsWith('err_'), reason: '$m sabit metin');
      }
    });
  });

  group('kullanılan anahtarların çevirisi var', () {
    // ⚠️ REGRESYON KORUMASI. Kod bir anahtar üretip i18n tablosuna
    // eklenmezse kullanıcı ham anahtarı ("err_send_message") görür —
    // sessiz ve çirkin bir bozulma.
    const used = [
      'err_load_messages',
      'err_send_message',
      'err_media_upload',
      'err_delete_message',
      'err_edit_message',
      'err_clear_chat',
      'err_reaction',
      'err_view_once',
      'err_mark_read',
      'err_decrypt_messages',
      'err_message_empty',
      'err_message_too_long',
      'err_poll_question_empty',
      'err_poll_min_options',
      'err_group_load',
      'err_group_create',
      'err_group_update',
      'err_group_delete',
      'err_group_not_found',
      'err_invite_invalid',
      'err_invite_code',
      'err_banned_from_group',
      'err_call_listen',
      'err_call_create',
      'err_call_answer',
      'err_call_update',
      'err_story_create',
      'err_story_upload',
      'err_story_delete',
      'err_story_seen',
      'err_status_empty',
      'err_status_too_long',
      'err_user_search',
      'err_user_gone',
      'err_self_chat',
      'err_chat_create',
      'err_session_missing',
      'err_username_check',
      'err_logout',
      'title_group_fallback',
      'title_chat_fallback',
      // §4x: şifreleme arızasında mesaj GÖNDERİLMEZ; kullanıcı bunu
      // anlaşılır bir metinle öğrenmeli.
      'err_encrypt_failed',
    ];

    test('anahtarların TÜRKÇE karşılığı tanımlı', () {
      for (final k in used) {
        expect(_tr(k, lang: 'tr'), isNot(k), reason: '$k → tr yok');
      }
    });

    test('anahtarların İNGİLİZCE karşılığı tanımlı', () {
      // İngilizce YEDEK dildir: bir anahtar burada yoksa kullanıcı ham
      // anahtarı ("err_send_message") görür.
      for (final k in used) {
        expect(_tr(k), isNot(k), reason: '$k → en yok');
      }
    });

    test('DESTEKLENMEYEN dil İNGİLİZCE yedeğine düşer, anahtara DEĞİL', () {
      // ⚠️ Bu test eskiden 'de' ile yazılmıştı ve Almanca'nın bu anahtarda
      // İngilizce'ye DÜŞTÜĞÜNÜ doğruluyordu — yani aslında bir ÇEVİRİ
      // AÇIĞINI test ediyordu. Açık §4ai'de kapatıldı (14 dil × 89
      // anahtar) ve test kırıldı; doğru davranış onu kırdı.
      //
      // Yedek mekanizması hâlâ önemli: tanımadığımız bir cihaz dili
      // ('xx') gelirse arayüz İngilizce olmalı, ham anahtar değil.
      // Desteklenen dillerdeki eksikleri artık
      // `translation_gate_test.dart` engelliyor.
      expect(_tr('err_send_message', lang: 'xx'),
          _tr('err_send_message', lang: 'en'));
      expect(_tr('err_send_message', lang: 'xx'), isNot('err_send_message'));
    });
  });

  group('domain katmanındaki yedek başlıklar', () {
    const grup = ConversationEntity(
      id: 'g1',
      type: ConversationType.group,
      memberIds: ['a', 'b'],
    );

    test('çeviri takılıysa kullanılır', () {
      ConversationEntity.labelResolver = (k) => 'ÇEVRİLDİ:$k';
      expect(grup.displayTitle('a'), 'ÇEVRİLDİ:title_group_fallback');
    });

    test('çeviri takılı değilse başlık BOŞ kalmaz', () {
      expect(grup.displayTitle('a'), 'Grup');
    });
  });
}
