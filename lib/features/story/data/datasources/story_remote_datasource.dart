import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/exceptions.dart';
import '../models/story_model.dart';
import '../../../../services/auth_service.dart';
import '../../../../core/observability/handled_error.dart';

/// Hikayelerin uzak veri kaynağı (Firestore + Storage).
abstract class StoryRemoteDataSource {
  Stream<List<StoryModel>> watchStories();
  Future<void> createStory(StoryModel story);
  Future<String> uploadImage(String storyId, File file);
  Future<void> markViewed(String storyId, String userId);
  Future<void> deleteStory(String storyId);
}

class StoryRemoteDataSourceImpl implements StoryRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final Uuid uuid;

  StoryRemoteDataSourceImpl({
    required this.firestore,
    required this.storage,
    required this.uuid,
  });

  CollectionReference<Map<String, dynamic>> get _stories =>
      firestore.collection('stories');

  @override
  Stream<List<StoryModel>> watchStories() async* {
    // ── HATA DÜZELTME: Hikaye sızması (kök neden) ──
    // Önceki sorgu koleksiyondaki TÜM hikayeleri çekiyordu (hiç filtre yoktu),
    // bu yüzden yeni bir hesap eski hesabın (ve herkesin) hikayesini görüyordu.
    // Artık yalnızca KENDİ + MESAJLAŞTIĞIN kişilerin (kontaklar) hikayeleri
    // gösterilir; ayrıca süresi dolmuş (24s) hikayeler elenir.
    final myUid = AuthService.currentUid;
    if (myUid == null) {
      yield <StoryModel>[];
      return;
    }

    // Kontakları belirle: üye olduğum sohbetlerdeki (1-1 ve grup) tüm kullanıcılar.
    // chats.memberIds içinde uid'im geçen dokümanlardan toplanır.
    final Set<String> allowedIds = {myUid};
    try {
      final chatsSnap = await firestore
          .collection('chats')
          .where('memberIds', arrayContains: myUid)
          .get();
      for (final doc in chatsSnap.docs) {
        final members =
            (doc.data()['memberIds'] as List?)?.cast<String>() ?? const [];
        allowedIds.addAll(members);
      }
    } catch (_) {
      // Kontaklar okunamazsa en azından kendi hikayelerim gösterilir.
    }

    // Hikayeleri canlı dinle; yalnızca izinli kullanıcıların ve süresi
    // dolmamış olanları geçir. (Not: kontak listesi akış başında bir kez
    // okunur; yeni bir sohbet açılırsa ekrana tekrar girince güncellenir.
    // Ölçek için ileride sunucu-tarafı whereIn + composite index'e taşınabilir.)
    yield* _stories.orderBy('createdAt', descending: false).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => StoryModel.fromMap(doc.data()))
            .where((story) =>
                allowedIds.contains(story.userId) && !story.isExpired)
            .toList());
  }

  @override
  Future<void> createStory(StoryModel story) async {
    try {
      await _stories.doc(story.id).set(story.toMap());
    } catch (e, s) {
      reportHandled('Hikâye oluşturulamadı', e, stack: s);
      throw const ServerException('err_story_create');
    }
  }

  @override
  Future<String> uploadImage(String storyId, File file) async {
    try {
      final ref = storage.ref().child('stories/$storyId.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e, s) {
      reportHandled('Hikâye görseli yüklenemedi', e, stack: s);
      throw const ServerException('err_story_upload');
    }
  }

  @override
  Future<void> markViewed(String storyId, String userId) async {
    try {
      await _stories.doc(storyId).update({
        'viewedBy': FieldValue.arrayUnion([userId]),
      });
    } catch (e, s) {
      reportHandled('Görüntülendi işaretlenemedi', e, stack: s);
      throw const ServerException('err_story_seen');
    }
  }

  @override
  Future<void> deleteStory(String storyId) async {
    try {
      await _stories.doc(storyId).delete();
    } catch (e, s) {
      reportHandled('Hikâye silinemedi', e, stack: s);
      throw const ServerException('err_story_delete');
    }
  }
}
