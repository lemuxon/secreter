import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import '../models/call_model.dart';
import 'auth_service.dart';
import 'call_log_service.dart';
import 'turn_credentials_service.dart';

/// WebRTC tabanlı sesli/görüntülü arama servisi.
///
/// Mimari:
/// - Signaling (offer/answer/ICE) Firestore üzerinden yapılır.
/// - Ses/görüntü verisi P2P akar — sunucudan geçmez.
/// - STUN sunucuları NAT arkasındaki cihazların birbirini bulması için.
///
/// NOT: Bazı ağlarda (simetrik NAT) P2P kurulamaz; bu durumda TURN
/// sunucusu gerekir. Ücretsiz STUN yeterli olmazsa README'deki TURN
/// kurulumuna bakın.
class CallService {
  static final _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _callId;
  StreamSubscription? _callSub;

  /// Tek abonelik yeter: adaylar artık tek koleksiyonda ve bana
  /// adreslenmiş olanlar sorguyla süzülüyor.
  StreamSubscription? _candidatesSub;

  /// `setRemoteDescription` bir kez çağrılsın (yarış koruması).
  bool _remoteDescriptionSet = false;

  // Callback'ler — UI'ı güncellemek için
  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;
  Function(CallStatus status)? onStatusChanged;

  /// TURN yapılandırılmış ama erişilemiyor (bkz. [relayUnreachable]).
  void Function()? onRelayUnreachable;

  // ─────────────────────────────────────────
  // ICE / TURN YAPILANDIRMASI
  //
  // ⚠️ ANONİMLİK İÇİN KRİTİK:
  // Yalnızca STUN kullanmak, çağrının P2P kurulması demektir — yani
  // ARAYAN VE ARANAN BİRBİRİNİN GERÇEK IP ADRESİNİ ÖĞRENİR. Numara
  // istemeyen, anonimlik vaat eden bir uygulamada bu, kimliğin en
  // güçlü belirleyicilerinden birini karşı tarafa vermek anlamına gelir.
  // (Signal/WhatsApp da rehberde olmayan kişilerle aramaları relay eder.)
  //
  // TURN yapılandırıldığında `iceTransportPolicy: relay` ile YALNIZCA
  // relay adayları toplanır; cihazın gerçek IP'si karşı tarafa hiç
  // gitmez. Kimlik bilgileri artık `TurnCredentialsService` üzerinden,
  // tercihen SUNUCUDAN ve kısa ömürlü olarak alınır — bkz. o dosyadaki
  // "APK'dan çıkarılabilir" notu.
  //
  // Bu aramada relay kullanılıyor mu? Arayüz bunu kullanıcıya gösterir:
  // IP'sinin görünüp görünmediğini bilmek kullanıcının hakkı.
  bool _relayActive = false;
  bool get isRelayed => _relayActive;

  /// TURN erişilemediği için bağlantı kurulamadı mı? `relay` politikası
  /// açıkken TURN'e ulaşılamazsa ICE hiçbir aday bulamaz ve arama
  /// sessizce başarısız olur — bu bayrak onu ayırt edilebilir yapar.
  bool _relayUnreachable = false;
  bool get relayUnreachable => _relayUnreachable;

  /// Ses aramasında video hattı açmamak için tipe göre seçenek.
  static Map<String, dynamic> _offerOptions(CallType type) => {
        'offerToReceiveAudio': true,
        // Eski kod ses aramasında da video hattı pazarlıyordu (gereksiz
        // bant genişliği + hatalı m-line).
        'offerToReceiveVideo': type == CallType.video,
      };

  // ─────────────────────────────────────────
  // ARAMA BAŞLATMA (CALLER)
  // ─────────────────────────────────────────

