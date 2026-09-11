import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/group_entity.dart';

/// Grup/kanal veri erişiminin sözleşmesi.
abstract class GroupRepository {
  /// Tek bir grubu canlı dinle (ayar ekranı için)
  Stream<Either<Failure, GroupEntity>> watchGroup(String chatId);

  // ── Davet linki ──
  Future<Either<Failure, String>> getOrCreateInviteCode(String chatId);
  Future<Either<Failure, String>> resetInviteCode(String chatId);
  Future<Either<Failure, String>> joinByInviteCode(String code);

  // ── Rol yönetimi ──
  Future<Either<Failure, Unit>> setMemberRole({
    required String chatId,
    required GroupMemberEntity member,
    required MemberRole newRole,
  });
  Future<Either<Failure, Unit>> setMemberMuted({
    required String chatId,
    required GroupMemberEntity member,
    required bool muted,
  });
  Future<Either<Failure, Unit>> kickMember({
    required String chatId,
    required GroupMemberEntity member,
  });
  Future<Either<Failure, Unit>> banMember({
    required String chatId,
    required GroupMemberEntity member,
  });

  // ── Grup ayarları ──
  Future<Either<Failure, Unit>> updateGroupInfo({
    required String chatId,
    String? name,
    String? description,
    String? avatarUrl,
  });
  Future<Either<Failure, Unit>> setOnlyAdminsCanPost({
    required String chatId,
    required bool value,
  });

  // ── Oluşturma ──
  Future<Either<Failure, String>> createChannel({
    required String name,
    required String description,
  });

  /// Seçili üyelerle grup oluştur → chatId döner.
  /// [members]: (uid, username) çiftleri (oluşturan otomatik owner olur).
  Future<Either<Failure, String>> createGroup({
    required String name,
    required List<({String uid, String username})> members,
  });

  /// Gruptan ayrıl (kendini çıkar)
  Future<Either<Failure, Unit>> leaveGroup(String chatId);
  Future<Either<Failure, Unit>> deleteGroup(String chatId);
}
