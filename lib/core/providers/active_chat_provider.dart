import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Su an acik olan sohbetin id'si (bildirim bastirmak icin).
/// MessagingScreen acilinca set eder, kapaninca temizler.
final activeChatProvider = StateProvider<String?>((ref) => null);
