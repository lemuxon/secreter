import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/group_entity.dart';
import '../repositories/group_repository.dart';

/// Grubu canlı dinle
class WatchGroup implements StreamUseCase<GroupEntity, String> {
  final GroupRepository repository;
  WatchGroup(this.repository);

  @override
  Stream<Either<Failure, GroupEntity>> call(String chatId) =>
      repository.watchGroup(chatId);
}

/// Davet kodu al/oluştur
class GetInviteCode implements UseCase<String, String> {
  final GroupRepository repository;
  GetInviteCode(this.repository);

  @override
  Future<Either<Failure, String>> call(String chatId) =>
      repository.getOrCreateInviteCode(chatId);
}

/// Davet koduyla katıl
class JoinByInviteCode implements UseCase<String, String> {
  final GroupRepository repository;
  JoinByInviteCode(this.repository);

  @override
  Future<Either<Failure, String>> call(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('err_invite_empty'));
    }
    return repository.joinByInviteCode(trimmed);
  }
}

/// Üye rolünü değiştir — YETKİ KONTROLÜ içerir
class ChangeMemberRole implements UseCase<Unit, ChangeMemberRoleParams> {
  final GroupRepository repository;
  ChangeMemberRole(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ChangeMemberRoleParams params) async {
    // İş kuralı: sadece moderatör rol değiştirebilir
    if (!params.group.canModerate(params.actorUid)) {
      return const Left(AuthFailure('err_no_permission'));
    }
    // İş kuralı: owner'ın rolü değiştirilemez
    if (params.member.role == MemberRole.owner) {
      return const Left(ValidationFailure('err_owner_role'));
    }
    return repository.setMemberRole(
      chatId: params.group.id,
      member: params.member,
      newRole: params.newRole,
    );
  }
}

class ChangeMemberRoleParams extends Equatable {
  final GroupEntity group;
  final GroupMemberEntity member;
  final MemberRole newRole;
  final String actorUid;
  const ChangeMemberRoleParams({
    required this.group,
    required this.member,
    required this.newRole,
    required this.actorUid,
  });

  @override
  List<Object?> get props => [group.id, member.uid, newRole, actorUid];
}

/// Üyeyi sessize al/aç
class MuteMember implements UseCase<Unit, MuteMemberParams> {
  final GroupRepository repository;
  MuteMember(this.repository);

  @override
  Future<Either<Failure, Unit>> call(MuteMemberParams params) async {
    if (!params.group.canModerate(params.actorUid)) {
      return const Left(AuthFailure('err_no_permission'));
    }
    return repository.setMemberMuted(
      chatId: params.group.id,
      member: params.member,
      muted: params.muted,
    );
  }
}

class MuteMemberParams extends Equatable {
  final GroupEntity group;
  final GroupMemberEntity member;
  final bool muted;
  final String actorUid;
  const MuteMemberParams({
    required this.group,
    required this.member,
    required this.muted,
    required this.actorUid,
  });

  @override
  List<Object?> get props => [group.id, member.uid, muted, actorUid];
}

/// Üyeyi at veya yasakla
class RemoveMember implements UseCase<Unit, RemoveMemberParams> {
  final GroupRepository repository;
  RemoveMember(this.repository);

  @override
  Future<Either<Failure, Unit>> call(RemoveMemberParams params) async {
    if (!params.group.canModerate(params.actorUid)) {
      return const Left(AuthFailure('err_no_permission'));
    }
    if (params.member.role == MemberRole.owner) {
      return const Left(ValidationFailure('err_owner_kick'));
    }
    return params.ban
        ? repository.banMember(chatId: params.group.id, member: params.member)
        : repository.kickMember(chatId: params.group.id, member: params.member);
  }
}

class RemoveMemberParams extends Equatable {
  final GroupEntity group;
  final GroupMemberEntity member;
  final bool ban; // true=yasakla, false=sadece at
  final String actorUid;
  const RemoveMemberParams({
    required this.group,
    required this.member,
    required this.ban,
    required this.actorUid,
  });

  @override
  List<Object?> get props => [group.id, member.uid, ban, actorUid];
}

/// Kanal oluştur
class CreateChannel implements UseCase<String, CreateChannelParams> {
  final GroupRepository repository;
  CreateChannel(this.repository);

  @override
  Future<Either<Failure, String>> call(CreateChannelParams params) async {
    final name = params.name.trim();
    if (name.isEmpty) {
      return const Left(ValidationFailure('err_channel_name_empty'));
    }
    return repository.createChannel(
      name: name,
      description: params.description.trim(),
    );
  }
}

class CreateChannelParams extends Equatable {
  final String name;
  final String description;
  const CreateChannelParams({required this.name, required this.description});

  @override
  List<Object?> get props => [name, description];
}

/// Seçili üyelerle grup oluştur
class CreateGroup implements UseCase<String, CreateGroupParams> {
  final GroupRepository repository;
  CreateGroup(this.repository);

  @override
  Future<Either<Failure, String>> call(CreateGroupParams params) async {
    final name = params.name.trim();
    if (name.isEmpty) {
      return const Left(ValidationFailure('err_group_name_empty'));
    }
    if (params.members.isEmpty) {
      return const Left(ValidationFailure('err_min_member'));
    }
    return repository.createGroup(name: name, members: params.members);
  }
}

class CreateGroupParams extends Equatable {
  final String name;
  final List<({String uid, String username})> members;
  const CreateGroupParams({required this.name, required this.members});

  @override
  List<Object?> get props => [name, members];
}
