import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/observability/app_logger.dart';
import '../core/observability/handled_error.dart';

/// 🧹 ESKİ SOHBET DOKÜMANLARINDAN KULLANICI ADLARINI SİLER.
///
/// ── NEDEN VAR ──
/// Metadata gizliliğinin 2. aşamasında istemci `memberUsernames` alanını
/// artık YAZMIYOR. Ama yalnızca yazmayı durdurmak, ZATEN YAZILMIŞ olanı
/// ortadan kaldırmaz: 2. aşamadan önce oluşmuş her sohbet dokümanı
/// sunucuda hâlâ
///
///     memberUsernames: ["ayse", "mehmet"]
///
/// taşır. Yani veritabanına bakan biri o sohbetlerin taraflarını
/// adlarıyla okumaya devam ederdi — "artık yazmıyoruz" demek düzeltmenin
/// yalnızca yarısı olurdu.
///
/// Bu yüzden istemci, alanı DOLU gördüğü her sohbette bir kez silme
/// dener. Güvenlik kuralı bu tek işlemi üyelere açar (yalnızca SİLME;
/// ekleme ve değiştirme her yolda reddedilir).
///
/// ── NEDEN SESSİZ ──
/// Temizlik bir kolaylıktır, işlevsel bir gereklilik değil. Başarısız
/// olursa (ağ yok, yasaklı üye, kurallar henüz dağıtılmadı) kullanıcıya
/// gösterilecek bir şey yoktur; sohbet normal çalışmaya devam eder ve
/// deneme bir sonraki açılışta tekrarlanır.
class ChatMetadataScrub {
  ChatMetadataScrub._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Süreç ömrü boyunca aynı sohbet için tek deneme. Kural henüz
  /// dağıtılmamışsa her liste güncellemesinde yeniden yazmaya çalışıp
  /// kota harcamayalım.
  static final Set<String> _tried = <String>{};

  /// Verilen sohbetlerdeki eski ad dizisini sil (ateşle-unut).
  ///
  /// Çağıran BEKLEMEZ: arayüz çizimi bu yazmaya bağlı değildir.
  static void scrub(Iterable<String> chatIds) {
    for (final chatId in chatIds) {
      if (chatId.isEmpty || !_tried.add(chatId)) continue;
      _db.collection('chats').doc(chatId).update({
        'memberUsernames': FieldValue.delete(),
      }).catchError((Object e) {
        reportHandled('Eski ad dizisi silinemedi', e,
            context: {'sohbet': Redact.id(chatId)});
      });
    }
  }

  /// Hesap değişimi / çıkış: denemeler önceki hesaba aitti.
  static void reset() => _tried.clear();
}
