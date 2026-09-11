import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/call/call_document.dart';
import '../core/observability/handled_error.dart';
import 'auth_service.dart';
import 'turn_credentials_service.dart';

/// 👥 GRUP ARAMASI — MESH (§4bq)
///
/// ── NEDEN MESH, NEDEN SFU DEĞİL ──
/// Kullanıcının kararı. Mesh'te her katılımcı DİĞER HERKESE ayrı bir
/// eş bağlantı kurar: sunucu maliyeti yoktur ve medya hiçbir sunucudan
/// geçmez — uçtan uca şifreleme, birebir aramadaki ile aynı güçte kalır.
/// Bedeli ölçeklenmedir: N kişide her istemci N-1 akış YÜKLER.
/// Pratikte 4-5 kişiden sonra yükleme bant genişliği tükenir; bu yüzden
/// [maksKatilimci] ile sınırlandırılmıştır.
///
/// ── İKİ LİSTE, İKİ FARKLI SORU ──
/// `participants` = ÇAĞRININ TARAFLARI → grubun tüm üyeleri.
///   Yetki (`callParty()`) ve "gelen arama" sorgusu buna bakar; yani
///   arama başlayınca herkesin telefonu ÇALAR. Bu, gelen arama yolunun
///   hiç değiştirilmeden grup aramasında da çalışmasını sağlar.
/// `joinedIds`    = KABUL EDİP BAĞLANANLAR → mesh yalnızca bunlara eş
///   bağlantı açar. Karıştırılırsa arama başlar başlamaz henüz cevap
///   vermemiş herkese bağlantı kurulmaya çalışılırdı.
///
/// ── ALTYAPININ ZATEN HAZIR OLAN KISMI ──
/// Sinyalleşme şeması ve güvenlik kuralları N kişiye göre yazılmıştı:
///   • `calls/{id}.participants` — yetkinin TEK kaynağı (`callParty()`),
///   • `candidates` alt koleksiyonu `from`/`to` taşır ve kural adayı
///     yalnızca o ikisine açar. Yani A, B↔C'nin IP adreslerini GÖREMEZ.
/// Eksik olan tek şey, offer/answer'ın çağrı belgesinde TEK alan olarak
/// durmasıydı — iki kişiye çakılıydı. Bu servis onun yerine adresli bir
/// `sdp` alt koleksiyonu kullanır.
///
/// ── ÇAKIŞMA (GLARE) NASIL ÖNLENİYOR ──
/// İki taraf aynı anda offer üretirse bağlantı kurulamaz. Burada
/// pazarlık YOK, deterministik kural var: bir çift için **uid'i
/// sözlükbilimsel olarak KÜÇÜK olan** taraf offer üretir, diğeri bekler.
/// Her iki istemci de aynı sonuca varır, mesajlaşmaya gerek kalmaz.
class GroupCallService {
  GroupCallService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Mesh'in pratik sınırı. Her istemci N-1 akış yüklediği için bunun
  /// üstünde görüntü donar; sessizce bozulmaktansa açıkça reddedilir.
  static const int maksKatilimci = 5;

  /// Bir grup araması ne kadar süre "canlı" sayılır?
  ///
  /// ⚠️ ZOMBİ ARAMA KORUMASI. Grup araması konuşma boyunca `ringing`
  /// kalır (geç katılanlar bulabilsin diye). Son kişi ayrılırken
  /// `ended` yazar — ama uygulama öldürülürse o yazma hiç olmaz.
  /// Süzgeç olmasaydı grup, sonsuza dek "çalan" bir aramaya takılır;
  /// her üye uygulamayı her açtığında gelen arama ekranı açılırdı.
  static const Duration canliSuresi = Duration(hours: 4);

  /// Bir çift için offer'ı KİM üretir? Küçük uid.
  ///
  /// Deterministik olması şart: iki istemci de aynı cevabı vermezse ya
  /// iki offer çarpışır ya da hiç offer üretilmez.
  static bool teklifiBenVeririm(String benim, String karsi) =>
      benim.compareTo(karsi) < 0;

