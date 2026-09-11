import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/call_model.dart';
import '../../features/call/presentation/screens/call_screen.dart';
import '../../core/i18n/app_localizations.dart';
import '../../services/active_call.dart';
import '../../utils/app_theme.dart';
import '../../main.dart';

/// 📞 DEVAM EDEN ARAMA ŞERİDİ
///
/// Arama ekranından çıkıldığında (geri tuşu / küçült) uygulamanın en
/// üstünde ince yeşil bir şerit belirir: "Arama sürüyor · 01:23".
/// Dokununca arama ekranına geri dönülür.
///
/// Şerit yalnızca aktif arama VARSA ve arama ekranı GÖRÜNMÜYORSA çizilir.
class ActiveCallBanner extends StatefulWidget {
  final Widget child;
  const ActiveCallBanner({super.key, required this.child});

  @override
  State<ActiveCallBanner> createState() => _ActiveCallBannerState();
}

class _ActiveCallBannerState extends State<ActiveCallBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    ActiveCall.instance.addListener(_onChange);
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    _syncTicker();
  }

  /// Süre sayacı yalnızca şerit görünürken çalışsın (pil dostu).
  void _syncTicker() {
    final a = ActiveCall.instance;
    final needed = a.isActive && !a.screenVisible;
    if (needed && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needed && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    ActiveCall.instance.removeListener(_onChange);
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _reopen(BuildContext context) {
    final a = ActiveCall.instance;
    if (!a.isActive) return;
    // KOK NEDEN: Bu widget MaterialApp.builder icinde, yani Navigator'in
    // USTUNDE yasiyor. Navigator.of(context) buradan uygulama
    // navigatorunu BULAMAZ (dokunma hicbir sey yapmiyordu).
    // Cozum: main.dart'taki kok navigator anahtarini kullan.
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => CallScreen(
        calleeId: a.peerUid ?? '',
        calleeUsername: a.peerUsername ?? '',
        callType: a.type,
        isIncoming: a.isIncoming,
        incomingCallId: a.callId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final a = ActiveCall.instance;
    final show = a.isActive && !a.screenVisible;
    if (!show) return widget.child;

    final label = a.status == CallStatus.ongoing
        ? _fmt(a.elapsed)
        : context.tr('ringing');

    return Column(
      children: [
        Material(
          color: AppTheme.secure,
          child: SafeArea(
            bottom: false,
            child: InkWell(
              onTap: () => _reopen(context),
              child: SizedBox(
                height: 34,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(a.isVideo ? Icons.videocam : Icons.call,
                        size: 15, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '${context.tr('call_ongoing')} · $label',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.keyboard_arrow_down,
                        size: 16, color: Colors.white70),
                    const SizedBox(width: 4),
                    // GÜVENLİK AĞI: Beklenmedik bir durumda (karşı taraf
                    // kapattı ama haber ulaşmadı gibi) şerit takılı
                    // kalabilir. Kullanıcı her zaman buradan bitirebilir.
                    InkWell(
                      onTap: () => ActiveCall.instance.hangUp(),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child:
                            Icon(Icons.call_end, size: 17, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
