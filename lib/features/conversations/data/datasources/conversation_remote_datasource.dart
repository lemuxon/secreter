import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/conversation_model.dart';
import 'package:flutter/foundation.dart';

/// Sohbet listesinin uzak kaynağı (Firestore 'chats').
abstract class ConversationRemoteDataSource {
  Stream<List<ConversationModel>> watchConversations(String myUid);
}

class ConversationRemoteDataSourceImpl implements ConversationRemoteDataSource {
  final FirebaseFirestore firestore;
  ConversationRemoteDataSourceImpl({required this.firestore});

  /// DAYANIKLI SOHBET AKISI
  ///
  /// Birincil sorgu sunucuda siralar (hizli) ama BILESIK DIZIN ister:
  ///   memberIds (array-contains) + lastMessageTime (desc)
  /// Dizin yoksa Firestore FAILED_PRECONDITION firlatir ve liste hic
  /// gelmez. Bu durumda sirasiz sorguya DUSER, siralamayi istemcide
  /// yapariz — kullanici dizin olusana kadar da uygulamayi kullanabilir.
  @override
  Stream<List<ConversationModel>> watchConversations(String myUid) {
    final base =
        firestore.collection('chats').where('memberIds', arrayContains: myUid);

    List<ConversationModel> parse(QuerySnapshot<Map<String, dynamic>> snap) =>
        snap.docs.map((d) => ConversationModel.fromMap(d.data())).toList();

    final controller = StreamController<List<ConversationModel>>();
    StreamSubscription? sub;
    var fellBack = false;

    void listenFallback() {
      sub = base.snapshots().listen(
        (snap) {
          final list = parse(snap);
          // istemci tarafi siralama (en yeni ustte)
          list.sort((a, b) {
            final at = a.lastMessageTime;
            final bt = b.lastMessageTime;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
          controller.add(list);
        },
        onError: controller.addError,
      );
    }

    void listenOrdered() {
      sub =
          base.orderBy('lastMessageTime', descending: true).snapshots().listen(
        (snap) => controller.add(parse(snap)),
        onError: (e) {
          // Dizin eksikse (FAILED_PRECONDITION) sessizce sirasiza dus.
          if (!fellBack) {
            fellBack = true;
            debugPrint(
                'Sohbet sorgusu dizinsiz moda düştü (dizin oluşturulmalı): $e');
            sub?.cancel();
            listenFallback();
          } else {
            controller.addError(e);
          }
        },
      );
    }

    controller.onListen = listenOrdered;
    controller.onCancel = () async {
      await sub?.cancel();
      await controller.close(); // kaynak sizintisi olmasin
    };
    return controller.stream;
  }
}
