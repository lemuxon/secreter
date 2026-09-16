import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../models/call_model.dart';
import '../../../../services/call_service.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../services/active_call.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../ringback_player.dart';

/// Görüşme ekranı (yeni mimari).
/// Canlı WebRTC motoru (CallService) UI-ömürlü olduğu için doğrudan
/// burada örneklenir — renderer'lar ve callback'ler bu State'e bağlı.
class CallScreen extends StatefulWidget {
  final String calleeId;
  final String calleeUsername;
  final CallType callType;
  final bool isIncoming;
  final String? incomingCallId;

  const CallScreen({
    super.key,
    required this.calleeId,
    required this.calleeUsername,
    required this.callType,
    this.isIncoming = false,
    this.incomingCallId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // ARKA PLANA ALMA: servis artik EKRANA ait degil; global oturumda yasar.
  // Ekran sadece ona baglanir; kapaninca arama DEVAM EDER.
  CallService? _callService;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  CallStatus _status = CallStatus.ringing;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _frontCamera = true;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  bool _renderersReady = false;

  /// Medya TURN relay'i üzerinden mi akıyor? (IP gizli mi?)
  bool _relayActive = false;
  bool _relayUnreachable = false;

  bool get _isVideo => widget.callType == CallType.video;

  @override
  void initState() {
    super.initState();
    ActiveCall.instance.setScreenVisible(true);
    ActiveCall.instance.addListener(_onSession);
    _initRenderers();
  }

  /// Global oturum degisince ekrani tazele (arka plandan donunce de).
  void _onSession() {
    if (!mounted) return;
    final a = ActiveCall.instance;
    setState(() {
      _status = a.status;
      if (a.localStream != null) _localRenderer.srcObject = a.localStream;
      if (a.remoteStream != null) _remoteRenderer.srcObject = a.remoteStream;
      if (a.answeredAt != null) _callDuration = a.elapsed;
      _relayActive = a.relayActive;
      _relayUnreachable = a.relayUnreachable;
    });
    // ☎️ ÇALMA SESİ (§4bo): yalnızca ÇALARKEN. Konuşma başlayınca ya da
    // arama düşünce susar — ton, karşı tarafın sesiyle çakışmamalı.
    // ⚠️ YALNIZCA ARAYAN TARAF. Gelen aramada karşı taraf zaten sistem
    // zilini duyar; üstüne bir de bu tonu çalmak iki sesin çakışması
    // demek olurdu.
    if (a.status == CallStatus.ringing && !widget.isIncoming) {
      unawaited(RingbackPlayer.basla());
    } else {
      unawaited(RingbackPlayer.durdur());
    }

    if (a.status == CallStatus.ongoing) _startDurationTimer();
    if (!a.isActive && mounted) Navigator.of(context).maybePop();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (!mounted) return;
    setState(() => _renderersReady = true);

    final active = ActiveCall.instance;

    // ZATEN DEVAM EDEN ARAMA VAR MI? (arka plandan geri donus)
    if (active.isActive) {
      _callService = active.service;
      _status = active.status;
      if (active.localStream != null) {
        _localRenderer.srcObject = active.localStream;
      }
      if (active.remoteStream != null) {
        _remoteRenderer.srcObject = active.remoteStream;
      }
      if (active.answeredAt != null) {
        _callDuration = active.elapsed;
        _startDurationTimer();
      }
      _relayActive = active.relayActive;
      _relayUnreachable = active.relayUnreachable;
      if (mounted) setState(() {});
      return;
    }

    // YENI ARAMA: global oturumu kur, sonra baslat/cevapla
    _callService = active.begin(
      peerUid: widget.calleeId,
      peerUsername: widget.calleeUsername,
      type: widget.callType,
      isIncoming: widget.isIncoming,
      callId: widget.incomingCallId,
    );

    if (widget.isIncoming && widget.incomingCallId != null) {
      await _callService!.answerCall(
        callId: widget.incomingCallId!,
        type: widget.callType,
      );
    } else {
      await _callService!.startCall(
        calleeId: widget.calleeId,
        calleeUsername: widget.calleeUsername,
        type: widget.callType,
      );
    }

    // Varsayılan hoparlör (görüntülüde açık, seslide kapalı)
    _speakerOn = _isVideo;
    await _callService!.toggleSpeaker(_speakerOn);
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDuration += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _endAndPop() async {
    _durationTimer?.cancel();
    await ActiveCall.instance.hangUp();
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusText {
    switch (_status) {
      case CallStatus.ringing:
        return widget.isIncoming
            ? context.tr('incoming_call')
            : context.tr('ringing');
      case CallStatus.ongoing:
        return _formatDuration(_callDuration);
      case CallStatus.ended:
        return context.tr('call_ended');
      case CallStatus.rejected:
        return 'Reddedildi';
      case CallStatus.missed:
        return 'Cevapsız';
    }
  }

  @override
  void dispose() {
    // Ekran kapanırken ton KESİNLİKLE sussun — arama akışı
    // beklenmedik bir yoldan biterse bile.
    unawaited(RingbackPlayer.durdur());
    _durationTimer?.cancel();
    ActiveCall.instance.removeListener(_onSession);
    ActiveCall.instance.setScreenVisible(false);
    // ONEMLI: _callService.dispose() BILEREK cagrilmiyor — ekran kapansa
    // bile arama devam etmeli. Oturum yalnizca hangUp() veya karsi taraf
    // kapatinca ActiveCall tarafindan temizlenir.
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Görüntülü: uzak video tam ekran
          if (_isVideo && _status == CallStatus.ongoing && _renderersReady)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

          // Görüntülü: kendi videom köşede
          if (_isVideo && _renderersReady && !_cameraOff)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                width: 110,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: _frontCamera,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // Sesli arama veya çalıyor: avatar + isim
          if (!_isVideo || _status != CallStatus.ongoing)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Karşı tarafın profil fotoğrafı (yoksa baş harf)
                  UserAvatar(
                    uid: widget.calleeId,
                    fallbackLetter: widget.calleeUsername.isNotEmpty
                        ? widget.calleeUsername[0].toUpperCase()
                        : '?',
                    radius: 60,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '@${widget.calleeUsername}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusText,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 14),
                  _buildPrivacyBadge(),
                ],
              ),
            ),

          // Üstte durum (görüntülü görüşme sırasında)
          if (_isVideo && _status == CallStatus.ongoing)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatDuration(_callDuration),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),

          // Görüntülü görüşmede gizlilik rozeti süre rozetinin ALTINDA
          if (_isVideo && _status == CallStatus.ongoing)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 16,
              child: _buildPrivacyBadge(),
            ),

          // Alt kontrol butonları
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  /// 🔀 BAĞLANTI TÜRÜ ROZETİ
  ///
  /// Kullanıcı, aramasının relay üzerinden mi (IP gizli) yoksa doğrudan
  /// mı (IP karşı tarafa görünür) kurulduğunu BİLMELİDİR. Numara
  /// istemeyen bir uygulamada IP, kimliğin en güçlü belirleyicilerinden
  /// biridir; bunu sessizce geçmek kullanıcıyı yanıltmak olurdu.
  ///
  /// ⚠️ Rozet artık YALNIZCA ETİKET — dokununca açılan açıklama YOK.
  ///
  /// Geçmişi: metin önce uyarı sarısıyla "IP adresin karşı tarafa
  /// görünüyor" diyordu ve "arama güvensiz" diye okunuyordu; §4ay bunu
  /// nötr bir etikete indirip ödünleşimi dokunmalı açıklamaya taşıdı.
  /// 2026-09-16'da kullanıcı açıklamayı da kaldırmayı istedi: arama
  /// ekranında rozetin üstüne gelince/ dokununca çıkan metin gürültü
  /// sayıldı.
  ///
  /// 🔴 BİLİNÇLİ KAYIP — yeni oturum bunu bilsin: TURN kurulana kadar
  /// (`TURN_KURULUMU.md`) HER arama doğrudan kurulur, yani IP karşı
  /// tarafa AÇILIR. Bu açıklama, kullanıcının bunu öğrenebileceği tek
  /// yerdi. Metinler (`call_ip_*_detail`) 16 dilde SİLİNMEDİ, yalnızca
  /// bu ekranda gösterilmiyor — geri getirmek `detail:` argümanını
  /// eklemekten ibarettir.
  /// Grup araması ekranı bu değişikliğin DIŞINDA bırakıldı: mesh'te IP
  /// tek kişiye değil aramadaki HERKESE açılıyor.
  Widget _buildPrivacyBadge() {
    // TURN yapılandırılmış ama erişilemiyor: arama hiç kurulamaz.
    // Bunu "arama başarısız" diye geçmek, sorunu saatlerce yanlış yerde
    // aratır.
    if (_relayUnreachable) {
      return _badge(
        icon: Icons.cloud_off_rounded,
        color: AppTheme.danger,
        text: context.tr('call_relay_unreachable'),
      );
    }

    // Çalma aşamasında bağlantı henüz kurulmadı; kesin olmayan bir şey
    // söylemektense hiçbir şey söyleme.
    if (_status != CallStatus.ongoing) return const SizedBox.shrink();

    return _relayActive
        ? _badge(
            icon: Icons.lock_rounded,
            color: AppTheme.secure,
            text: context.tr('call_ip_hidden'),
          )
        : _badge(
            // ⚠️ TON BİLİNÇLİ OLARAK NÖTR: eskiden uyarı sarısı + dünya
            // simgesiydi, kullanıcılar bunu "arama güvensiz" diye okuyordu.
            // Doğrudan bağlantı WebRTC'nin normal hâlidir ve ses yine
            // şifrelidir; arıza değil, bir ödünleşimdir. BİLGİ SİLİNMEDİ —
            // rozete dokununca IP'nin paylaşıldığı açıkça yazıyor.
            icon: Icons.swap_horiz_rounded,
            color: AppTheme.primary,
            text: context.tr('call_ip_visible'),
          );
  }

  Widget _badge({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute
            _circleButton(
              _muted ? Icons.mic_off : Icons.mic,
              _muted ? Colors.white24 : Colors.white12,
              () {
                setState(() => _muted = !_muted);
                _callService?.toggleMute(_muted);
              },
              small: true,
            ),
            // Hoparlör
            _circleButton(
              _speakerOn ? Icons.volume_up : Icons.volume_down,
              _speakerOn ? Colors.white24 : Colors.white12,
              () {
                setState(() => _speakerOn = !_speakerOn);
                _callService?.toggleSpeaker(_speakerOn);
              },
              small: true,
            ),
            // Video kontrolleri
            if (_isVideo) ...[
              _circleButton(
                _cameraOff ? Icons.videocam_off : Icons.videocam,
                _cameraOff ? Colors.white24 : Colors.white12,
                () {
                  setState(() => _cameraOff = !_cameraOff);
                  _callService?.toggleCamera(_cameraOff);
                },
                small: true,
              ),
              _circleButton(
                Icons.cameraswitch,
                Colors.white12,
                () {
                  setState(() => _frontCamera = !_frontCamera);
                  _callService?.switchCamera();
                },
                small: true,
              ),
            ],
          ],
        ),
        const SizedBox(height: 30),
        // Görüşmeyi bitir
        _circleButton(Icons.call_end, AppTheme.danger, _endAndPop),
      ],
    );
  }

  Widget _circleButton(IconData icon, Color bg, VoidCallback onTap,
      {bool small = false}) {
    final size = small ? 56.0 : 68.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: small ? 26 : 32),
      ),
    );
  }
}
