import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/call/call_document.dart';
import 'package:gizli_chat/models/call_model.dart' as live;

/// 🔗 GELEN ARAMA SÖZLEŞMESİ — DART UCU
///
/// Gelen arama bu projede **iki kez sessizce kırıldı**: §4m'de kural
/// `list: false` olduğu için, §4u'de canlı model `participants`
/// yazmadığı için. İkisi de hata vermeden kırıldı; sorgu her iki
/// durumda da sorunsuz kuruluyor, sadece boş dönüyordu.
///
/// Emülatör tarafında bir test vardı ama `assertSucceeds` kullanıyordu:
/// sorgunun **İZİNLİ** olduğunu ölçüyor, **EŞLEŞTİĞİNİ** değil. Yani
/// §4u'nun hatası orada da görünmezdi. Üstelik oradaki fixture elle
/// yazılmıştı — şema değişse test yine geçerdi.
///
/// Bu dosya açığın Dart ucunu kapatır: `test/fixtures/
/// call_incoming.golden.json` içindeki belge ve alan adları, gerçek
/// şemadan ÜRETİLENLE aynı olmak zorunda. Emülatör testi aynı dosyayı
/// okuyup sorgunun gerçekten eşleştiğini ölçüyor.
///
/// ⚠️ Bu test düşerse: şema değişmiş demektir. Altın dosyayı güncelle
/// VE emülatör testinin hâlâ geçtiğini doğrula — ikisi birlikte
/// anlamlı; yalnız birini güncellemek §4u'yu geri getirir.
void main() {
  final golden = jsonDecode(
    File('test/fixtures/call_incoming.golden.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final belge = Map<String, dynamic>.from(golden['belge'] as Map);
  final sorgu = Map<String, dynamic>.from(golden['sorgu'] as Map);

  group('gelen arama sözleşmesi', () {
    test('canlı şema altın belgeyle AYNI', () {
      // `buildCallDocument`, `calls`'a yazan TEK yerin (CallService)
      // kullandığı üreteç (§4aj sonrası tek yazar kaldı).
      final uretilen = buildCallDocument(
        id: belge['id'] as String,
        callerId: belge['callerId'] as String,
        calleeId: belge['calleeId'] as String,
        type: belge['type'] as String,
        status: belge['status'] as String,
        createdAt: DateTime.parse(belge['createdAt'] as String),
      );

      expect(uretilen, belge,
          reason: 'Çağrı şeması değişti. Altın dosyayı güncelle ve '
              'emülatör testini yeniden çalıştır — yoksa gelen arama '
              'sorgusu sessizce eşleşmeyi bırakabilir (§4u).');
    });

    test('sorgunun dayandığı ALAN ADLARI altın dosyayla aynı', () {
      // Sorgu artık `CallFields` sabitlerini kullanıyor
      // (`call_remote_datasource.dart`). Sabit değişip altın dosya
      // güncellenmezse burada yakalanır.
      expect(CallFields.participants, sorgu['katilimciAlani']);
      expect(CallFields.status, sorgu['durumAlani']);
    });

    test('ÇALIYOR durumunun adı altın dosyayla aynı', () {
      // Sorgu `status == 'ringing'` süzüyor. Canlı enum'daki ad
      // değişirse (ör. `calling`) sorgu hiçbir şey döndürmez.
      expect(live.CallStatus.ringing.name, sorgu['calanDurum']);
    });

    test('belge, sorgunun aradığı DEĞERLERİ taşıyor', () {
      // §4u'nun tam hatası: alan yoktu, sorgu hiç eşleşmedi.
      expect(belge[sorgu['katilimciAlani']], contains(belge['calleeId']));
      expect(belge[sorgu['durumAlani']], sorgu['calanDurum']);
    });
  });
}
