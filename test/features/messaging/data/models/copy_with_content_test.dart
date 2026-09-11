import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/features/messaging/data/models/message_model.dart';
import 'package:gizli_chat/features/messaging/domain/entities/message_entity.dart';

/// `copyWithContent` ALAN DÜŞÜRÜYORDU (§4az).
///
/// 🐞 GERÇEK KULLANICIDA ÖLÇÜLDÜ (2026-09-11): karşı taraf gönderilen
/// fotoğraf/video/belgeyi göremiyor, ankete oy veremiyordu.
///
/// Kök neden TEK bir metotta: `_decryptMessages`, çözmeden ÖNCE her
/// mesajı `withResolvedSender()`'dan geçiriyor (metadata gizliliği §4k:
/// `senderUsername` sunucuya yazılmıyor, uid'den çözülüyor). O da
/// `copyWithContent`'i çağırıyor — ve `copyWithContent` dört alanı
/// taşımıyordu:
///
///   • `e2eeHeader`   → X3DH başlığı ÇÖZMEDEN ÖNCE yok oluyor. Alıcı
///                      oturumu kuramıyor → "bu mesaj bu cihazda
///                      çözülemiyor". Medya ekinin anahtarı da şifreli
///                      içerikte taşındığı için medya da açılmıyor.
///   • `pollOptions`  → ankette hiç seçenek kalmıyor → OY VERİLEMİYOR.
///   • `pollVotes` / `pollClosed`
///
/// ⚠️ ASİMETRİNİN SEBEBİ BUYDU: `withResolvedSender` yalnızca ad BOŞKEN
/// ve çözülebiliyorken kopya üretir. Kendi mesajlarımızda ad zaten dolu
/// (yerel önbellekten) → başlık korunur → "kendimle mesajlaşınca sorun
/// yok". Gelen mesajlarda ad boştur ve çözülür → başlık SİLİNİR →
/// "başkası bana yazamıyor".
///
/// Bu ayrıca gece turundaki ÖLÇÜMÜ açıklıyor: "gelen mesajlarda başlık
/// YOK" doğruydu — ama başlığı gönderen koymamış değildi, ALICI kendi
/// içinde siliyordu.
void main() {
  MessageModel mesaj({
    Map<String, dynamic>? baslik,
    List<String> secenekler = const [],
    Map<String, int> oylar = const {},
    bool kapali = false,
    String ad = '',
  }) =>
      MessageModel(
        id: 'm1',
        chatId: 'c1',
        senderId: 'gonderen',
        senderUsername: ad,
        content: 'ŞİFRELİ',
        type: MessageContentType.text,
        timestamp: DateTime(2026, 9, 11),
        e2eeHeader: baslik,
        pollOptions: secenekler,
        pollVotes: oylar,
        pollClosed: kapali,
      );

  const baslik = {'ik': 'KİMLİK_ANAHTARI', 'ek': 'EFEMERAL_ANAHTAR'};

  group('copyWithContent alan düşürmez', () {
    test('🔴 e2eeHeader KORUNUR', () {
      final k = mesaj(baslik: baslik).copyWithContent('düz metin');
      expect(k.e2eeHeader, baslik,
          reason: 'başlık düşerse alıcı X3DH oturumunu KURAMAZ ve mesaj '
              'kalıcı olarak çözülemez kalır');
    });

    test('🔴 anket alanları KORUNUR', () {
      final k = mesaj(
        secenekler: ['Evet', 'Hayır'],
        oylar: {'u1': 0},
        kapali: true,
      ).copyWithContent('Soru?');

      expect(k.pollOptions, ['Evet', 'Hayır'],
          reason: 'seçenek kalmazsa arayüz oylanacak bir şey çizemez');
      expect(k.pollVotes, {'u1': 0});
      expect(k.pollClosed, isTrue);
    });

    test('mediaKey ve diğer alanlar da korunur', () {
      final k = mesaj(baslik: baslik).copyWithContent('x', mediaKey: 'ANAHTAR');
      expect(k.mediaKey, 'ANAHTAR');
      expect(k.id, 'm1');
      expect(k.senderId, 'gonderen');
      expect(k.content, 'x', reason: 'değişmesi İSTENEN tek alan içerik');
    });
  });

  group('withResolvedSender — gerçek çağrı yolu', () {
    test('🔴 ad çözülürken başlık ve anket KAYBOLMAZ', () {
      // `_decryptMessages` her gelen mesajı ÇÖZMEDEN ÖNCE buradan geçirir.
      final gelen = mesaj(baslik: baslik, secenekler: ['A', 'B']);
      final cozulmus = gelen.withResolvedSender('ayse');

      expect(cozulmus.senderUsername, 'ayse');
      expect(cozulmus.e2eeHeader, baslik,
          reason: 'ASIL HATA BUYDU: ad çözülünce başlık siliniyordu');
      expect(cozulmus.pollOptions, ['A', 'B']);
    });

    test('adı ZATEN dolu olan mesaja dokunulmaz', () {
      // Kendi mesajlarımız bu daldan geçer — hatanın neden yalnızca
      // GELEN mesajlarda göründüğünün sebebi.
      final kendi = mesaj(baslik: baslik, ad: 'ben');
      expect(identical(kendi.withResolvedSender('baskasi'), kendi), isTrue);
    });

    test('ad çözülemezse dokunulmaz', () {
      final gelen = mesaj(baslik: baslik);
      expect(identical(gelen.withResolvedSender(null), gelen), isTrue);
      expect(identical(gelen.withResolvedSender(''), gelen), isTrue);
    });
  });
}
