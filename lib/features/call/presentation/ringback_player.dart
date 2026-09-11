import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../../../core/observability/handled_error.dart';

/// ☎️ ÇALMA SESİ — "diit diit" (§4bo)
///
/// ── NEDEN SES DOSYASI YOK ──
/// Ton, çalışma anında ÜRETİLİR. Depoya doğrulayamadığım bir ikili dosya
/// koymamak için: bir `.wav`'ın içinde ne olduğunu okuyarak denetleyemem,
/// ama üreten kodu okuyabilirim. Ayrıca paket boyutu artmaz ve lisans
/// sorusu doğmaz.
///
/// ── SES NASIL OLUŞUYOR ──
/// Klasik çevir sesi: kısa iki bip, sonra sessizlik, ve tekrar. Burada
/// tek bir WAV döngüye alınır; sessizlik de tamponun içindedir, böylece
/// zamanlayıcıya gerek kalmaz — `ReleaseMode.loop` yeter.
///
/// ⚠️ Ses ÇIKIŞI ÇAĞRI KANALINA verilmez: konuşma başlayınca durdurulur.
/// Aksi hâlde ton, karşı tarafın sesiyle çakışırdı.
class RingbackPlayer {
  RingbackPlayer._();

  static AudioPlayer? _player;

  static const int _ornekHizi = 8000; // 8 kHz konuşma kalitesi yeter
  static const double _frekans = 440; // la notası — telefon tonlarına yakın
  static const int _bipMs = 180; // "diit"
  static const int _bipArasiMs = 140; // iki bip arası kısa boşluk
  static const int _sessizlikMs = 1600; // tekrar arası bekleme

  /// Çalmaya başla. Zaten çalıyorsa hiçbir şey yapmaz.
  static Future<void> basla() async {
    if (_player != null) return;
    try {
      final p = AudioPlayer();
      _player = p;
      await p.setReleaseMode(ReleaseMode.loop);
      // Çalma sesi bildirim/zil değil, ARAYÜZ sesidir: sessize alınmış
      // telefonda ısrarla ötmesin diye medya kanalını kullanır.
      await p.play(BytesSource(_wavUret()));
    } catch (e) {
      // Ses çıkmaması aramayı engellemez; sessizce vazgeç ama ÖLÇÜLEBİLİR
      // kal — "kimsede çalma sesi yok" arızası ancak böyle fark edilir.
      reportHandled('Çalma sesi başlatılamadı', e);
      _player = null;
    }
  }

  /// Durdur ve kaynakları bırak. Birden çok kez çağrılabilir.
  static Future<void> durdur() async {
    final p = _player;
    _player = null;
    if (p == null) return;
    try {
      await p.stop();
      await p.dispose();
    } catch (e) {
      reportHandled('Çalma sesi durdurulamadı', e);
    }
  }

  /// Tek döngüyü içeren 16-bit mono WAV üret.
  static Uint8List _wavUret() {
    final bip = _ornek(_bipMs, sesli: true);
    final ara = _ornek(_bipArasiMs, sesli: false);
    final bosluk = _ornek(_sessizlikMs, sesli: false);

    final pcm = <int>[...bip, ...ara, ...bip, ...bosluk];
    return _wavBasligiEkle(pcm);
  }

  /// [ms] kadar örnek: sesliyse sinüs, değilse sessizlik.
  ///
  /// Sinüs, başında ve sonunda YUMUŞATILIR (fade). Ani başlayan bir dalga
  /// hoparlörde "tık" sesi üretir; kısa bir rampa onu ortadan kaldırır.
  static List<int> _ornek(int ms, {required bool sesli}) {
    final adet = (_ornekHizi * ms / 1000).round();
    final cikti = List<int>.filled(adet, 0);
    if (!sesli) return cikti;

    final rampa = (_ornekHizi * 0.005).round(); // 5 ms
    for (var i = 0; i < adet; i++) {
      final t = i / _ornekHizi;
      var genlik = 0.35; // kulağı tırmalamayacak seviye
      if (i < rampa) {
        genlik *= i / rampa;
      } else if (i > adet - rampa) {
        genlik *= (adet - i) / rampa;
      }
      final deger = math.sin(2 * math.pi * _frekans * t) * genlik;
      cikti[i] = (deger * 32767).round().clamp(-32768, 32767);
    }
    return cikti;
  }

  /// 16-bit mono PCM'i WAV kabına koy.
  static Uint8List _wavBasligiEkle(List<int> pcm) {
    final veriBoyutu = pcm.length * 2;
    final b = BytesBuilder();

    void yaz32(int v) => b.add([
          v & 0xFF,
          (v >> 8) & 0xFF,
          (v >> 16) & 0xFF,
          (v >> 24) & 0xFF,
        ]);
    void yaz16(int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);

    b.add('RIFF'.codeUnits);
    yaz32(36 + veriBoyutu);
    b.add('WAVE'.codeUnits);
    b.add('fmt '.codeUnits);
    yaz32(16); // alt parça boyutu
    yaz16(1); // PCM
    yaz16(1); // mono
    yaz32(_ornekHizi);
    yaz32(_ornekHizi * 2); // bayt/saniye
    yaz16(2); // blok hizası
    yaz16(16); // bit derinliği
    b.add('data'.codeUnits);
    yaz32(veriBoyutu);

    final veri = Uint8List(veriBoyutu);
    final gorunum = ByteData.view(veri.buffer);
    for (var i = 0; i < pcm.length; i++) {
      gorunum.setInt16(i * 2, pcm[i], Endian.little);
    }
    b.add(veri);
    return b.toBytes();
  }
}
