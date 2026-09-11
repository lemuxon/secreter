import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/auth/current_user_provider.dart';
import '../../../../services/chat_metadata_scrub.dart';
import '../../../../services/username_resolver.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../datasources/conversation_remote_datasource.dart';
import '../../../../core/observability/handled_error.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  final ConversationRemoteDataSource remoteDataSource;
  final CurrentUserProvider userProvider;

  ConversationRepositoryImpl({
    required this.remoteDataSource,
    required this.userProvider,
  });

  @override
  Stream<Either<Failure, List<ConversationEntity>>> watchConversations() {
    final myUid = userProvider.currentUid;
    if (myUid == null) {
      return Stream.value(const Left(AuthFailure()));
    }
    // HATA: .handleError((e) => Left(...)) hatayi YUTAR, donen degeri
    // AKISA EKLEMEZ. Firestore akisi bir kez hata verdiginde (izin, index,
    // gecici ag) hicbir sey yayilmadigi icin arayuz SONSUZ "yukleniyor"
    // durumunda kaliyordu. transform ile hatayi da bir deger olarak
    // yayiyoruz — arayuz ya listeyi ya da hatayi gorur, asla asili kalmaz.
    return remoteDataSource
        .watchConversations(myUid)
        .asyncMap<Either<Failure, List<ConversationEntity>>>((list) async {
      // ── METADATA GİZLİLİĞİ (2. aşama) ──
      // Sohbet dokümanı artık üye adlarını taşımıyor; birebir
      // sohbetin başlığı karşı tarafın uid'sinden çözülür. Liste
      // ÇİZİLMEDEN önce toplu ısıtılır, böylece `displayTitle`
      // senkron yolda hazır adı bulur ve başlık "Sohbet" diye
      // görünüp sonradan zıplamaz.
      await UsernameResolver.warm(
        list
            .where((c) => c.isDirect)
            .map((c) => c.otherUserId(myUid) ?? '')
            .where((id) => id.isNotEmpty),
      );
      // Eski dokümanlarda kalmış ad dizisini sunucudan sil.
      ChatMetadataScrub.scrub(
        list.where((c) => c.memberUsernames.isNotEmpty).map((c) => c.id),
      );
      return Right(list);
    }).transform(
      StreamTransformer<Either<Failure, List<ConversationEntity>>,
          Either<Failure, List<ConversationEntity>>>.fromHandlers(
        // handleData varsayilan: veriyi aynen gecirir.
        handleError: (e, st, sink) {
          reportHandled('watchConversations', e, stack: st);
          sink.add(const Left(ServerFailure()));
        },
      ),
    );
  }
}
