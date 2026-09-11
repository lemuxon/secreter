import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/call_entity.dart';
import '../models/call_model.dart';
import '../../../../core/call/call_document.dart';
import '../../../../services/call_log_service.dart';
import '../../../../core/observability/handled_error.dart';

/// ⚠️ ÇAĞRI DOKÜMANINI **OKUR**, OLUŞTURMAZ.
///
/// `calls` koleksiyonuna yazan tek yer `lib/services/call_service.dart`.
/// Burada yalnızca dinleme (`watchIncomingCall`, `watchCall`) ve tek bir
/// durum geçişi (`updateStatus` — reddetme) var.
///
/// ── 🐞 NEDEN YAZMA YÜZEYİ KALDIRILDI (§4t/§4u/§4aj) ──
/// Bu dosyada `createCall`/`setAnswer`/`getAnswer`/`deleteCall` vardı ve
/// HİÇBİRİ çağrılmıyordu — ama `calls`'a tam bir doküman yazacak koda
/// sahiptiler. §4t'de `participants` yalnızca bu katmana eklenince canlı
/// doküman alanı taşımadı ve gelen arama sessizce kırıldı (§4u).
/// §4t ölü ICE metotlarını aynı gerekçeyle kaldırmıştı: *bırakılsalardı
/// bir sonraki geliştirici onları doğru yol sanıp eski şemaya yazardı.*
/// §4aj aynı ilkeyi kalan yazma metotlarına uyguladı.
///
/// ⚠️ Buraya yazma metodu ekleme; ikinci bir yazar §4u'yu geri getirir.

/// Çağrı sinyalleşmesinin uzak kaynağı (Firestore) — okuma tarafı.
abstract class CallRemoteDataSource {
  Stream<CallModel?> watchIncomingCall(String myUid);
  Stream<CallModel> watchCall(String callId);
  Future<void> updateStatus(String callId, CallStatus status);
}

class CallRemoteDataSourceImpl implements CallRemoteDataSource {
  final FirebaseFirestore firestore;
  CallRemoteDataSourceImpl({required this.firestore});

  CollectionReference<Map<String, dynamic>> get _calls =>
      firestore.collection('calls');

  @override
  Stream<CallModel?> watchIncomingCall(String myUid) {
    try {
      return _calls
          // 👥 ÜYELİK ARTIK `participants` — `calleeId` DEĞİL.
          // Eski sorgu şemayı iki kişiye çiviliyordu: grup aramasında
          // "aranan" diye tek bir kişi yok, çağrıya davet edilen HERKES
          // gelen aramayı görmeli.
          // ⚠️ ALAN ADLARI `CallFields`TEN — elle yazılmamalı. Sorgu,
          // dokümanı ÜRETEN yerle (`buildCallDocument`) aynı sabitlere
          // bağlı olmazsa §4u tekrar eder: yazan taraf alanı
          // değiştirir, sorgu eski adı arar, sonuç boş döner ve
          // **hiçbir hata çıkmaz**.
          .where(CallFields.participants, arrayContains: myUid)
          // CallService gelen aramayı 'ringing' statüsüyle yazar
          // (eski motor 'dialing' değil 'ringing' kullanıyor)
          .where(CallFields.status, isEqualTo: CallStatus.ringing.name)
          .snapshots()
          .map((snap) {
        // ⚠️ `participants` beni de içerdiği için KENDİ başlattığım
        // çağrı da bu sorguya düşer. `calleeId` ile süzerken bu sorun
        // yoktu; elenmezse arayan kişiye kendi araması "gelen arama"
        // olarak gösterilirdi.
        for (final d in snap.docs) {
          final veri = d.data();
          final call = CallModel.fromMap(veri);
          if (call.callerId == myUid) continue;
          // 👥 GRUP ARAMASI SÜZGECİ (§4bq).
          //
          // Grup araması konuşma boyunca `ringing` kalır; bu iki tuzak
          // doğurur ve ikisi de kullanıcıya "durmadan çalan telefon"
          // olarak görünür:
          //   1. ÖLÜ ARAMA — son ayrılan `ended` yazamadıysa (uygulama
          //      öldürüldü) doküman sonsuza dek çalar durumda kalır.
          //   2. ZATEN İÇİNDEYİM — konuşurken gelen arama ekranı
          //      açılmamalı.
          if (call.isGroup) {
            if (!grupCagrisiCanli(veri)) continue;
            if (call.joinedIds.contains(myUid)) continue;
          }
          return call;
        }
        return null;
      });
    } catch (e, s) {
      reportHandled('Gelen çağrı dinlenemedi', e, stack: s);
      throw const ServerException('err_call_listen');
    }
  }

  @override
  Stream<CallModel> watchCall(String callId) {
    try {
      return _calls
          .doc(callId)
          .snapshots()
          .map((doc) => CallModel.fromMap(doc.data() ?? {}));
    } catch (e, s) {
      reportHandled('Çağrı dinlenemedi', e, stack: s);
      throw const ServerException('err_call_listen');
    }
  }

  @override
  Future<void> updateStatus(String callId, CallStatus status) async {
    try {
      final data = <String, dynamic>{'status': status.name};
      if (status == CallStatus.ended ||
          status == CallStatus.rejected ||
          status == CallStatus.missed) {
        data['endedAt'] = DateTime.now().toUtc().toIso8601String();
      }
      await _calls.doc(callId).update(data);

      // ÇAĞRI GEÇMİŞİ: sinyalleşme dokümanı kısa ömürlüdür (silinir).
      // Terminal durumda kalıcı bir kayıt yazarız ki geçmiş sekmesinde
      // ve cevapsız çağrı bildiriminde kullanılabilsin.
      if (data.containsKey('endedAt')) {
        await CallLogService.archive(callId, status.name);
      }
    } catch (e, s) {
      reportHandled('Çağrı durumu güncellenemedi', e, stack: s);
      throw const ServerException('err_call_update');
    }
  }
}