  /// Bu çağrı dokümanı hâlâ katılınabilir bir grup araması mı?
  ///
  /// Ölçüt ortak şema dosyasındadır: gelen arama süzgeci de AYNI kararı
  /// vermek zorunda (bkz. [grupCagrisiCanli]).
  static bool cagriCanli(Map<String, dynamic> veri, {DateTime? simdi}) =>
      grupCagrisiCanli(veri, simdi: simdi, canliSuresi: canliSuresi);

  String? _callId;
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _baglantilar = {};
  final Map<String, MediaStream> _uzakAkislar = {};

  /// ⚠️ EŞ KURMA YARIŞI. `_esKur` İKİ yerden çağrılıyor: katılımcı
  /// listesi dinleyicisinden ve gelen SDP'den. `createPeerConnection`
  /// beklenirken ikinci çağrı gelirse aynı kişi için İKİ bağlantı
  /// kurulur; haritada biri kalır, diğeri kapatılmadan sızar ve karşı
  /// tarafa iki teklif gider — bağlantı hiç kurulmaz.
  final Set<String> _kuruluyor = {};

  StreamSubscription? _katilimciSub;
  StreamSubscription? _sdpSub;
  StreamSubscription? _adaySub;

  /// Uzak akış eklendi/çıktı — arayüz karoları buna göre çizer.
  void Function(Map<String, MediaStream> akislar)? onAkislarDegisti;

  /// Bağlı katılımcı listesi değişti (biri katıldı/ayrıldı).
  void Function(List<String> katilimcilar)? onKatilimcilar;

  /// Gizlilik durumu değişti — rozet yeniden çizilsin.
  void Function()? onGizlilikDegisti;

  /// 🔒 MEDYA AKTARMA SUNUCUSU ÜZERİNDEN Mİ AKIYOR? (IP gizli mi?)
  ///
  /// ⚠️ MESH'TE BU SORU BİREBİR ARAMADAKİNDEN AĞIRDIR. Doğrudan
  /// bağlantıda IP adresin karşı tarafa açılır; grup aramasında karşı
  /// taraf TEK kişi değil, **aramadaki herkestir**. Kullanıcı bunu
  /// görebilmeli — arayüz rozeti buna bakar.
  bool _relayAktif = false;
  bool get relayAktif => _relayAktif;

  /// TURN yapılandırılmış ama erişilemiyor: bağlantı hiç kurulamaz.
  /// "Arama bir şekilde olmadı" demek, sorunu yanlış yerde aratır.
  bool _relayErisilemez = false;
  bool get relayErisilemez => _relayErisilemez;

  /// Bu çağrıyı BEN mi açtım (yoksa var olana mı katıldım)?
  ///
  /// Çalma sesi buna bakar: katılan biri zaten konuşan bir aramaya
  /// giriyordur, tonu kısa bir an bile duymamalı.
  bool _yeniAcildi = false;
  bool get yeniAcildi => _yeniAcildi;

  String? get callId => _callId;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get uzakAkislar => Map.unmodifiable(_uzakAkislar);

  DocumentReference<Map<String, dynamic>> get _cagri =>
      _db.collection('calls').doc(_callId);

  /// SDP belgesi kimliği — YÖNLÜ. `a__b`, a'dan b'ye olan teklif/yanıttır.
  static String _sdpId(String from, String to) => '${from}__$to';

  // ─────────────────────────────────────────
  // BAŞLATMA / KATILMA
  // ─────────────────────────────────────────