  /// Birini ara
  Future<CallModel> startCall({
    required String calleeId,
    required String calleeUsername,
    required CallType type,
  }) async {
    _callId = _uuid.v4();
    // TURN kimliğini şimdiden iste: `getUserMedia` (izin diyaloğu dahil)
    // zaten zaman alıyor, istek onun arkasına gizlenir.
    TurnCredentialsService.prefetch();
    final me = await AuthService.getCurrentUserData();

    final call = CallModel(
      id: _callId!,
      callerId: AuthService.currentUid!,
      callerUsername: me?.username ?? '',
      calleeId: calleeId,
      calleeUsername: calleeUsername,
      type: type,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
    );

    // Yerel medyayı al
    await _initLocalStream(type);

    // Peer connection kur
    await _createPeerConnection();

    final callDoc = _db.collection('calls').doc(_callId);

    // ── ICE ADAYLARI: ADRESLİ TEK KOLEKSİYON ──
    // Eskiden `callerCandidates` / `calleeCandidates` diye İKİ sabit alt
    // koleksiyon vardı; bu, şemayı iki kişiye çiviliyordu. Artık her
    // aday KİMDEN–KİME olduğunu taşır, yani N kişi aynı belgeyi
    // paylaşabilir.
    //
    // 🔒 Yan kazanç: kural motoru adayı yalnızca göndericisine ve
    // alıcısına açar. Grup aramasında A, B↔C adaylarını — yani onların
    // IP ADRESLERİNİ — göremez (C-03'ün grup hâli).
    final myUid = AuthService.currentUid!;
    _peerConnection!.onIceCandidate = (candidate) {
      callDoc.collection('candidates').add({
        ...candidate.toMap(),
        'from': myUid,
        'to': calleeId,
      });
    };

    // Offer oluştur
    final offer = await _peerConnection!.createOffer(_offerOptions(type));
    await _peerConnection!.setLocalDescription(offer);

    // Çağrıyı + offer'ı kaydet
    await callDoc.set({
      ...call.toMap(),
      'offer': {'type': offer.type, 'sdp': offer.sdp},
    });

    // Answer'ı dinle
    _callSub = callDoc.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;

      // ── YARIŞ DURUMU KORUMASI ──
      // Eski kod `getRemoteDescription() == null` kontrolü yapıyordu; bu
      // asenkron olduğu için hızlı ardışık iki snapshot ikisi de kontrolü
      // geçip `setRemoteDescription`'ı İKİ KEZ çağırabiliyor ve
      // InvalidStateError üretiyordu. Senkron bayrak bunu engeller.
      final answer = data['answer'];
      if (answer != null && !_remoteDescriptionSet) {
        _remoteDescriptionSet = true;
        final sdp = answer['sdp'];
        final type = answer['type'];
        if (sdp is String && type is String) {
          try {
            await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(sdp, type),
            );
            onStatusChanged?.call(CallStatus.ongoing);
          } catch (e) {
            _remoteDescriptionSet = false;
            debugPrint('setRemoteDescription başarısız: $e');
          }
        }
      }

