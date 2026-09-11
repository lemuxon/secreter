import 'package:equatable/equatable.dart';

/// Arama sonucunda bulunan kullanıcının domain temsili.
class FoundUser extends Equatable {
  final String uid;
  final String username;
  final bool isOnline;

  const FoundUser({
    required this.uid,
    required this.username,
    this.isOnline = false,
  });

  String get avatarLetter =>
      username.isNotEmpty ? username[0].toUpperCase() : '?';

  @override
  List<Object?> get props => [uid, username, isOnline];
}
