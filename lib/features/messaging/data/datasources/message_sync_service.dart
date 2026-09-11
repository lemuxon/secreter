import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/network_info.dart';
import '../datasources/message_local_datasource.dart';
import '../datasources/message_remote_datasource.dart';
import '../../../../core/observability/handled_error.dart';
import '../../domain/entities/message_entity.dart';

/// Gönderilemeyen (pending) mesajları yönetir.
///
/// Offline'da gönderilen mesaj yerelde "pending" saklanır; ağ dönünce bu
/// servis kuyruğu işler. Başarılı olanlar kuyruktan silinir.
///
/// ── BU SÜRÜMDE DÜZELTİLEN DÖRT SORUN ──
///
/// 1. YARIŞ DURUMU → ÇİFT GÖNDERİM. `if (_isSyncing) return;` kontrolü ile
///    `_isSyncing = true` ataması arasında bir `await` vardı. İki çağrı
///    (açılış + bağlantı olayı) aynı anda kontrolü geçip AYNI MESAJI İKİ
///    KEZ gönderebiliyordu. Bayrak artık ilk `await`ten ÖNCE set edilir.
///
/// 2. "ÜSTEL GERİ ÇEKİLME" YOKTU. Sınıf dokümanı backoff olduğunu
///    söylüyordu ama hiç uygulanmamıştı: kalıcı hata veren bir mesaj her
///    bağlantı olayında sonsuza kadar yeniden deneniyordu (pil + kota).
///    Artık gerçek üstel backoff ve deneme sınırı var.
///
/// 3. GÖNDEREN KİMLİĞİ GEÇİLMİYORDU. `updateLastMessage` çağrısında
///    `senderId` yoktu; kuyruktan giden mesajlarda okunmamış sayacı
///    artmıyor ve `lastMessageSenderId` yazılmıyordu.
///
/// 4. ÖNİZLEMEYE ŞİFRELİ METİN YAZILIYORDU. `message.preview` E2EE bir
///    mesajda base64 ciphertext'tir; sohbet listesinde çöp görünüyordu.
class MessageSyncService {
  final MessageLocalDataSource localDataSource;
  final MessageRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  StreamSubscription<bool>? _connectivitySub;
  bool _isSyncing = false;
  Timer? _retryTimer;

  /// Mesaj başına deneme sayacı (kalıcı hata sonsuza kadar denenmesin).
  final Map<String, int> _attempts = {};

  /// Bu sayıdan sonra mesaj kuyruktan düşürülür.
  static const int maxAttempts = 6;

  MessageSyncService({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.networkInfo,
  });

  /// Senkronizasyonu başlat — ağ değişimlerini dinle.
  void start() {
    // Yeniden başlatılırsa önceki abonelik sızmasın.
    _connectivitySub?.cancel();
    _connectivitySub = networkInfo.onConnectivityChanged.listen((isConnected) {
      if (isConnected) syncPendingMessages();
    });
    syncPendingMessages();
  }

  /// Bekleyen tüm mesajları göndermeyi dene.
  Future<void> syncPendingMessages() async {
    // ── KRİTİK: bayrak İLK await'ten ÖNCE ──
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      if (!await networkInfo.isConnected) return;

      final pending = await localDataSource.getPendingMessages();
      if (pending.isEmpty) {
        _attempts.clear();
        return;
      }

      var needsRetry = false;

      for (final message in pending) {
        try {
          // 🐞 DURUM GÜNCELLENMİYORDU: kuyruktaki mesaj `status: sending`
          // ile saklanır (saat ikonu). Eskiden AYNI nesne gönderiliyordu,
          // yani Firestore'a `sending` yazılıyor ve yerel önbellek de
          // `sending` kalıyordu. Mesaj karşı tarafa ULAŞSA BİLE gönderende
          // saat ikonu SONSUZA KADAR duruyordu; durumu ilerleten başka
          // hiçbir yol yok. Artık `sent` olarak yazılır ve yerel kopya da
          // güncellenir.
          final delivered = message.copyWithStatus(MessageDeliveryStatus.sent);
          await remoteDataSource.sendMessage(message.chatId, delivered);
          // GİZLİLİK: önizlemeye içerik/ciphertext yazılmaz.
          await remoteDataSource.updateLastMessage(
            message.chatId,
            '🔒 Mesaj',
            senderId: message.senderId,
          );
          // Yerel önbellek de güncellenmeli: arayüz kuyruk boşaldıktan
          // sonra bu kopyayı gösteriyor.
          await localDataSource.cacheMessage(message.chatId, delivered);
          await localDataSource.removePendingMessage(message.id);
          _attempts.remove(message.id);
        } catch (e, s) {
          final tries = (_attempts[message.id] ?? 0) + 1;
          _attempts[message.id] = tries;
          if (tries >= maxAttempts) {
            // ÖLÜ MEKTUP: kalıcı hata (ör. izin reddi) kuyruğu sonsuza
            // kadar tıkamasın. Kullanıcı mesajı yeniden gönderebilir.
            // ⚠️ Mesaj ARTIK GÖNDERİLMEYECEK. Kullanıcıya bunu
            // söyleyen bir yol yok; en azından raporlanmalı ki kalıcı
            // hata (izin reddi, şema uyuşmazlığı) fark edilsin.
            reportHandled(
                'Mesaj kalıcı olarak gönderilemedi, kuyruktan '
                'düşürüldü',
                e,
                stack: s);
            await localDataSource.removePendingMessage(message.id);
            _attempts.remove(message.id);
          } else {
            needsRetry = true;
          }
        }
      }

      if (needsRetry) _scheduleRetry();
    } catch (e) {
      debugPrint('Senkronizasyon hatası: $e');
      _scheduleRetry();
    } finally {
      _isSyncing = false;
    }
  }

  /// ÜSTEL GERİ ÇEKİLME: en yüksek deneme sayısına göre gecikme.
  void _scheduleRetry() {
    final maxTries = _attempts.values.isEmpty
        ? 1
        : _attempts.values.reduce((a, b) => a > b ? a : b);
    // 4s, 8s, 16s, 32s, 64s … en fazla 5 dakika
    final seconds = (4 * (1 << (maxTries - 1).clamp(0, 7))).clamp(4, 300);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), syncPendingMessages);
  }

  /// Bekleyen mesaj sayısı (UI'da gösterilebilir).
  Future<int> pendingCount() async =>
      (await localDataSource.getPendingMessages()).length;

  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _attempts.clear();
  }
}
