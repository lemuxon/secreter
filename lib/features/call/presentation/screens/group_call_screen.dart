import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/observability/handled_error.dart';
import '../../../../services/group_call_service.dart';
import '../../../../services/username_resolver.dart';
import '../../../../utils/app_theme.dart';
import '../ringback_player.dart';

/// 👥 GRUP ARAMASI EKRANI — MESH (§4bq)
///
/// Her katılımcı için ayrı bir karo. Yerel görüntü de bir karodur:
/// "benim görüntüm köşede" düzeni iki kişide anlamlıdır, N kişide
/// karolardan biri olması daha okunaklıdır.
///
/// ⚠️ MESH'İN SINIRI KULLANICIYA GÖSTERİLİR. Katılımcı sayısı arttıkça
/// her istemci N-1 akış YÜKLER; sessizce donmak yerine sınır açıkça
/// söylenir (`GroupCallService.maksKatilimci`).
class GroupCallScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;
  final bool video;

  /// Gelen arama ekranından gelindiyse KATILINACAK çağrı.
  ///
  /// Verilmezse gruba ait canlı arama aranır, yoksa yenisi açılır.
  /// Verildiğinde arama YARIŞI önlenir: kabul ile sorgu arasında çağrı
  /// değişse bile doğru belgeye katılınır.
  final String? callId;

  const GroupCallScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    this.video = false,
    this.callId,
  });

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final _servis = GroupCallService();
  final _yerelRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _uzakRenderer = {};

  MediaStream? _yerelAkis;
  bool _hazir = false;
  bool _sessiz = false;
  bool _kameraKapali = false;

  /// ⚠️ GRUP ARAMASINDA HOPARLÖR VARSAYILAN AÇIK.
  ///
  /// Birebir aramada kulaklık (ahize) çıkışı doğru varsayılandır: telefon
  /// kulağa dayanır. Grup araması odada birden çok kişiyle konuşmak
  /// içindir; ahizeden başlarsa kullanıcı "ses gelmiyor" sanır.
  bool _hoparlor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _basla();
  }

  Future<void> _basla() async {
    try {
      await _yerelRenderer.initialize();

      _yerelAkis = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.video
            ? {'facingMode': 'user', 'width': 640, 'height': 480}
            : false,
      });
      _yerelRenderer.srcObject = _yerelAkis;

      _servis.onAkislarDegisti = _akislariEsle;
      _servis.onGizlilikDegisti = () {
        if (mounted) setState(() {});
      };
      _servis.onKatilimcilar = (liste) async {
        // ☎️ ÇALMA SESİ: yalnız BEKLERKEN. İkinci kişi bağlanır
        // bağlanmaz susar — yoksa ton konuşmanın üstüne biner (§4bo).
        if (liste.length > 1) {
          await RingbackPlayer.durdur();
        }
        // Karo etiketleri uid değil AD göstersin; çözüm önbelleğe
        // alındıktan sonra yeniden çizilir.
        await UsernameResolver.warm(liste);
        if (mounted) setState(() {});
      };

      await _servis.baslatVeyaKatil(
        chatId: widget.chatId,
        localStream: _yerelAkis!,
        video: widget.video,
        callId: widget.callId,
      );

      // ⚠️ Ekran, arama kurulurken KAPATILMIŞ olabilir. `dispose`
      // çağrıldıysa oradaki `ayril()` bu satırdan ÖNCE çalışmıştır ve
      // hiçbir şeyi kapatamaz — arama öksüz kalır, grup "konuşuluyor"
      // görünmeye devam ederdi.
      if (!mounted) {
        await _servis.ayril();
        return;
      }

      await _hoparloruUygula();
      // Aramayı ilk açan tek başınadır: beklerken çalma sesi duyar.
      // Var olan bir aramaya KATILAN duymaz — orada zaten konuşuluyor.
      if (_servis.yeniAcildi) await RingbackPlayer.basla();
      if (mounted) setState(() => _hazir = true);
    } catch (e, s) {
      reportHandled('Grup araması başlatılamadı', e, stack: s);
      if (!mounted) return;
      setState(() => _hata = _hataMetni(e));
    }
  }

  /// Hatayı kullanıcının anlayacağı cümleye çevir.
  ///
  /// Üç durum BİRBİRİNDEN AYRI söylenir; hepsine "başlatılamadı" demek
  /// kullanıcıyı yeniden denemeye iter ve aynı duvara çarptırır.
  String _hataMetni(Object e) {
    if (e is! StateError) return context.tr('group_call_failed');
    switch (e.message) {
      case 'arama_dolu':
        return context.tr('group_call_full');
      case 'arama_bitti':
        return context.tr('group_call_ended');
      default:
        return context.tr('group_call_failed');
    }
  }

  /// Uzak akışlar değişti — eksik renderer'ları kur, fazlalıkları at.
  Future<void> _akislariEsle(Map<String, MediaStream> akislar) async {
    for (final giris in akislar.entries) {
      var r = _uzakRenderer[giris.key];
      if (r == null) {
        r = RTCVideoRenderer();
        await r.initialize();
        _uzakRenderer[giris.key] = r;
      }
      r.srcObject = giris.value;
    }
    for (final uid in _uzakRenderer.keys.toList()) {
      if (!akislar.containsKey(uid)) {
        final r = _uzakRenderer.remove(uid);
        r?.srcObject = null;
        await r?.dispose();
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _ayril() async {
    await _servis.ayril();
    if (mounted) Navigator.of(context).pop();
  }

  void _sessizDegistir() {
    final track = _yerelAkis?.getAudioTracks().firstOrNull;
    if (track == null) return;
    setState(() => _sessiz = !_sessiz);
    track.enabled = !_sessiz;
  }

  /// Ses çıkışını uygula. Başarısızlık aramayı düşürmez ama sessiz de
  /// geçilmez: "kimse duymuyor" arızası ancak böyle görülebilir.
  Future<void> _hoparloruUygula() async {
    try {
      await Helper.setSpeakerphoneOn(_hoparlor);
    } catch (e) {
      reportHandled('Grup araması: hoparlör ayarlanamadı', e);
    }
  }

  void _hoparlorDegistir() {
    setState(() => _hoparlor = !_hoparlor);
    _hoparloruUygula();
  }

  void _kameraDegistir() {
    final track = _yerelAkis?.getVideoTracks().firstOrNull;
    if (track == null) return;
    setState(() => _kameraKapali = !_kameraKapali);
    track.enabled = !_kameraKapali;
  }

  @override
  void dispose() {
    // Ekran kapanınca aramadan AYRIL. Birebir aramanın aksine grup
    // araması arka planda sürdürülmüyor: mesh'te ekranı kapatan
    // katılımcı diğerlerinin yükleme bant genişliğini tüketmeye devam
    // ederdi.
    _servis.ayril();
    RingbackPlayer.durdur();
    _yerelRenderer.srcObject = null;
    _yerelRenderer.dispose();
    for (final r in _uzakRenderer.values) {
      r.srcObject = null;
      r.dispose();
    }
    _yerelAkis?.getTracks().forEach((t) => t.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        title: Text(widget.chatTitle),
      ),
      body: SafeArea(
        child: _hata != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_hata!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ),
              )
            : Column(
                children: [
                  _gizlilikRozeti(),
                  Expanded(child: _karolar()),
                  _kontroller(),
                ],
              ),
      ),
    );
  }

  /// 🔒 GİZLİLİK ROZETİ — grup aramasının kendi metniyle.
  ///
  /// ── NEDEN BİREBİR ARAMANIN METNİ YETMEZ ──
  /// Oradaki açıklama "IP adresin KARŞI TARAFA görünür" diyor; iki kişi
  /// için doğru. Mesh'te karşı taraf tek kişi değil, **aramadaki
  /// herkestir**: her katılımcı diğer herkese doğrudan bağlanır, yani
  /// IP'n aramadaki N-1 kişiye açılır. Aynı cümleyi grupta kullanmak,
  /// ödünleşimi olduğundan küçük göstermek olurdu.
  ///
  /// ⚠️ Rozetin kendisi kısa ve NÖTR (§4ay'nin dersi): doğrudan bağlantı
  /// WebRTC'nin normal hâlidir ve ses/görüntü her hâlükârda şifrelidir.
  /// Ödünleşim dokununca açılır — metin YUMUŞATILDI, bilgi SİLİNMEDİ.
  /// `test/features/call/ip_disclosure_test.dart` 16 dilde açıklamanın
  /// hem IP'den hem de "herkes" boyutundan söz etmesini zorunlu kılar.
  Widget _gizlilikRozeti() {
    if (_servis.relayErisilemez) {
      return _rozet(
        ikon: Icons.cloud_off_rounded,
        renk: AppTheme.danger,
        metin: context.tr('call_relay_unreachable'),
      );
    }
    // Henüz kimse bağlanmadıysa bağlantının türü BELLİ DEĞİL; kesin
    // olmayan bir şey söylemektense hiçbir şey söyleme.
    if (_uzakRenderer.isEmpty) return const SizedBox.shrink();

    return _servis.relayAktif
        ? _rozet(
            ikon: Icons.lock_rounded,
            renk: AppTheme.secure,
            metin: context.tr('call_ip_hidden'),
            detay: context.tr('group_call_ip_hidden_detail'),
          )
        : _rozet(
            ikon: Icons.swap_horiz_rounded,
            renk: AppTheme.primary,
            metin: context.tr('call_ip_visible'),
            detay: context.tr('group_call_ip_visible_detail'),
          );
  }

  Widget _rozet({
    required IconData ikon,
    required Color renk,
    required String metin,
    String? detay,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: GestureDetector(
        onTap: detay == null ? null : () => _detayGoster(metin, detay),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ikon, size: 15, color: renk),
              const SizedBox(width: 6),
              Flexible(
                child: Text(metin,
                    style: TextStyle(color: renk, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              if (detay != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.info_outline, size: 13, color: renk),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Rozetin tam açıklaması. Rozet tek satıra sığmak zorunda; gerçek
  /// ödünleşimi anlatacak yer yok. Metni kısaltıp açıklamayı buraya
  /// almak, kısaltıp yok saymaktan iyidir.
  void _detayGoster(String baslik, String metin) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(baslik,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Text(metin,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('ok')),
          ),
        ],
      ),
    );
  }

  Widget _karolar() {
    if (!_hazir) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }

    final karolar = <Widget>[
      _karo(_yerelRenderer, context.tr('you_word'), yerel: true),
      for (final g in _uzakRenderer.entries) _karo(g.value, '', uid: g.key),
    ];

    // Sütun sayısı katılımcıyla büyür: 1-2 kişi tek sütun, sonrası ikili.
    final sutun = karolar.length <= 2 ? 1 : 2;
    return GridView.count(
      crossAxisCount: sutun,
      padding: const EdgeInsets.all(8),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: karolar,
    );
  }

  /// Karo etiketi: çözülmüş kullanıcı adı, yoksa kısaltılmış uid.
  ///
  /// ⚠️ `substring(0, 4)` DOĞRUDAN ÇAĞRILMAZ: uid dört karakterden
  /// kısaysa (test/eski hesap) ekran çizilirken çöker.
  String _ad(String uid) {
    final ad = UsernameResolver.cached(uid);
    if (ad != null && ad.isNotEmpty) return '@$ad';
    if (uid.isEmpty) return '…';
    return '@${uid.substring(0, uid.length < 4 ? uid.length : 4)}…';
  }

  Widget _karo(RTCVideoRenderer r, String etiket,
      {bool yerel = false, String? uid}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: AppTheme.surface,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.video)
              RTCVideoView(r,
                  mirror: yerel,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            else
              const Center(
                child:
                    Icon(Icons.person, size: 48, color: AppTheme.textSecondary),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  etiket.isNotEmpty ? etiket : _ad(uid ?? ''),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kontroller() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _dugme(_sessiz ? Icons.mic_off : Icons.mic, Colors.white12,
              _sessizDegistir),
          _dugme(_hoparlor ? Icons.volume_up : Icons.volume_down,
              _hoparlor ? Colors.white24 : Colors.white12, _hoparlorDegistir),
          if (widget.video)
            _dugme(_kameraKapali ? Icons.videocam_off : Icons.videocam,
                Colors.white12, _kameraDegistir),
          _dugme(Icons.call_end, AppTheme.danger, _ayril),
        ],
      ),
    );
  }

  Widget _dugme(IconData ikon, Color renk, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
        child: Icon(ikon, color: Colors.white),
      ),
    );
  }
}
