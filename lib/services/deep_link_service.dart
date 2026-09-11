import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/di/injection.dart';
import '../core/i18n/app_localizations.dart';
import '../features/group/domain/usecases/group_usecases.dart';
import '../features/messaging/presentation/screens/messaging_screen.dart';
import '../features/security/presentation/app_lock_wrapper.dart';
import '../services/auth_service.dart';

/// 🔗 DAVET DERİN-LİNKİ — `gizlichat://join/KOD`
///
/// ── BU SÜRÜMDE KAPATILAN İKİ GÜVENLİK BOŞLUĞU ──
///
/// 1. UYGULAMA KİLİDİNİ ATLIYORDU. Bağlantı, kök navigator'a doğrudan bir
///    sohbet ekranı push ediyordu. Kilit o zaman yalnızca `HomeShell`'i
///    saran bir rota olduğu için, PIN ekranı KİLİTLİYKEN gelen bir bağlantı
///    sohbeti üstüne açıyor ve kilidi tamamen anlamsız kılıyordu. Kilit artık
///    Navigator'ın üstünde (bkz. AppLockWrapper) ve burada da ayrıca
///    beklemeye alınır: kilit açılana kadar bağlantı İŞLENMEZ.
///
/// 2. ONAY ALINMIYORDU. Herhangi bir web sayfasındaki bağlantı, kullanıcıyı
///    SESSİZCE saldırganın grubuna ekliyor ve kullanıcı adını `memberUsernames`
///    listesine yazıyordu. Artık katılmadan önce açık onay istenir.
///
/// Ayrıca kod biçimi doğrulanır: doğrulanmamış kod doğrudan Firestore
/// doküman kimliği olarak kullanıldığında `..` gibi değerler istemci
/// tarafında ArgumentError fırlatıp akışı bozabiliyordu.
class DeepLinkService {
  static bool _inited = false;
  static StreamSubscription<Uri>? _sub;

  /// Kilit açıkken gelen bağlantı burada bekletilir.
  static String? _pendingCode;

  /// Geçerli davet kodu biçimi.
  static final RegExp _codePattern = RegExp(r'^[A-Za-z0-9_-]{4,64}$');

  static Future<void> init(GlobalKey<NavigatorState> nav) async {
    if (_inited) return;
    _inited = true;
    final links = AppLinks();
    try {
      final initial = await links.getInitialLink();
      if (initial != null) _handle(initial, nav);
    } catch (e) {
      debugPrint('DeepLink initial hata: $e');
    }
    _sub = links.uriLinkStream.listen(
      (u) => _handle(u, nav),
      onError: (Object e) => debugPrint('DeepLink stream hata: $e'),
    );
  }

  /// Kilit açıldıktan sonra bekleyen bağlantıyı işle.
  /// (PinLockScreen başarılı doğrulamadan sonra çağırır.)
  static Future<void> processPending(GlobalKey<NavigatorState> nav) async {
    final code = _pendingCode;
    if (code == null) return;
    _pendingCode = null;
    await _join(code, nav);
  }

  /// Derin bağlantıdan davet kodunu çıkar; bağlantı bize ait değilse ya
  /// da kod biçimi geçersizse null döner.
  ///
  /// SAF ve AYRI tutulur ki test edilebilsin. Bu, dışarıdan kontrol
  /// edilen bir girdinin tek doğrulama kapısıdır:
  ///  • Doğrulanmamış değer Firestore doküman kimliği olarak
  ///    kullanılıyordu ('..', '/', 1500+ bayt → ArgumentError).
  ///  • C-11'de kilit atlatan akışın giriş noktası da burasıydı.
  @visibleForTesting
  static String? parseInviteCode(Uri uri) {
    if (uri.scheme != 'gizlichat' || uri.host != 'join') return null;
    final code =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.first.trim() : '';
    return _codePattern.hasMatch(code) ? code : null;
  }

  static Future<void> _handle(Uri uri, GlobalKey<NavigatorState> nav) async {
    final code = parseInviteCode(uri);
    if (code == null) {
      debugPrint('DeepLink: geçersiz bağlantı/kod biçimi, yoksayıldı');
      return;
    }

    if (AuthService.currentUid == null) {
      debugPrint('DeepLink: oturum yok, davet yoksayıldı');
      return;
    }

    // KİLİT AÇILANA KADAR BEKLET.
    if (isAppLocked()) {
      _pendingCode = code;
      debugPrint('DeepLink: uygulama kilitli, davet beklemede');
      return;
    }

    await _join(code, nav);
  }

  static Future<void> _join(String code, GlobalKey<NavigatorState> nav) async {
    final myUid = AuthService.currentUid;
    if (myUid == null) return;

    final ctx = nav.currentContext;
    if (ctx == null) return;

    // ── KULLANICI ONAYI ──
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(dialogCtx.tr('join_group_q')),
        content: Text(dialogCtx.tr('join_group_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(dialogCtx.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(dialogCtx.tr('join')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await getIt<JoinByInviteCode>()(code);

    final liveCtx = nav.currentContext;
    result.fold(
      (f) {
        debugPrint('DeepLink katılım hatası: ${f.message}');
        if (liveCtx != null) {
          // Hata mesajları i18n ANAHTARI taşır; ham anahtar göstermek
          // ("err_server") kullanıcıya anlamsızdı.
          ScaffoldMessenger.of(liveCtx)
              .showSnackBar(SnackBar(content: Text(liveCtx.tr(f.message))));
        }
      },
      (chatId) async {
        String title = 'Grup';
        bool isGroup = true;
        try {
          final d = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .get();
          final data = d.data();
          title = (data?['groupName'] ?? 'Grup').toString();
          // Tür sabit 'true' varsayılıyordu; birebir davette arayüz yanlış
          // çiziliyordu.
          isGroup = (data?['type'] ?? 'group') != 'direct';
        } catch (_) {
          // başlık okunamadı — varsayılanla devam
        }
        nav.currentState?.push(MaterialPageRoute(
          builder: (_) => MessagingScreen(
            chatId: chatId,
            chatTitle: title,
            myUid: myUid,
            isGroup: isGroup,
          ),
        ));
      },
    );
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _pendingCode = null;
    _inited = false;
  }
}
