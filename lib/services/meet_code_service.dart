import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/observability/handled_error.dart';

/// 🤝 BULUŞMA KODU — kullanıcı adını paylaşmadan tanışma
///
/// NEDEN BU ÖZELLİK ÖNEMLİ:
/// Numara isteyen uygulamalarda (WhatsApp vb.) biriyle konuşmak için
/// kalıcı kimliğini — telefon numaranı — vermek zorundasın. Numara geri
/// alınamaz: karşı taraf onu saklar, rehberine ekler, başkasına verebilir.
///
/// SECRETER'de kalıcı kimlik bile paylaşmak gerekmiyor: 5 dakika geçerli,
/// TEK KULLANIMLIK bir kod üretirsin. Karşı taraf kodu girer, sohbet
/// açılır, kod ölür. İlanla satış, iş görüşmesi, konferansta tanışma
/// gibi "numaramı vermek istemiyorum" durumları için tasarlandı.
///
/// GÜVENLİK SINIRLARI:
///  • 5 dakika ömür — sızsa bile kısa süre sonra işe yaramaz
///  • Tek kullanım — ilk kullanan alır, ikinci kişi giremez
///  • Kod tahmin edilemez (kriptografik rastgele, 8 karakter)
///  • Karıştırılan karakterler (0/O, 1/I/L) alfabeden ÇIKARILDI
///  • Kendi kodunu kullanamazsın
class MeetCodeService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('meetCodes');

  /// Kodun geçerlilik süresi.
  static const Duration lifetime = Duration(minutes: 5);

  /// Okunması kolay alfabe: benzeyen karakterler yok (0/O, 1/I/L, 5/S)
  static const _alphabet = 'ABCDEFGHJKMNPQRTUVWXY2346789';

  static String _generate() {
    final r = Random.secure();
    return List.generate(8, (_) => _alphabet[r.nextInt(_alphabet.length)])
        .join();
  }

  /// 🐞 KULLANICININ GİRDİĞİ KODU DOKÜMAN KİMLİĞİNE ÇEVİR.
  ///
  /// ── DÜZELTİLEN HATA ──
  /// Kod ekranda ve panoda **tireli** gösteriliyor (`ABCD-EFGH`, bkz.
  /// [MeetCode.pretty]) ve giriş alanının ipucu da tam olarak `ABCD-EFGH`
  /// yazıyordu. Ama ayrıştırıcı yalnızca BOŞLUK siliyordu:
  ///
  ///     code.trim().toUpperCase().replaceAll(RegExp(r'\s'), '')
  ///
  /// Sonuç: kullanıcı kendi uygulamasının kopyaladığı kodu yapıştırınca
  /// 9 karakter oluyor, uzunluk kontrolüne takılıyor ve
  /// "geçersiz kod" alıyordu. Tireyi ELLE silmek zorundaydı — yani
  /// uygulama kendi ürettiği biçimi kabul etmiyordu.
  ///
  /// Artık harf ve rakam DIŞINDAKİ her şey atılır: tire, boşluk, nokta,
  /// görünmez karakterler, satır sonu. Böylece hem `ABCD-EFGH` hem
  /// `abcd efgh` hem de düz `ABCDEFGH` çalışır.
  ///
  /// ⚠️ Alfabede olmayan HARFLER atılmaz (ör. yanlışlıkla yazılan `S`).
  /// Atmak, kalan karakterleri kaydırıp BAŞKA birinin geçerli koduna
  /// dönüştürebilirdi; yanlış kodun dürüstçe "bulunamadı" demesi doğrusu.
  static String normalize(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Yeni kod üret ve sunucuya yaz. Çakışma olursa yeniden dener.
  static Future<MeetCode> create({
    required String myUid,
    required String myUsername,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generate();
      final doc = _col.doc(code);
      final now = DateTime.now();
      final expires = now.add(lifetime);
      try {
        // Var olan bir kodu ezmemek için önce kontrol
        final existing = await doc.get();
        if (existing.exists) continue;
        await doc.set({
          'code': code,
          'ownerUid': myUid,
          'ownerUsername': myUsername,
          'createdAt': now.toIso8601String(),
          'expiresAt': expires.toIso8601String(),
          'usedBy': null,
        });
        return MeetCode(code: code, expiresAt: expires);
      } catch (e) {
        debugPrint('Buluşma kodu yazılamadı: $e');
        rethrow;
      }
    }
    throw Exception('meet_code_generate_failed');
  }

  /// Kodu iptal et (paylaşmaktan vazgeçtin).
  static Future<void> cancel(String code) async {
    try {
      await _col.doc(code).delete();
    } catch (e, s) {
      // ⚠️ KOD CANLI KALIR: kullanıcı "iptal ettim" der ama doküman
      // duruyor — kodu daha önce paylaştığı HERKES süresi dolana kadar
      // onu kullanıp kendisine ulaşabilir. Vazgeçmenin tek yolu buydu.
      reportHandled('Buluşma kodu iptal edilemedi — KOD HÂLÂ GEÇERLİ', e,
          stack: s);
    }
  }

  /// Kodun kullanılıp kullanılmadığını izle — üreten taraf için.
  /// Karşı taraf kodu girdiğinde onun kullanıcı adını döndürür.
  static Stream<String?> watchUsedBy(String code) =>
      _col.doc(code).snapshots().map((d) {
        final data = d.data();
        if (data == null) return null;
        return data['usedByUsername'] as String?;
      });

  /// Kodu kullan. Başarılıysa karşı tarafın kullanıcı adını döner.
  ///
  /// Hata durumları çeviri ANAHTARI olarak fırlatılır; arayüz kullanıcının
  /// diline çevirir.
  static Future<String> redeem({
    required String code,
    required String myUid,
    required String myUsername,
  }) async {
    final clean = normalize(code);
    if (clean.length != 8) throw const MeetCodeError('meet_code_invalid');

    final doc = _col.doc(clean);

    // ── ATOMİK TEK KULLANIM ──
    // Eski kod `get()` → kontrol → `set()` yapıyordu. İki kişi aynı kodu
    // aynı anda girdiğinde ikisi de "kullanılmamış" görüp ikisi de
    // işaretliyordu; yani "TEK KULLANIMLIK" garantisi geçersizdi.
    // Transaction, kontrolü ve yazımı bölünmez hâle getirir.
    return _db.runTransaction<String>((tx) async {
      final snap = await tx.get(doc);
      if (!snap.exists) throw const MeetCodeError('meet_code_not_found');

      final d = snap.data()!;
      final ownerUid = (d['ownerUid'] ?? '').toString();
      final ownerUsername = (d['ownerUsername'] ?? '').toString();

      if (ownerUid == myUid) throw const MeetCodeError('meet_code_own');

      final expires = DateTime.tryParse((d['expiresAt'] ?? '').toString());
      if (expires == null || DateTime.now().toUtc().isAfter(expires.toUtc())) {
        throw const MeetCodeError('meet_code_expired');
      }
      if (d['usedBy'] != null) throw const MeetCodeError('meet_code_used');

      tx.update(doc, {
        'usedBy': myUid,
        'usedByUsername': myUsername,
        'usedAt': DateTime.now().toUtc().toIso8601String(),
      });
      return ownerUsername;
    });
  }
}

class MeetCode {
  final String code;
  final DateTime expiresAt;
  const MeetCode({required this.code, required this.expiresAt});

  Duration get remaining {
    final d = expiresAt.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// Görüntülemek için 4'lü gruplar: ABCD-EFGH
  String get pretty =>
      code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;
}

/// Çeviri anahtarı taşıyan hata (arayüz `context.tr(key)` ile gösterir).
class MeetCodeError implements Exception {
  final String key;
  const MeetCodeError(this.key);
  @override
  String toString() => key;
}
