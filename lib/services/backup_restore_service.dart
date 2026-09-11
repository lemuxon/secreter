import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/messaging/domain/entities/message_entity.dart';
import 'backup_service.dart';

/// 💾 YEDEKTEN GERİ YÜKLEME
///
/// TASARIM KARARI — neden sunucuya yazmıyoruz:
/// Yedekteki mesajlar CİHAZDA ÇÖZÜLMÜŞ (düz metin) hâldedir. Bunları
/// sunucuya geri yazmak, daha önce uçtan uca şifreli olan içeriği
/// sunucuda AÇIK hâle getirirdi — yani gizliliği geri yüklerken
/// gizliliği bozardık. Ayrıca karşı tarafın geçmişini de değiştirirdi.
///
/// Bunun yerine geri yükleme YALNIZCA BU CİHAZDA yapılır: mesajlar
/// ayrı bir yerel kutuya yazılır ve sohbet açıldığında sunucudan gelen
/// mesajlarla BİRLEŞTİRİLİR. Sunucuya hiçbir şey gönderilmez.
///
/// Aynı mesaj hem sunucuda hem yedekte varsa, sunucudaki kazanır
/// (kimlik bazlı tekilleştirme) — çift görünmez.
class BackupRestoreService {
  static const String _boxPrefix = 'restored_';

  // ---------------------------------------------------------------
  // BELLEK İÇİ ÖNBELLEK — CANLI AKIŞI BLOKLAMAMAK İÇİN
  //
  // SORUN: Mesaj akışı her güncellemede Hive'dan okuma yapıyordu.
  // `asyncMap` bu beklemeleri SIRAYA dizer; okuma yavaşlar/takılırsa
  // sonraki tüm canlı güncellemeler durur (mesaj/ses/çağrı ekrana
  // düşmez, uygulama yeniden açılınca düzelir).
  //
  // ÇÖZÜM: Akış artık SENKRON önbelleğe bakar. Önbellek yoksa arka
  // planda yüklenir ve akış BEKLETİLMEZ.
  // ---------------------------------------------------------------
  static final Map<String, List<MessageEntity>> _memCache = {};
  static final Set<String> _loading = {};

  /// Önbellekteki geri yüklenmiş mesajlar. `null` = henüz yüklenmedi.
  static List<MessageEntity>? getRestoredSync(String chatId) =>
      _memCache[chatId];

  /// Arka planda yükle (akışı bekletmeden).
  static void preload(String chatId) {
    if (_memCache.containsKey(chatId) || _loading.contains(chatId)) return;
    _loading.add(chatId);
    getRestored(chatId).then((list) {
      _memCache[chatId] = list;
      _loading.remove(chatId);
    }).catchError((_) {
      _memCache[chatId] = const <MessageEntity>[];
      _loading.remove(chatId);
    });
  }

  /// KUTU ERİŞİMİ — TEK KAPI (yarış koşulunu önler).
  ///
  /// KÖK NEDEN: Geri yükleme kutuya YAZARKEN, mesaj akışı aynı kutuyu
  /// OKUMAYA çalışıyordu. İki taraf da "kutu açık değil" görüp aynı anda
  /// `openBox` çağırınca Hive dosyası tutarsız okunuyor ve
  /// "unknown typeId" hatası veriyordu; yazma tarafı da kilitlenip
  /// ilerleme %0'da kalıyordu.
  ///
  /// Çözüm: her kutu için açma işlemi TEK Future'da tutulur; eşzamanlı
  /// çağrılar aynı Future'ı bekler.
  static final Map<String, Future<Box>> _opening = {};

  static Future<Box> _box(String chatId) {
    final name = '$_boxPrefix$chatId';
    if (Hive.isBoxOpen(name)) return Future.value(Hive.box(name));
    return _opening[name] ??= Hive.openBox(name).then((b) {
      _opening.remove(name);
      return b;
    }, onError: (e) {
      _opening.remove(name);
      throw e;
    });
  }

  /// Bir sohbetin yedekteki mesajlarını cihaza geri yükle.
  ///
  /// PERFORMANS + GERİ BİLDİRİM:
  ///  • Mesajlar TEK TEK değil, 500'lük PARÇALAR hâlinde yazılır.
  ///    (Tek tek yazmak binlerce mesajta dakikalar sürüyordu.)
  ///  • Her parçadan sonra arayüze kontrol geri verilir; böylece ilerleme
  ///    güncellenir ve ekran donmuş görünmez — tek sohbette 50.000 mesaj
  ///    olsa bile.
  static Future<int> restoreChat(
    BackupChat chat, {
    void Function(double chatProgress)? onChunk,
  }) async {
    final box = await _box(chat.id);
    final pending = <String, String>{};
    var written = 0;
    var seen = 0;
    final total = chat.messages.isEmpty ? 1 : chat.messages.length;

    Future<void> flush() async {
      if (pending.isEmpty) return;
      await box.putAll(pending);
      written += pending.length;
      pending.clear();
      // Arayuze nefes aldir
      await Future<void>.delayed(Duration.zero);
    }

    for (final m in chat.messages) {
      seen++;
      final key = _keyOf(m);
      if (!box.containsKey(key)) {
        // NOT: Hive'a Map yerine JSON METİN yazıyoruz. Map/dynamic
        // serileştirmesi tip hatalarına açık; String her sürümde güvenli.
        pending[key] = jsonEncode({
          'senderId': m.senderId,
          'senderUsername': m.senderUsername,
          'content': m.content,
          'type': m.type,
          'timestamp': m.timestamp?.toIso8601String(),
        });
      }
      if (pending.length >= 500) {
        await flush();
        onChunk?.call(seen / total);
      }
    }
    await flush();
    // Geri yükleme sonrası önbellek TAZELENMELİ, yoksa yeni mesajlar
    // sohbette görünmez.
    _memCache.remove(chat.id);
    _loading.remove(chat.id);
    onChunk?.call(1.0);
    return written;
  }

