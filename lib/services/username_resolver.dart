import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 🕵️ KULLANICI ADI ÇÖZÜMLEYİCİ — uid → görünen ad, YEREL önbellekle.
///
/// ── NEDEN VAR ──
/// Her mesaj Firestore'a `senderUsername` alanını **düz metin** yazıyordu.
/// İçerik şifreli olsa bile sunucu (ve konsola erişen herkes) şunu
/// görüyordu:
///
///     @ayse → @mehmet, 14:32, okundu 14:33
///
/// Yani sosyal grafiğin tamamı, gerçek kullanıcı adlarıyla açıktı.
/// Telefon numarası istemeyen, anonimlik vaat eden bir uygulamada asıl
/// açık buydu — Signal'in "sealed sender" ile yıllarca uğraştığı alan.
///
/// Alan artık YAZILMIYOR; ad, gösterim anında uid'den burada çözülür.
///
/// ⚠️ Bu, metadata gizliliğinin YALNIZCA İLK aşamasıdır. `senderId`,
/// `readBy`, zaman damgaları ve sohbet üyeliği hâlâ sunucuda açıktır.
/// Kazanılan şey, grafiğin **adlarla** okunabilir olmaktan çıkmasıdır:
/// veritabanına bakan biri artık uid'leri ayrıca eşlemek zorundadır.
class UsernameResolver {
  UsernameResolver._();

  static final _db = FirebaseFirestore.instance;

  /// uid → kullanıcı adı. Süreç ömrü boyunca yaşar.
  static final Map<String, String> _mem = {};

  /// Aynı uid için eşzamanlı iki okuma yapılmasın.
  static final Map<String, Future<String>> _inFlight = {};

  /// Sınırsız büyümesin (uzun oturumda çok sayıda kanal üyesi görülebilir).
  static const int _cap = 2000;

  /// Önbellekten SENKRON oku. Arayüz çizim yolunda `await` edilemeyeceği
  /// için gerekir; yoksa null döner ve çağıran yedeğe düşer.
  static String? cached(String uid) => _mem[uid];

  /// Bilinen bir adı önbelleğe koy (ör. profil zaten çekilmişse).
  static void seed(String uid, String username) {
    if (uid.isEmpty || username.isEmpty) return;
    _put(uid, username);
  }

  static void _put(String uid, String username) {
    if (_mem.length >= _cap) {
      for (final k in _mem.keys.take(_cap ~/ 4).toList()) {
        _mem.remove(k);
      }
    }
    _mem[uid] = username;
  }

  /// Tek bir uid'i çöz. Bulunamazsa boş dize döner (asla fırlatmaz —
  /// bir adın çözülememesi mesajın gösterilmesini engellememelidir).
  static Future<String> resolve(String uid) async {
    if (uid.isEmpty) return '';
    final hit = _mem[uid];
    if (hit != null) return hit;

    final pending = _inFlight[uid];
    if (pending != null) return pending;

    final future = _fetch(uid);
    _inFlight[uid] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(uid);
    }
  }

  static Future<String> _fetch(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final name = (doc.data()?['username'] ?? '').toString();
      if (name.isNotEmpty) _put(uid, name);
      return name;
    } catch (e) {
      debugPrint('Kullanıcı adı çözülemedi ($uid): $e');
      return '';
    }
  }

  /// Birden çok uid'i paralel ısıt — mesaj listesi çizilmeden önce.
  ///
  /// Zaten önbellekte olanlar için ağ isteği YAPILMAZ; tipik sohbette
  /// ilk açılıştan sonra hiç istek olmaz.
  static Future<void> warm(Iterable<String> uids) async {
    final missing =
        uids.where((u) => u.isNotEmpty && !_mem.containsKey(u)).toSet();
    if (missing.isEmpty) return;
    await Future.wait(missing.map(resolve));
  }

  /// Hesap değişimi / çıkış: önbellek önceki hesaba aitti.
  static void clear() {
    _mem.clear();
    _inFlight.clear();
  }
}