  /// Grup aramasını başlat (ya da var olana katıl).
  ///
  /// [chatId] grubun sohbet kimliği; aynı gruba ikinci bir arama
  /// açılmasın diye çağrı belgesi bu kimlikle ilişkilendirilir.
  /// [callId] verilirse (gelen arama ekranından kabul) doğrudan o
  /// aramaya katılınır.
  Future<String> baslatVeyaKatil({
    required String chatId,
    required MediaStream localStream,
    bool video = false,
    String? callId,
  }) async {
    final ben = AuthService.currentUid;
    if (ben == null) throw StateError('oturum_yok');

    _localStream = localStream;

    // Aynı gruba CANLI bir arama var mı? Varsa ona katıl.
    final mevcut = callId != null
        ? await _db.collection('calls').doc(callId).get()
        : await _canliCagriyiBul(chatId, ben);

    if (mevcut != null && mevcut.exists && cagriCanli(mevcut.data()!)) {
      _callId = mevcut.id;
      final bagli =
          List<String>.from(mevcut.data()![CallFields.joinedIds] ?? const []);
      if (!bagli.contains(ben) && bagli.length >= maksKatilimci) {
        _localStream = null;
        throw StateError('arama_dolu');
      }
      _yeniAcildi = false;
      await _cagri.update({
        CallFields.joinedIds: FieldValue.arrayUnion([ben]),
      });
    } else if (callId != null) {
      // ⚠️ "KABUL ET"E BASILDI AMA ARAMA BİTMİŞ.
      //
      // Buradan yeni bir arama AÇILMAZ. Açılsaydı, gelen aramayı kabul
      // eden kişi farkında olmadan ARAYAN olur ve TÜM GRUBUN telefonu
      // çalardı — kullanıcının yaptığı tek şey "kabul et"e basmaktı.
      _localStream = null;
      throw StateError('arama_bitti');
    } else {
      _yeniAcildi = true;
      // Ölü/eskimiş bir arama bulunduysa kapat ki sorgu ona takılmasın.
      if (mevcut != null && mevcut.exists) {
        try {
          await mevcut.reference.update({CallFields.status: 'ended'});
        } catch (e) {
          reportHandled('Eskimiş grup araması kapatılamadı', e);
        }
      }
      final uyeler = await _grupUyeleri(chatId);
      _callId = _db.collection('calls').doc().id;
      // Şema ortak dosyadan gelir; alan adları burada ELLE YAZILMAZ.
      await _cagri.set(buildGroupCallDocument(
        id: _callId!,
        callerId: ben,
        groupChatId: chatId,
        // ⚠️ Grubun TÜM üyeleri: yetki + "gelen arama" sorgusu buna
        // bakar. Kural da bu listeyi grubun üyeleriyle sınırlar.
        participants: uyeler,
        joinedIds: [ben],
        type: video ? 'video' : 'audio',
        createdAt: DateTime.now().toUtc(),
      ));
    }

    _dinlemeyeBasla(ben);
    return _callId!;
  }

  /// Gruba ait canlı aramayı bul.
  ///
  /// ⚠️⚠️ `participants` KISITI KALDIRILAMAZ — süsleme değil, İZNİN
  /// KENDİSİ.
  ///
  /// Firestore'da `list` kuralı dönen belgelere tek tek bakmaz; sorgunun
  /// yalnızca izinli belgeleri döndüreceğini SORGU KISITLARINDAN
  /// kanıtlamak zorundadır. `callParty()` katılımcı dizisine baktığı
  /// için, sorguda o dizi üzerinde bir kısıt yoksa kanıtlanamaz ve
  /// sorgunun TAMAMI reddedilir — kullanıcı çağrının tarafı olsa bile.
  ///
  /// Emülatörde ölçüldü: bu satır olmadan sorgu `permission-denied`
  /// veriyor ve ekranda "Grup araması başlatılamadı" çıkıyor.
  /// (`test/rules/firestore.rules.test.js` → "katılımcı kısıtı OLMADAN
  /// sorgu REDDEDİLİR")
  Future<DocumentSnapshot<Map<String, dynamic>>?> _canliCagriyiBul(
      String chatId, String ben) async {
    final snap = await _db
        .collection('calls')
        .where(CallFields.groupChatId, isEqualTo: chatId)
        .where(CallFields.status, isEqualTo: 'ringing')
        .where(CallFields.participants, arrayContains: ben)
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first;
  }

  /// Grubun üye listesi — çağrının `participants` alanını doldurur.
  ///
  /// Boş dönerse çağrıyı açan en azından kendini listeye koyar; aksi
  /// hâlde kural `create`i reddeder ve arama hiç başlamazdı.
  Future<List<String>> _grupUyeleri(String chatId) async {
    final ben = AuthService.currentUid!;
    try {
      final d = await _db.collection('chats').doc(chatId).get();
      final ids = (d.data()?['memberIds'] as List?)
              ?.map((e) => e.toString())
              .where((u) => u.isNotEmpty)
              .toList() ??
          <String>[];
      if (!ids.contains(ben)) ids.add(ben);
      return ids;
    } catch (e) {
      reportHandled('Grup üyeleri okunamadı', e);
      return [ben];
    }
  }

