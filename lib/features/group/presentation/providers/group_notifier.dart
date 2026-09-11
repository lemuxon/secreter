import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/repositories/group_repository.dart';
import '../../domain/usecases/group_usecases.dart';

/// Grup ayar ekranı durumu
class GroupState extends Equatable {
  final GroupEntity? group;
  final bool isLoading;
  final String? error;
  final String? inviteCode;
  final bool isProcessing;

  const GroupState({
    this.group,
    this.isLoading = false,
    this.error,
    this.inviteCode,
    this.isProcessing = false,
  });

  factory GroupState.initial() => const GroupState(isLoading: true);

  GroupState copyWith({
    GroupEntity? group,
    bool? isLoading,
    String? error,
    String? inviteCode,
    bool? isProcessing,
    bool clearError = false,
  }) {
    return GroupState(
      group: group ?? this.group,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      inviteCode: inviteCode ?? this.inviteCode,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  @override
  List<Object?> get props =>
      [group, isLoading, error, inviteCode, isProcessing];
}

/// Grup durumunu yöneten notifier (chatId bazlı)
class GroupNotifier extends StateNotifier<GroupState> {
  final String chatId;
  final String myUid;

  final WatchGroup _watchGroup;
  final GetInviteCode _getInviteCode;
  final ChangeMemberRole _changeMemberRole;
  final MuteMember _muteMember;
  final RemoveMember _removeMember;
  final GroupRepository _repo;

  StreamSubscription? _sub;

  GroupNotifier(this.chatId, this.myUid)
      : _watchGroup = getIt<WatchGroup>(),
        _getInviteCode = getIt<GetInviteCode>(),
        _changeMemberRole = getIt<ChangeMemberRole>(),
        _muteMember = getIt<MuteMember>(),
        _removeMember = getIt<RemoveMember>(),
        _repo = getIt<GroupRepository>(),
        super(GroupState.initial()) {
    _start();
  }

  void _start() {
    _sub = _watchGroup(chatId).listen((either) {
      either.fold(
        (failure) =>
            state = state.copyWith(isLoading: false, error: failure.message),
        (group) => state = state.copyWith(
          group: group,
          isLoading: false,
          clearError: true,
        ),
      );
    });
  }

  /// Davet kodunu yükle
  Future<void> loadInviteCode() async {
    final result = await _getInviteCode(chatId);
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (code) => state = state.copyWith(inviteCode: code),
    );
  }

  /// Üye rolünü değiştir
  Future<void> changeMemberRole(
      GroupMemberEntity member, MemberRole newRole) async {
    final group = state.group;
    if (group == null) return;

    state = state.copyWith(isProcessing: true);
    final result = await _changeMemberRole(ChangeMemberRoleParams(
      group: group,
      member: member,
      newRole: newRole,
      actorUid: myUid,
    ));
    result.fold(
      (failure) =>
          state = state.copyWith(isProcessing: false, error: failure.message),
      (_) => state = state.copyWith(isProcessing: false, clearError: true),
    );
  }

  /// Üyeyi sessize al/aç
  Future<void> toggleMute(GroupMemberEntity member) async {
    final group = state.group;
    if (group == null) return;

    final result = await _muteMember(MuteMemberParams(
      group: group,
      member: member,
      muted: !member.isMuted,
      actorUid: myUid,
    ));
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (_) {},
    );
  }

  /// Üyeyi at veya yasakla
  Future<void> removeMember(GroupMemberEntity member,
      {required bool ban}) async {
    final group = state.group;
    if (group == null) return;

    final result = await _removeMember(RemoveMemberParams(
      group: group,
      member: member,
      ban: ban,
      actorUid: myUid,
    ));
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (_) {},
    );
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// Davet kodunu yenile (eskisini geçersiz kıl)
  Future<void> resetInviteCode() async {
    final result = await _repo.resetInviteCode(chatId);
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (code) => state = state.copyWith(inviteCode: code),
    );
  }

  /// Grup adı / açıklamasını güncelle
  /// Grup/kanal fotografini yukle ve kaydet (yalnizca yoneticiler cagirmali).
  Future<void> setGroupPhoto(String localPath) async {
    try {
      final ref =
          FirebaseStorage.instance.ref().child('group_avatars/$chatId.jpg');
      await ref.putFile(File(localPath));
      final url = await ref.getDownloadURL();
      final result =
          await _repo.updateGroupInfo(chatId: chatId, avatarUrl: url);
      result.fold(
        (f) => state = state.copyWith(error: f.message),
        (_) {},
      );
    } catch (e) {
      state = state.copyWith(error: 'Fotoğraf yüklenemedi: $e');
    }
  }

  Future<void> updateInfo({String? name, String? description}) async {
    state = state.copyWith(isProcessing: true);
    final result = await _repo.updateGroupInfo(
        chatId: chatId, name: name, description: description);
    result.fold(
      (failure) =>
          state = state.copyWith(isProcessing: false, error: failure.message),
      (_) => state = state.copyWith(isProcessing: false, clearError: true),
    );
  }

  /// "Sadece adminler gönderebilir" ayarını değiştir
  Future<void> setOnlyAdminsCanPost(bool value) async {
    final result =
        await _repo.setOnlyAdminsCanPost(chatId: chatId, value: value);
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (_) {},
    );
  }

  /// Gruptan ayrıl. Başarılıysa true döner (ekran kapatması için).
  Future<bool> leaveGroup() async {
    final result = await _repo.leaveGroup(chatId);
    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (_) => true,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// chatId + myUid parametreli provider
final groupNotifierProvider = StateNotifierProvider.autoDispose
    .family<GroupNotifier, GroupState, ({String chatId, String myUid})>(
  (ref, params) => GroupNotifier(params.chatId, params.myUid),
);
