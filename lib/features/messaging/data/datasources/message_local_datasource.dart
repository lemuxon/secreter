import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/security/secure_store.dart';
import '../models/message_model.dart';
import '../../../../core/observability/handled_error.dart';

/// Mesajların lokal veri kaynağı (şifreli Hive önbelleği).
///
/// İki amaç:
///  1. Önbellek: ağdan geleni sakla → açılışta/offline'da anında göster
///  2. Pending kuyruğu: offline gönderilen mesajları sakla
///
/// ── BU SÜRÜMDE DÜZELTİLEN ÜÇ SORUN ──
///
/// 1. ÖNBELLEK ŞİFRESİZDİ. `Hive.openBox` şifreleme olmadan çağrılıyordu;
///    grup/kanal mesajları (düz metin) ve tüm mesaj metadata'sı cihazda
///    AÇIK bir dosyada duruyordu. `allowBackup` da açık olduğu için bu
///    dosya Google Drive'a yedeklenebiliyordu. Artık tüm kutular
///    [HiveAesCipher] ile şifreli açılır; anahtar secure storage'da.
///
/// 2. KUTULAR HİÇ KAPATILMIYORDU. Sohbet başına bir kutu açılıp asla
///    kapatılmadığı için dosya tanıtıcısı ve bellek sürekli birikiyordu.
///    Artık LRU ile en fazla [_maxOpenBoxes] kutu açık tutulur.
///
/// 3. SINIRSIZ BÜYÜME. Tahliye yoktu: silinen/kaybolan mesajlar bile
///    önbellekte kalıyordu. Artık kutu başına [_maxMessagesPerChat] sınırı
///    uygulanır (en eski kayıtlar düşer).
abstract class MessageLocalDataSource {
  Future<List<MessageModel>> getCachedMessages(String chatId);
  Future<void> cacheMessages(String chatId, List<MessageModel> messages);
  Future<void> cacheMessage(String chatId, MessageModel message);

  /// GİZLİ SOHBET / SOHBET TEMİZLEME: yerel önbelleği de boşalt.
  Future<void> clearCachedMessages(String chatId);

  // Pending (gönderilmeyi bekleyen) mesajlar
  Future<void> addPendingMessage(MessageModel message);
  Future<List<MessageModel>> getPendingMessages();
  Future<void> removePendingMessage(String messageId);

  /// Tüm yerel önbelleği sil (çıkış / hesap silme).
  Future<void> wipeAll();
}

class MessageLocalDataSourceImpl implements MessageLocalDataSource {
  static const String messagesBoxPrefix = 'messages_';
  static const String pendingBoxName = 'pending_messages';
  static const String _cipherKeyName = 'hive_cipher_key_v1';

  /// Aynı anda açık tutulacak en fazla sohbet kutusu.
  static const int _maxOpenBoxes = 12;

  /// Sohbet başına saklanacak en fazla mesaj.
  static const int _maxMessagesPerChat = 500;

  /// LRU: en son kullanılan kutu sonda.
  final LinkedHashSet<String> _openOrder = LinkedHashSet<String>();

  HiveAesCipher? _cipher;

  /// Şifreleme anahtarını al/üret (secure storage'da saklanır).
  Future<HiveAesCipher> _getCipher() async {
    final existing = _cipher;
    if (existing != null) return existing;

    var keyB64 = await SecureStore.read(_cipherKeyName);
    if (keyB64 == null) {
      final rand = Random.secure();
      final key = List<int>.generate(32, (_) => rand.nextInt(256));
      keyB64 = base64Url.encode(key);
      await SecureStore.writeOrThrow(key: _cipherKeyName, value: keyB64);
    }
    final cipher = HiveAesCipher(base64Url.decode(keyB64));
    _cipher = cipher;
    return cipher;
  }

  /// Sohbet kutusunu aç (şifreli) ve LRU'yu güncelle.
  Future<Box> _messagesBox(String chatId) async {
    final name = '$messagesBoxPrefix${_sanitize(chatId)}';
    _touch(name);
    if (Hive.isBoxOpen(name)) return Hive.box(name);
    await _evictIfNeeded();
    return Hive.openBox(name, encryptionCipher: await _getCipher());
  }

  Future<Box> _pendingBox() async {
    if (Hive.isBoxOpen(pendingBoxName)) return Hive.box(pendingBoxName);
    return Hive.openBox(pendingBoxName, encryptionCipher: await _getCipher());
  }

  /// Hive kutu adı dosya adına dönüşür. Büyük/küçük harf duyarsız
  /// dosya sistemlerinde (Windows/macOS) yalnızca harf büyüklüğüyle
  /// ayrılan iki sohbet kimliği AYNI dosyaya düşer ve önbellekler karışır.
  /// Bu yüzden ad, harf büyüklüğünü koruyan güvenli bir gösterime çevrilir.
  static String _sanitize(String chatId) {
    final b = StringBuffer();
    for (final c in chatId.codeUnits) {
      if (c >= 0x61 && c <= 0x7A) {
        b.write(String.fromCharCode(c)); // a-z
      } else if (c >= 0x30 && c <= 0x39) {
        b.write(String.fromCharCode(c)); // 0-9
      } else if (c >= 0x41 && c <= 0x5A) {
        b.write('_${String.fromCharCode(c + 32)}'); // A → _a
      } else {
        b.write('x${c.toRadixString(16)}');
      }
    }
    return b.toString();
  }

  void _touch(String name) {
    _openOrder.remove(name);
    _openOrder.add(name);
  }