  /// Dinleyicileri kur.
  ///
  /// ⚠️ [ben] PARAMETRE OLARAK GELİR, `AuthService.currentUid`ten
  /// okunmaz. Sorgu kurulurken değer bir an null olsaydı
  /// `where('to', ==, null)` HİÇBİR ŞEYLE eşleşmez ve sinyalleşme
  /// hatasız biçimde ölürdü (§4bd/§4bh ile aynı sınıf: doğru değeri
  /// YANLIŞ ANDA okumak).
  void _dinlemeyeBasla(String ben) {
    // 1) BAĞLI KATILIMCILAR — kim geldi, kim gitti.
    _katilimciSub = _cagri.snapshots().listen((snap) async {
      final veri = snap.data();
      if (veri == null) return;
      final liste = List<String>.from(veri[CallFields.joinedIds] ?? const []);
      onKatilimcilar?.call(liste);

      // Yeni katılanlara bağlan.
      for (final uid in liste) {
        if (uid == ben || _baglantilar.containsKey(uid)) continue;
        await _esKur(uid);
      }

      // Ayrılanların bağlantısını kapat.
      for (final uid in _baglantilar.keys.toList()) {
        if (!liste.contains(uid)) await _esKapat(uid);
      }
    });

    // 2) BANA GELEN SDP — teklif ya da yanıt.
    _sdpSub = _cagri
        .collection('sdp')
        .where('to', isEqualTo: ben)
        .snapshots()
        .listen((snap) async {
      for (final d in snap.docChanges) {
        if (d.type == DocumentChangeType.removed) continue;
        await _sdpIsle(d.doc.data()!);
      }
    });

    // 3) BANA GELEN ICE ADAYLARI.
    _adaySub = _cagri
        .collection('candidates')
        .where('to', isEqualTo: ben)
        .snapshots()
        .listen((snap) async {
      for (final d in snap.docChanges) {
        if (d.type != DocumentChangeType.added) continue;
        final veri = d.doc.data()!;
        final pc = _baglantilar[veri['from']];
        if (pc == null) continue;
        try {
          await pc.addCandidate(RTCIceCandidate(
            veri['candidate'] as String?,
            veri['sdpMid'] as String?,
            (veri['sdpMLineIndex'] as num?)?.toInt(),
          ));
        } catch (e) {
          reportHandled('Grup araması: aday eklenemedi', e);
        }
      }
    });
  }

  // ─────────────────────────────────────────
  // EŞ BAĞLANTI
  // ─────────────────────────────────────────

