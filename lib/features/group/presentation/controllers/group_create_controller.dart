import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../../search/domain/entities/found_user.dart';
import '../../../search/domain/repositories/search_repository.dart';
import '../../domain/usecases/group_usecases.dart';

class GroupCreateState extends Equatable {
  // Üye arama (sadece grup için)
  final bool searching;
  final FoundUser? searchResult;
  final String? searchError;
  final List<FoundUser> selectedMembers;
  // Oluşturma
  final bool creating;
  final String? error;
  final String? createdChatId;
  final String? createdName;

  const GroupCreateState({
    this.searching = false,
    this.searchResult,
    this.searchError,
    this.selectedMembers = const [],
    this.creating = false,
    this.error,
    this.createdChatId,
    this.createdName,
  });

  GroupCreateState copyWith({
    bool? searching,
    FoundUser? searchResult,
    String? searchError,
    List<FoundUser>? selectedMembers,
    bool? creating,
    String? error,
    String? createdChatId,
    String? createdName,
    bool clearSearchResult = false,
    bool clearSearchError = false,
    bool clearError = false,
  }) {
    return GroupCreateState(
      searching: searching ?? this.searching,
      searchResult:
          clearSearchResult ? null : (searchResult ?? this.searchResult),
      searchError: clearSearchError ? null : (searchError ?? this.searchError),
      selectedMembers: selectedMembers ?? this.selectedMembers,
      creating: creating ?? this.creating,
      error: clearError ? null : (error ?? this.error),
      createdChatId: createdChatId ?? this.createdChatId,
      createdName: createdName ?? this.createdName,
    );
  }

  @override
  List<Object?> get props => [
        searching,
        searchResult,
        searchError,
        selectedMembers,
        creating,
        error,
        createdChatId,
        createdName,
      ];
}

class GroupCreateController extends StateNotifier<GroupCreateState> {
  final SearchRepository _searchRepo;
  final CreateGroup _createGroup;
  final CreateChannel _createChannel;

  GroupCreateController()
      : _searchRepo = getIt<SearchRepository>(),
        _createGroup = getIt<CreateGroup>(),
        _createChannel = getIt<CreateChannel>(),
        super(const GroupCreateState());

  /// Üye aramak için kullanıcı bul
  Future<void> searchUser(String query) async {
    final q = query.trim().toLowerCase().replaceAll('@', '');
    if (q.isEmpty) return;
    state = state.copyWith(
        searching: true, clearSearchResult: true, clearSearchError: true);
    final result = await _searchRepo.findByUsername(q);
    result.fold(
      (failure) => state =
          state.copyWith(searching: false, searchError: failure.message),
      (user) {
        if (user == null) {
          state = state.copyWith(
              searching: false, searchError: 'err_user_not_found');
        } else if (state.selectedMembers.any((u) => u.uid == user.uid)) {
          state = state.copyWith(
              searching: false, searchError: 'err_already_added');
        } else {
          state = state.copyWith(searching: false, searchResult: user);
        }
      },
    );
  }

  void addMember(FoundUser user) {
    state = state.copyWith(
      selectedMembers: [...state.selectedMembers, user],
      clearSearchResult: true,
    );
  }

  void removeMember(FoundUser user) {
    state = state.copyWith(
      selectedMembers:
          state.selectedMembers.where((u) => u.uid != user.uid).toList(),
    );
  }

  /// Grup oluştur
  Future<void> createGroup(String name) async {
    state = state.copyWith(creating: true, clearError: true);
    final members = state.selectedMembers
        .map((u) => (uid: u.uid, username: u.username))
        .toList();
    final result =
        await _createGroup(CreateGroupParams(name: name, members: members));
    result.fold(
      (failure) =>
          state = state.copyWith(creating: false, error: failure.message),
      (chatId) => state = state.copyWith(
          creating: false, createdChatId: chatId, createdName: name.trim()),
    );
  }

  /// Kanal oluştur
  Future<void> createChannel(String name, String description) async {
    state = state.copyWith(creating: true, clearError: true);
    final result = await _createChannel(
        CreateChannelParams(name: name, description: description));
    result.fold(
      (failure) =>
          state = state.copyWith(creating: false, error: failure.message),
      (chatId) => state = state.copyWith(
          creating: false, createdChatId: chatId, createdName: name.trim()),
    );
  }
}

final groupCreateControllerProvider =
    StateNotifierProvider.autoDispose<GroupCreateController, GroupCreateState>(
  (ref) => GroupCreateController(),
);
