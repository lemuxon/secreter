import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/double_ratchet_service.dart';

/// ⏱️ RATCHET İLERLEDİKTEN SONRA MESAJ BİR DAHA ÇÖZÜLEMEZ
///
/// ── NEDEN ÖNEMLİ ──
/// `decryptMessage` başarılı çözmeden sonra ratchet durumunu KALICI
/// yazıyor. Düz metin önbelleği ise ÇAĞIRAN tarafta, ayrı bir yazmayla
/// tutuluyordu. Arada uygulama ölürse (kullanıcı arka plandan siler,
/// telefon kapanır) şu olur:
///
///   zincir ilerledi + kaydedildi → **ölüm** → düz metin hiç yazılmadı
///
/// Açılışta mesaj yeniden çözülmeye çalışılır ama zincir o mesajın
/// ötesine geçmiştir. Anahtar `skipped` haritasına da girmemiştir:
/// atlanmadı, TÜKETİLDİ. Sonuç kalıcı "çözülemedi".
///
/// Bu dosya tuzağın ALTINDAKİ gerçeği ölçüyor — aynı paketi ilerlemiş
/// bir zincirle ikinci kez çözmek MÜMKÜN DEĞİL. Düzeltme bu yüzden
/// "yeniden dene" değil, **sıra**: düz metin ratchet kaydından önce
/// yazılır (`decryptMessage(messageId: ...)`).
void main() {
  test('🔴 tüketilen anahtar geri gelmez — ikinci çözme BAŞARISIZ', () async {
    final zincir = List<int>.generate(32, (i) => i + 1);
    final skipped = <String, String>{};

    final paket = await DoubleRatchetService.encrypt(
      chainKey: zincir,
      plaintext: 'gizli mesaj',
      messageNumber: 0,
    );

    // 1) İlk çözme başarılı ve zinciri İLERLETİR.
    final ilk = await DoubleRatchetService.decrypt(
      chainKey: zincir,
      chainIndex: 0,
      skipped: skipped,
      encryptedPacket: paket.ciphertext,
    );
    expect(ilk, isNotNull);
    expect(ilk!.plaintext, 'gizli mesaj');
    expect(ilk.newChainIndex, greaterThan(0),
        reason: 'zincir ilerlemezse bu tuzak zaten oluşmazdı');

    // 2) UYGULAMA ÖLDÜ: düz metin kaydedilmedi, ama ilerlemiş durum
    //    kalıcı. Açılışta aynı paket İLERLEMİŞ zincirle denenir.
    final ikinci = await DoubleRatchetService.decrypt(
      chainKey: ilk.newChainKey,
      chainIndex: ilk.newChainIndex,
      skipped: ilk.skipped,
      encryptedPacket: paket.ciphertext,
    );

    expect(ikinci, isNull,
        reason: 'ilerlemiş zincirle eski paket çözülemez — bu yüzden '
            'düz metin ratchet kaydından ÖNCE yazılmalı');
  });

  test('ATLANAN mesaj geri gelir — tüketilenden farkı budur', () async {
    // Karşıtlık: sırası atlanan mesajın anahtarı `skipped`te saklanır ve
    // sonradan çözülebilir. Kaybolan durum "atlama" değil, "tüketme".
    final zincir = List<int>.generate(32, (i) => i + 7);

    final birinci = await DoubleRatchetService.encrypt(
      chainKey: zincir,
      plaintext: 'bir',
      messageNumber: 0,
    );
    final ikinci = await DoubleRatchetService.encrypt(
      chainKey: birinci.newChainKey,
      plaintext: 'iki',
      messageNumber: 1,
    );

    // Önce İKİNCİ gelir (birinci gecikti) → birincinin anahtarı saklanır.
    final ikinciSonuc = await DoubleRatchetService.decrypt(
      chainKey: zincir,
      chainIndex: 0,
      skipped: <String, String>{},
      encryptedPacket: ikinci.ciphertext,
    );
    expect(ikinciSonuc, isNotNull);
    expect(ikinciSonuc!.plaintext, 'iki');

    // Geciken birinci sonradan gelir ve ÇÖZÜLÜR.
    final birinciSonuc = await DoubleRatchetService.decrypt(
      chainKey: ikinciSonuc.newChainKey,
      chainIndex: ikinciSonuc.newChainIndex,
      skipped: ikinciSonuc.skipped,
      encryptedPacket: birinci.ciphertext,
    );
    expect(birinciSonuc, isNotNull,
        reason: 'atlanan anahtar saklanır; asıl kayıp TÜKETİLEN anahtardır');
    expect(birinciSonuc!.plaintext, 'bir');
  });
}