  Future<void> _esKur(String karsiUid) async {
    final ben = AuthService.currentUid;
    if (ben == null || _callId == null) return;
    if (_baglantilar.containsKey(karsiUid) || _kuruluyor.contains(karsiUid)) {
      return;
    }
    _kuruluyor.add(karsiUid);
    // Çağrı belgesi ŞİMDİ yakalanır: `ayril()` sonrası `_callId` null
    // olursa `_cagri` getter'ı RASTGELE bir belgeye işaret eder ve geç
    // gelen bir ICE adayı oraya yazılırdı.
    final cagri = _cagri;
    try {
      final turn = await TurnCredentialsService.resolve();
      if (turn.hasRelay != _relayAktif) {
        _relayAktif = turn.hasRelay;
        onGizlilikDegisti?.call();
      }
      final pc = await createPeerConnection(turn.toRtcConfiguration());
      _baglantilar[karsiUid] = pc;

      _localStream?.getTracks().forEach((t) => pc.addTrack(t, _localStream!));

      pc.onTrack = (event) {
        if (event.streams.isEmpty) return;
        _uzakAkislar[karsiUid] = event.streams[0];
        onAkislarDegisti?.call(uzakAkislar);
      };

      pc.onIceCandidate = (c) {
        // Adres YAZILIR: kural adayı yalnızca bu ikisine açar.
        cagri.collection('candidates').add({
          ...c.toMap(),
          'from': ben,
          'to': karsiUid,
        });
      };

      pc.onConnectionState = (s) {
        if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          reportHandled(
              'Grup araması: eş bağlantı düştü', StateError('peer_failed'),
              context: {'peer': karsiUid});
        }
      };

      // ⚠️ TURN ERİŞİLEMEZLİĞİ (birebir aramadaki ile aynı ayrım).
      // `relay` politikasında tek aday kaynağı TURN'dür; sunucu
      // kapalıysa ICE hiç aday bulamaz ve arama "bir şekilde kurulamadı"
      // diye görünür. Ayırt edilmezse sorun saatlerce yanlış yerde
      // aranır.
      pc.onIceConnectionState = (s) {
        if (s == RTCIceConnectionState.RTCIceConnectionStateFailed &&
            _relayAktif &&
            !_relayErisilemez) {
          _relayErisilemez = true;
          onGizlilikDegisti?.call();
        }
      };

      // ── KİM TEKLİF EDER ──
      // Deterministik: küçük uid. Diğer taraf hiçbir şey yapmaz, gelen
      // teklifi bekler. Pazarlık mesajı gerekmez.
      if (teklifiBenVeririm(ben, karsiUid)) {
        final offer = await pc.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true,
        });
        await pc.setLocalDescription(offer);
        await cagri.collection('sdp').doc(_sdpId(ben, karsiUid)).set({
          'from': ben,
          'to': karsiUid,
          'type': offer.type,
          'sdp': offer.sdp,
        });
      }
    } catch (e, s) {
      reportHandled('Grup araması: eş kurulamadı', e, stack: s);
      await _esKapat(karsiUid);
    } finally {
      _kuruluyor.remove(karsiUid);
    }
  }

  Future<void> _sdpIsle(Map<String, dynamic> veri) async {
    final ben = AuthService.currentUid;
    final karsi = (veri['from'] ?? '').toString();
    final tip = (veri['type'] ?? '').toString();
    final sdp = veri['sdp'];
    if (ben == null || karsi.isEmpty || sdp is! String) return;
    if (_callId == null) return; // aramadan çıkıldı; geç gelen SDP
    final cagri = _cagri;

    var pc = _baglantilar[karsi];
    if (pc == null) {
      // Teklif, katılımcı listesinden ÖNCE gelebilir.
      await _esKur(karsi);
      pc = _baglantilar[karsi];
      if (pc == null) return;
    }

    try {
      await pc.setRemoteDescription(RTCSessionDescription(sdp, tip));

      if (tip == 'offer') {
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await cagri.collection('sdp').doc(_sdpId(ben, karsi)).set({
          'from': ben,
          'to': karsi,
          'type': answer.type,
          'sdp': answer.sdp,
        });
      }
    } catch (e, s) {
      reportHandled('Grup araması: SDP işlenemedi', e, stack: s);
    }
  }

  Future<void> _esKapat(String uid) async {
    final pc = _baglantilar.remove(uid);
    _uzakAkislar.remove(uid);
    onAkislarDegisti?.call(uzakAkislar);
    try {
      await pc?.close();
    } catch (_) {
      // kapanış hatası akışı etkilemez
    }
  }

  // ─────────────────────────────────────────
  // AYRILMA
  // ─────────────────────────────────────────

  /// Aramadan ayrıl: kendini bağlılar listesinden çıkar, eşleri kapat.
  ///
  /// ⚠️ `participants` DOKUNULMAZ — o, grubun üye listesidir. Çıkarılsa
  /// kişi aramayı bir daha göremez ve geri katılamazdı.
  ///
  /// ⚠️ Son kişi çıkınca çağrı `ended` işaretlenir. Aksi hâlde
  /// `groupChatId` sorgusu o boş aramayı "açık" görür ve gruba yeni
  /// arama başlatılamazdı.
  Future<void> ayril() async {
    final ben = AuthService.currentUid;
    await _katilimciSub?.cancel();
    await _sdpSub?.cancel();
    await _adaySub?.cancel();

    for (final uid in _baglantilar.keys.toList()) {
      await _esKapat(uid);
    }
    _kuruluyor.clear();

    if (_callId != null && ben != null) {
      try {
        final snap = await _cagri.get();
        final kalan =
            List<String>.from(snap.data()?[CallFields.joinedIds] ?? const [])
              ..remove(ben);
        await _cagri.update({
          CallFields.joinedIds: kalan,
          if (kalan.isEmpty) CallFields.status: 'ended',
          if (kalan.isEmpty)
            CallFields.endedAt: DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        reportHandled('Grup aramasından ayrılırken hata', e);
      }
    }
    _callId = null;
    _localStream = null;
  }
}