      // Durum değişimleri
      final status = CallStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CallStatus.ended,
      );
      if (status == CallStatus.rejected || status == CallStatus.ended) {
        onStatusChanged?.call(status);
        await _cleanup();
      }
    });

    // Bana ADRESLENMİŞ adayları dinle
    _candidatesSub = callDoc
        .collection('candidates')
        .where('to', isEqualTo: myUid)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;
        // `_peerConnection!` çağrı kapandıktan sonra gelen bir adayda
        // null-check hatasıyla ÇÖKÜYORDU (abonelik iptali ile aday
        // teslimi arasında pencere var). Güvenli erişim + try/catch.
        try {
          _peerConnection?.addCandidate(
            RTCIceCandidate(
              data['candidate'] as String?,
              data['sdpMid'] as String?,
              (data['sdpMLineIndex'] as num?)?.toInt(),
            ),
          );
        } catch (e) {
          debugPrint('ICE adayı eklenemedi: $e');
        }
      }
    });

    return call;
  }

  // ─────────────────────────────────────────
  // ARAMA CEVAPLAMA (CALLEE)
  // ─────────────────────────────────────────

  /// Gelen aramayı cevapla
  Future<void> answerCall({
    required String callId,
    required CallType type,
  }) async {
    _callId = callId;
    TurnCredentialsService.prefetch();
    final callDoc = _db.collection('calls').doc(callId);
    final callData = (await callDoc.get()).data();
    if (callData == null) return;

    await _initLocalStream(type);
    await _createPeerConnection();

    // Adresli adaylar (yukarıdaki gerekçe)
    final myUid = AuthService.currentUid!;
    final peerUid = (callData['callerId'] ?? '').toString();
    _peerConnection!.onIceCandidate = (candidate) {
      callDoc.collection('candidates').add({
        ...candidate.toMap(),
        'from': myUid,
        'to': peerUid,
      });
    };

    // Caller'ın offer'ını al — alan kontrolü ŞART (eski kod doğrudan
    // indeksliyordu ve eksik/bozuk offer'da NoSuchMethodError veriyordu).
    final offer = callData['offer'];
    if (offer is! Map || offer['sdp'] is! String || offer['type'] is! String) {
      debugPrint('Arama cevaplanamadı: geçersiz offer');
      await _cleanup();
      return;
    }
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'] as String, offer['type'] as String),
    );
    _remoteDescriptionSet = true;

    // Answer oluştur
    final answer = await _peerConnection!.createAnswer(_offerOptions(type));
    await _peerConnection!.setLocalDescription(answer);

    // Answer'ı + durumu kaydet
    await callDoc.update({
      'answer': {'type': answer.type, 'sdp': answer.sdp},
      'status': CallStatus.ongoing.name,
      'answeredAt': DateTime.now().toUtc().toIso8601String(),
    });

    onStatusChanged?.call(CallStatus.ongoing);

    // Caller'ın ICE adaylarını dinle
    _candidatesSub = callDoc
        .collection('candidates')
        .where('to', isEqualTo: myUid)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;
        // `_peerConnection!` çağrı kapandıktan sonra gelen bir adayda
        // null-check hatasıyla ÇÖKÜYORDU (abonelik iptali ile aday
        // teslimi arasında pencere var). Güvenli erişim + try/catch.
        try {
          _peerConnection?.addCandidate(
            RTCIceCandidate(
              data['candidate'] as String?,
              data['sdpMid'] as String?,
              (data['sdpMLineIndex'] as num?)?.toInt(),
            ),
          );
        } catch (e) {
          debugPrint('ICE adayı eklenemedi: $e');
        }
      }
    });

    // Bitiş durumunu dinle
    _callSub = callDoc.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) {
        onStatusChanged?.call(CallStatus.ended);
        await _cleanup();
        return;
      }
      final status = CallStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CallStatus.ended,
      );
      if (status == CallStatus.ended) {
        onStatusChanged?.call(CallStatus.ended);
        await _cleanup();
      }
    });
  }

  /// Gelen aramayı reddet
  Future<void> rejectCall(String callId) async {
    await _db.collection('calls').doc(callId).update({
      'status': CallStatus.rejected.name,
      'endedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await CallLogService.archive(callId, CallStatus.rejected.name);
  }

  /// Görüşmeyi bitir
  Future<void> endCall() async {
    final id = _callId;
    if (id != null) {
      await _db.collection('calls').doc(id).update({
        'status': CallStatus.ended.name,
        'endedAt': DateTime.now().toUtc().toIso8601String(),
      });
      // GECMISE YAZ: cagri gecmisi sekmesi ve cevapsiz cagri mesaji
      // buradan besleniyor (eskiden hic yazilmiyordu).
      await CallLogService.archive(id, CallStatus.ended.name);
    }
    await _cleanup();
  }

  // ─────────────────────────────────────────
  // MEDYA KONTROLLERİ
  // ─────────────────────────────────────────

  /// Mikrofonu aç/kapat
  void toggleMute(bool muted) {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !muted;
    });
  }

  /// Kamerayı aç/kapat
  void toggleCamera(bool off) {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !off;
    });
  }

  /// Ön/arka kamera değiştir
  Future<void> switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  /// Hoparlör aç/kapat
  Future<void> toggleSpeaker(bool on) async {
    if (_localStream != null) {
      await Helper.setSpeakerphoneOn(on);
    }
  }

  // ─────────────────────────────────────────
  // YARDIMCI
  // ─────────────────────────────────────────

  Future<void> _initLocalStream(CallType type) async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': type == CallType.video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    onLocalStream?.call(_localStream!);
  }

  Future<void> _createPeerConnection() async {
    // Kimlik `startCall`/`answerCall` başında ısıtıldı; burada genelde
    // önbellekten döner ve arama kurulumunu geciktirmez.
    final turn = await TurnCredentialsService.resolve();
    _relayActive = turn.hasRelay;
    _peerConnection = await createPeerConnection(turn.toRtcConfiguration());

    // Yerel track'leri ekle
    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // Uzak stream geldiğinde
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
      }
    };

    // Bağlantı durumu
    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onStatusChanged?.call(CallStatus.ended);
      }
    };

    // ⚠️ TURN ERİŞİLEMEZLİĞİ. `relay` politikasında tek aday kaynağı
    // TURN'dür; sunucu kapalı/yanlış yapılandırılmışsa ICE hiç aday
    // bulamaz ve arama "bir şekilde kurulamadı" diye görünür. Bunu
    // ayırt etmek, saatlerce yanlış yerde hata aramayı önler.
    _peerConnection!.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed &&
          _relayActive) {
        _relayUnreachable = true;
        debugPrint(
            'ICE başarısız — TURN erişilemiyor olabilir (relay politikası '
            'açık). Sunucu adresi/kimlik bilgisi ve 3478/5349 portlarını '
            'kontrol et.');
        onRelayUnreachable?.call();
      }
    };
  }

  Future<void> _cleanup() async {
    await _callSub?.cancel();
    await _candidatesSub?.cancel();
    _callSub = null;
    _candidatesSub = null;

    // KAMERA/MİKROFON KAPATMA GARANTİSİ: her adım ayrı korunur, biri
    // patlarsa diğerleri yine çalışır. Aksi halde bir istisna kameranın
    // AÇIK KALMASINA yol açabiliyordu (gizlilik açısından kabul edilemez).
    try {
      _localStream?.getTracks().forEach((t) => t.stop());
    } catch (e) {
      debugPrint('Yerel track durdurulamadı: $e');
    }
    try {
      await _localStream?.dispose();
    } catch (e) {
      debugPrint('Yerel akış kapatılamadı: $e');
    }
    // `_remoteStream` hiç dispose edilmiyordu → bellek sızıntısı.
    try {
      await _remoteStream?.dispose();
    } catch (e) {
      debugPrint('Uzak akış kapatılamadı: $e');
    }
    try {
      await _peerConnection?.close();
    } catch (e) {
      debugPrint('Bağlantı kapatılamadı: $e');
    }

    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _callId = null;
    _remoteDescriptionSet = false;
  }

  /// `dispose` asenkron temizliği BEKLEMİYORDU; kamera/mikrofon serbest
  /// bırakılmadan önce nesne çöpe gidebiliyordu.
  Future<void> dispose() => _cleanup();
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