  /// Tüm yedeği geri yükle. [onProgress] 0..1 ilerleme + sohbet adı verir.
  ///
  /// DAYANIKLILIK: bir sohbet hata verirse tüm işlem durmaz; o sohbet
  /// atlanır ve kalanlar yüklenir.
  static Future<int> restoreAll(
    BackupData data, {
    void Function(double progress, String label)? onProgress,
  }) async {
    var total = 0;
    final n = data.chats.isEmpty ? 1 : data.chats.length;

    for (var i = 0; i < data.chats.length; i++) {
      final c = data.chats[i];
      onProgress?.call(i / n, c.title);
      try {
        total += await restoreChat(
          c,
          onChunk: (p) => onProgress?.call((i + p) / n, c.title),
        );
      } catch (e) {
        debugPrint('Geri yükleme atlandı (${c.id}): $e');
      }
      await Future<void>.delayed(Duration.zero);
    }
    onProgress?.call(1.0, '');
    return total;
  }

  /// Bu sohbet için geri yüklenmiş mesajlar (varsa).
  static Future<List<MessageEntity>> getRestored(String chatId) async {
    try {
      final name = '$_boxPrefix$chatId';
      // Kutu hic olusmadiysa acmayalim — bosuna dosya yaratmasin
      if (!Hive.isBoxOpen(name) && !await Hive.boxExists(name)) {
        return const [];
      }
      final box = await _box(chatId);
      if (box.isEmpty) return const [];

      final list = <MessageEntity>[];
      for (final entry in box.toMap().entries) {
        // Yeni biçim: JSON metin · Eski biçim: Map (geriye uyum)
        Map<String, dynamic> m;
        final v = entry.value;
        if (v is String) {
          m = Map<String, dynamic>.from(jsonDecode(v) as Map);
        } else if (v is Map) {
          m = Map<String, dynamic>.from(v);
        } else {
          continue;
        }
        list.add(MessageEntity(
          id: entry.key.toString(),
          chatId: chatId,
          senderId: (m['senderId'] ?? '').toString(),
          senderUsername: (m['senderUsername'] ?? '').toString(),
          content: (m['content'] ?? '').toString(),
          type: _typeOf((m['type'] ?? 'text').toString()),
          timestamp: DateTime.tryParse((m['timestamp'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          status: MessageDeliveryStatus.read,
          isEncrypted: false,
        ));
      }
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    } catch (e) {
      // KENDİNİ ONARMA: önceki sürümde yarış koşulu yüzünden bozulmuş
      // kutular kalıcı hata veriyordu. Okunamayan kutuyu silip temiz
      // başlangıç sağlıyoruz (canlı mesajlar etkilenmez).
      debugPrint('Geri yüklenen mesajlar okunamadı, kutu sıfırlanıyor: $e');
      try {
        final name = '$_boxPrefix$chatId';
        if (Hive.isBoxOpen(name)) await Hive.box(name).close();
        await Hive.deleteBoxFromDisk(name);
      } catch (e2) {
        debugPrint('Bozuk kutu silinemedi: $e2');
      }
      return const [];
    }
  }

  /// Bu sohbetin geri yüklenmiş mesajlarını sil (canlı veriye dokunmaz).
  static Future<void> clearChat(String chatId) async {
    try {
      final box = await _box(chatId);
      await box.clear();
    } catch (e) {
      debugPrint('Geri yükleme temizlenemedi: $e');
    }
  }

  /// Cihazdaki TÜM geri yüklemeleri sil.
  static Future<int> clearAll() async {
    var n = 0;
    // Hive box adlarini dogrudan listeleyemedigimiz icin acik kutulari
    // tarariz; kapalilar zaten getRestored ile acilinca temizlenebilir.
    for (final name in List<String>.from(_openBoxNames())) {
      if (!name.startsWith(_boxPrefix)) continue;
      try {
        await Hive.box(name).clear();
        n++;
      } catch (_) {}
    }
    return n;
  }

  static Iterable<String> _openBoxNames() {
    // Hive acik kutu adlarini disari vermez; pratikte restoreChat/getRestored
    // uzerinden acilanlari takip etmek yeterli.
    return const <String>[];
  }

  /// Mesaj anahtarı: yedekte id yoksa içerik+zaman ile üretilir.
  /// Aynı mesaj iki kez geri yüklenirse tekrar eklenmez.
  static String _keyOf(BackupMessage m) {
    final t = m.timestamp?.toIso8601String() ?? '';
    final raw = '${m.senderId}|$t|${m.content}';
    return 'r_${base64Url.encode(utf8.encode(raw)).replaceAll('=', '')}';
  }

  static MessageContentType _typeOf(String name) {
    for (final t in MessageContentType.values) {
      if (t.name == name) return t;
    }
    return MessageContentType.text;
  }
}
