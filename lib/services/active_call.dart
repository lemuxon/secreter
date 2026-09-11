import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/call_model.dart';
import 'call_service.dart';

/// 📞 AKTİF ARAMA OTURUMU (global)
///
/// SORUN: `CallService` arama ekranıyla birlikte yaratılıp yok ediliyordu;
/// ekrandan çıkınca WebRTC bağlantısı kapanıyor, arama düşüyordu.
///
/// ÇÖZÜM: Oturum artık burada — uygulama ömrü boyunca yaşar. Arama ekranı
/// yalnızca bir "görüntüleyici"dir: açılır, mevcut oturuma bağlanır;
/// kapanınca oturum DEVAM EDER. Böylece arama arka plana alınabilir,
/// kullanıcı mesajlaşırken konuşma sürer.
///
/// Ses akışı ekran olmadan da devam eder (WebRTC ses yolu UI'dan
/// bağımsızdır). Video için görüntü ancak ekran açıkken çizilir; bağlantı
/// yine kopmaz, geri dönünce görüntü tazelenir.
class ActiveCall extends ChangeNotifier {
  ActiveCall._();
  static final ActiveCall instance = ActiveCall._();

  CallService? _service;
  CallService? get service => _service;

  String? callId;
  String? peerUid;
  String? peerUsername;
  CallType type = CallType.audio;
  bool isIncoming = false;
  // NOT: models/call_model.dart'ta 'dialing' yok; baslangic 'ringing'.
  CallStatus status = CallStatus.ringing;

  /// Konuşma başlangıcı (status = ongoing olduğu an) — süre sayacı için
  DateTime? answeredAt;

  MediaStream? localStream;
  MediaStream? remoteStream;

  /// Arama ekranı şu an görünürde mi? (şerit yalnızca değilken çıkar)
  bool screenVisible = false;

  /// 🔀 Medya TURN relay'i üzerinden mi akıyor?
  ///
  /// true ise cihazın gerçek IP'si karşı tarafa GİTMEZ. false ise arama
  /// P2P kurulur ve taraflar birbirinin IP adresini görür — anonimlik
  /// vaat eden bir uygulamada kullanıcının bunu bilmesi gerekir.
  bool relayActive = false;

  /// TURN yapılandırılmış ama erişilemiyor: arama kurulamaz.
  bool relayUnreachable = false;

  /// CEVAPSIZ ZAMAN ASIMI: karsi taraf 30 sn icinde cevaplamazsa cagri
  /// kendiliginden kapanir (sonsuza kadar calmasin). Cevaplanirsa iptal.
  Timer? _ringTimeout;
  static const ringTimeout = Duration(seconds: 30);

  bool get isActive => _service != null;
  bool get isVideo => type == CallType.video;

  Duration get elapsed => answeredAt == null
      ? Duration.zero
      : DateTime.now().difference(answeredAt!);

  /// Yeni oturum kur (arama başlat/cevapla ÖNCESİ çağrılır).
  CallService begin({
    required String peerUid,
    required String peerUsername,
    required CallType type,
    required bool isIncoming,
    String? callId,
  }) {
    // Zaten bir arama varsa onu kapat (aynı anda tek arama)
    if (_service != null) {
      endSession();
    }
    final svc = CallService();
    _service = svc;
    this.peerUid = peerUid;
    this.peerUsername = peerUsername;
    this.type = type;
    this.isIncoming = isIncoming;
    this.callId = callId;
    status = CallStatus.ringing;
    answeredAt = null;
    localStream = null;
    remoteStream = null;
    relayActive = false;
    relayUnreachable = false;

    // Oturum callback'leri MERKEZDE — ekran açık olmasa da durum güncellenir
    svc.onLocalStream = (s) {
      localStream = s;
      notifyListeners();
    };
    svc.onRemoteStream = (s) {
      remoteStream = s;
      // `iceTransportPolicy: relay` açıkken YALNIZCA relay adayları
      // toplanır; bağlantı kurulduysa medya kesinlikle relay üzerinden
      // akıyor demektir. Ayrıca istatistik sorgulamaya gerek yok.
      relayActive = svc.isRelayed;
      notifyListeners();
    };
    svc.onRelayUnreachable = () {
      relayUnreachable = true;
      notifyListeners();
    };
    svc.onStatusChanged = (st) {
      status = st;
      // Rozet `ongoing` olunca çizilir; relay bilgisi o ana kadar HAZIR
      // olmalı. Yalnızca uzak akış geldiğinde güncellemek, kısa bir süre
      // "IP görünüyor" yazmasına yol açardı.
      relayActive = svc.isRelayed;
      if (st == CallStatus.ongoing && answeredAt == null) {
        answeredAt = DateTime.now();
        _ringTimeout?.cancel(); // cevaplandi -> zaman asimi iptal
        _ringTimeout = null;
      }
      if (st == CallStatus.ended || st == CallStatus.rejected) {
        // Karşı taraf kapattı → oturumu temizle
        endSession(alreadyEnded: true);
        return;
      }
      notifyListeners();
    };
    // 30 sn cevap yoksa otomatik kapat (cevapsiz olarak arsivlenir)
    _ringTimeout?.cancel();
    _ringTimeout = Timer(ringTimeout, () {
      if (_service == svc && status != CallStatus.ongoing) {
        debugPrint('Arama 30 sn cevapsız — otomatik kapatılıyor');
        hangUp();
      }
    });

    notifyListeners();
    return svc;
  }

  void setScreenVisible(bool v) {
    if (screenVisible == v) return;
    screenVisible = v;
    notifyListeners();
  }

  /// Aramayı bitir (kullanıcı kapattı) ve oturumu temizle.
  Future<void> hangUp() async {
    final svc = _service;
    if (svc == null) return;
    try {
      await svc.endCall();
    } catch (e) {
      debugPrint('Arama sonlandırma hatası: $e');
    }
    endSession(alreadyEnded: true);
  }

  /// Oturumu kapat + kaynakları bırak.
  void endSession({bool alreadyEnded = false}) {
    _ringTimeout?.cancel();
    _ringTimeout = null;
    final svc = _service;
    _service = null;
    callId = null;
    peerUid = null;
    peerUsername = null;
    status = CallStatus.ended;
    answeredAt = null;
    localStream = null;
    remoteStream = null;
    screenVisible = false;
    relayActive = false;
    relayUnreachable = false;
    try {
      svc?.dispose();
    } catch (e) {
      debugPrint('Arama kaynak temizleme: $e');
    }
    notifyListeners();
  }
}