  /// LRU tahliyesi: en eski kutuyu kapat (bellek + dosya tanıtıcısı).
  Future<void> _evictIfNeeded() async {
    while (_openOrder.length > _maxOpenBoxes) {
      final oldest = _openOrder.first;
      _openOrder.remove(oldest);
      if (Hive.isBoxOpen(oldest)) {
        try {
          await Hive.box(oldest).close();
        } catch (e) {
          debugPrint('Önbellek kutusu kapatılamadı ($oldest): $e');
        }
      }
    }
  }

  // ─────────────────────────────────────────
  // CACHE
  // ─────────────────────────────────────────

  @override
  Future<List<MessageModel>> getCachedMessages(String chatId) async {
    try {
      final box = await _messagesBox(chatId);
      final messages = <MessageModel>[];
      for (final raw in box.values) {
        // TEK BOZUK KAYIT TÜM ÖNBELLEĞİ DÜŞÜRMESİN — eskiden bir kayıttaki
        // tip hatası `getCachedMessages`'ı tamamen patlatıyordu.
        try {
          messages.add(
            MessageModel.fromMap(Map<String, dynamic>.from(raw as Map), chatId),
          );
        } catch (e) {
          debugPrint('Bozuk önbellek kaydı atlandı: $e');
        }
      }
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } on CacheException {
      rethrow;
    } catch (e, s) {
      reportHandled('Önbellek okunamadı', e, stack: s);
      throw const CacheException('err_cache');
    }
  }

  @override
  Future<void> cacheMessages(String chatId, List<MessageModel> messages) async {
    try {
      final box = await _messagesBox(chatId);
      await box.putAll({for (final m in messages) m.id: m.toMap()});
      await _trim(box);
    } catch (e, s) {
      reportHandled('Önbellek yazılamadı', e, stack: s);
      throw const CacheException('err_cache');
    }
  }

  @override
  Future<void> cacheMessage(String chatId, MessageModel message) async {
    try {
      final box = await _messagesBox(chatId);
      await box.put(message.id, message.toMap());
      await _trim(box);
    } catch (e, s) {
      reportHandled('Mesaj önbelleğe yazılamadı', e, stack: s);
      throw const CacheException('err_cache');
    }
  }

  /// Kutu sınırı aşıldıysa en eski mesajları düş (sınırsız disk büyümesi).
  Future<void> _trim(Box box) async {
    if (box.length <= _maxMessagesPerChat) return;
    final entries = <(dynamic, String)>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      final ts = raw is Map ? (raw['timestamp']?.toString() ?? '') : '';
      entries.add((key, ts));
    }
    entries.sort((a, b) => a.$2.compareTo(b.$2));
    final removeCount = box.length - _maxMessagesPerChat;
    await box.deleteAll(entries.take(removeCount).map((e) => e.$1));
  }

  @override
  Future<void> clearCachedMessages(String chatId) async {
    try {
      final box = await _messagesBox(chatId);
      await box.clear();
    } catch (e, s) {
      // Sunucu zaten temizlendi; akışı kırmamak için istisna yutulur.
      // ⚠️ Ama sonucu görünür: sunucudaki kopya gitti, ÇÖZÜLMÜŞ YEREL
      // kopya durdu. Kullanıcı "sohbeti temizledim" der; mesajlar
      // uygulama yeniden açıldığında geri gelir ve cihaza erişen biri
      // onları okuyabilir (C-07'nin sınıfı).
      reportHandled(
          'Sohbet önbelleği temizlenemedi — MESAJLAR CİHAZDA KALDI', e,
          stack: s);
    }
  }

  // ─────────────────────────────────────────
  // PENDING KUYRUĞU
  // ─────────────────────────────────────────

  @override
  Future<void> addPendingMessage(MessageModel message) async {
    try {
      final box = await _pendingBox();
      final map = message.toMap();
      map['_chatId'] = message.chatId;
      await box.put(message.id, map);
    } catch (e, s) {
      reportHandled('Bekleyen mesaj eklenemedi', e, stack: s);
      throw const CacheException('err_cache');
    }
  }

  @override
  Future<List<MessageModel>> getPendingMessages() async {
    try {
      final box = await _pendingBox();
      final out = <MessageModel>[];
      for (final raw in box.values) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          out.add(MessageModel.fromMap(map, (map['_chatId'] ?? '').toString()));
        } catch (e) {
          debugPrint('Bozuk pending kayıt atlandı: $e');
        }
      }
      return out;
    } catch (e, s) {
      reportHandled('Bekleyen mesajlar okunamadı', e, stack: s);
      throw const CacheException('err_cache');
    }
  }

  @override
  Future<void> removePendingMessage(String messageId) async {
    try {
      final box = await _pendingBox();
      await box.delete(messageId);
    } catch (e, s) {
      reportHandled('Bekleyen mesaj silinemedi', e, stack: s);
      throw const CacheException('err_cache');
    }
  }

  @override
  Future<void> wipeAll() async {
    for (final name in _openOrder.toList()) {
      if (Hive.isBoxOpen(name)) {
        try {
          await Hive.box(name).deleteFromDisk();
        } catch (e, s) {
          // ⚠️ `wipeAll()` ÇIKIŞ, HESAP SİLME ve PANİK yollarında çalışır.
          // Bir kutu silinemezse o sohbetin ÇÖZÜLMÜŞ mesajları diskte
          // kalır — "hesabımı sildim" bir yanılsamaya döner (C-07).
          reportHandled('Mesaj kutusu silinemedi — MESAJLAR CİHAZDA KALDI', e,
              stack: s);
        }
      }
    }
    _openOrder.clear();
    try {
      final pending = await _pendingBox();
      await pending.deleteFromDisk();
    } catch (e, s) {
      // Kuyrukta gönderilmemiş DÜZ METİN mesajlar durur; aynı sınıf.
      reportHandled(
          'Bekleyen mesaj kutusu silinemedi — MESAJLAR CİHAZDA KALDI', e,
          stack: s);
    }
  }
}
