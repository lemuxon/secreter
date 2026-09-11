import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'attachment_crypto.dart';
import '../observability/handled_error.dart';

/// 📥 ŞİFRELİ MEDYA ÖNBELLEĞİ
///
/// Şifreli ekler doğrudan `Image.network`/`VideoPlayer` ile açılamaz —
/// önce indirilip ÇÖZÜLMESİ gerekir. Bu sınıf indirir, çözer, uygulamanın
/// özel dizinine yazar ve yolu döndürür.
///
/// ── GİZLİLİK ──
/// Çözülmüş dosyalar `getApplicationSupportDirectory()` altına yazılır:
/// bu dizin uygulamaya özeldir, galeriye/medya tarayıcısına DÜŞMEZ ve
/// `allowBackup=false` sayesinde buluta yedeklenmez. [clearAll] çıkışta
/// ve panik modunda çağrılır.
///
/// ── EŞZAMANLILIK ──
/// Aynı ek birden çok widget tarafından aynı anda istenebilir (liste +
/// tam ekran). Aynı URL için tek indirme yapılır; diğerleri onu bekler.
class SecureMediaCache {
  SecureMediaCache._();
  static final SecureMediaCache instance = SecureMediaCache._();

  static const _dirName = 'secure_media';

  /// Devam eden indirmeler — aynı dosya iki kez indirilmesin.
  final Map<String, Future<File>> _inFlight = {};

  Directory? _dir;

  Future<Directory> _cacheDir() async {
    final existing = _dir;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/$_dirName');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  /// URL için kararlı yerel dosya adı (URL'i diske YAZMAZ).
  String _fileNameFor(String url, String? ext) {
    final hash = sha256.convert(utf8.encode(url)).toString().substring(0, 32);
    return ext == null || ext.isEmpty ? hash : '$hash.$ext';
  }

  /// Şifreli eki indir + çöz + önbelleğe al. Yerel dosyayı döndürür.
  ///
  /// [key] null ise dosya ŞİFRESİZDİR (eski mesajlar) — yalnızca indirilir.
  Future<File> resolve(String url, {String? key, String? ext}) {
    final cacheKey = '$url|${key ?? ''}';
    final existing = _inFlight[cacheKey];
    if (existing != null) return existing;

    final job = _resolve(url, key, ext).whenComplete(() {
      _inFlight.remove(cacheKey);
    });
    _inFlight[cacheKey] = job;
    return job;
  }

  Future<File> _resolve(String url, String? key, String? ext) async {
    final dir = await _cacheDir();
    final file = File('${dir.path}/${_fileNameFor(url, ext)}');

    // Zaten çözülmüş ve boş değilse tekrar indirme.
    if (await file.exists() && await file.length() > 0) return file;

    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw HttpException('Medya indirilemedi: ${res.statusCode}',
          uri: Uri.parse(url));
    }

    Uint8List bytes = res.bodyBytes;
    if (key != null && key.isNotEmpty) {
      // Anahtar yanlışsa/dosya kurcalandıysa BURASI fırlatır — sessizce
      // bozuk görüntü göstermeyiz.
      bytes = await AttachmentCrypto.decryptBytes(bytes, key);
    }

    // Yarım yazılmış dosya "geçerli önbellek" sanılmasın: önce geçiciye
    // yaz, sonra atomik olarak taşı.
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
    return file;
  }

  /// Tek bir ekin önbelleğini sil (mesaj silinince).
  Future<void> evict(String url, {String? ext}) async {
    try {
      final dir = await _cacheDir();
      final f = File('${dir.path}/${_fileNameFor(url, ext)}');
      if (await f.exists()) await f.delete();
    } catch (e, s) {
      // ⚠️ ÇÖZÜLMÜŞ EK CİHAZDA KALIR: mesaj silindi/süresi doldu ama
      // fotoğrafın DÜZ hâli önbellekte duruyor. "Kaybolan mesaj" ve
      // "mesajı sil" vaatlerinin ikisi de sessizce boşa çıkar.
      reportHandled('Medya önbelleği silinemedi — ÇÖZÜLMÜŞ EK CİHAZDA KALDI', e,
          stack: s);
    }
  }

  /// TÜM çözülmüş medyayı sil.
  ///
  /// Çıkış, hesap silme ve PANİK (sahte mod) durumunda çağrılır: cihazda
  /// çözülmüş fotoğraf bırakmak, "kaybolan mesaj" vaadini boşa çıkarır.
  Future<void> clearAll() async {
    try {
      final dir = await _cacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        _dir = null;
      }
    } catch (e, s) {
      // ⚠️ EN AĞIR HÂLİ: bu metot ÇIKIŞ, HESAP SİLME ve PANİK (sahte mod)
      // yollarında çağrılır. Başarısız olursa kullanıcı "her şeyi sildim"
      // sanırken cihazda çözülmüş fotoğraflar durur — panik senaryosunda
      // korunmaya çalışılan şeyin ta kendisi.
      reportHandled(
          'Medya önbelleği temizlenemedi — ÇÖZÜLMÜŞ MEDYA CİHAZDA KALDI', e,
          stack: s);
    }
  }

  /// Önbellek boyutu (ayarlar ekranında gösterilebilir).
  Future<int> sizeInBytes() async {
    try {
      final dir = await _cacheDir();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final e in dir.list()) {
        if (e is File) total += await e.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
