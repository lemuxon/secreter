import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../../../models/call_model.dart' as legacy;
import '../../../../utils/app_theme.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/usecases/call_usecases.dart';
import 'call_screen.dart';
import 'group_call_screen.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/widgets/user_avatar.dart';

/// Gelen arama ekranı (yeni mimari).
/// incomingCallProvider bir çağrı yakaladığında gösterilir.
class IncomingCallScreen extends ConsumerWidget {
  final CallEntity call;
  const IncomingCallScreen({super.key, required this.call});

  bool get _isVideo => call.type.name == 'video';

  Future<void> _accept(BuildContext context) async {
    // 👥 GRUP ARAMASI ayrı bir motor kullanır (mesh, §4bq).
    if (call.isGroup) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GroupCallScreen(
            chatId: call.groupChatId,
            chatTitle: context.tr('group_call'),
            video: _isVideo,
            callId: call.id,
          ),
        ),
      );
      return;
    }
    // Eski CallType'a çevir (CallScreen eski motoru kullanıyor)
    final legacyType = _isVideo ? legacy.CallType.video : legacy.CallType.audio;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          calleeId: call.callerId,
          calleeUsername: call.callerName,
          callType: legacyType,
          isIncoming: true,
          incomingCallId: call.id,
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context) async {
    // ⚠️ GRUP ARAMASINDA "REDDET" ÇAĞRIYI BİTİRMEZ.
    //
    // `RejectCall` çağrının DURUMUNU `rejected` yapar; birebir aramada
    // doğru davranış budur. Grupta ise tek bir kişinin reddi, konuşan
    // herkesin aramasını kapatırdı. Burada reddetmek "beni bu çağrıya
    // çağırmayı bırak" demektir: ekran kapanır, çağrı sürer.
    if (call.isGroup) {
      Navigator.of(context).pop();
      return;
    }
    await getIt<RejectCall>()(call.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Arayanın profil fotoğrafı (yoksa baş harfe düşer)
            UserAvatar(
              uid: call.callerId,
              fallbackLetter: call.callerName.isNotEmpty
                  ? call.callerName[0].toUpperCase()
                  : '?',
              radius: 60,
            ),
            const SizedBox(height: 24),
            Text('@${call.callerName}',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
                call.isGroup
                    ? context.tr('group_call')
                    : (_isVideo ? 'Görüntülü arama...' : 'Sesli arama...'),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 16)),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Reddet
                  _actionButton(
                    icon: Icons.call_end,
                    color: AppTheme.danger,
                    label: context.tr('reject'),
                    onTap: () => _reject(context),
                  ),
                  // Kabul et
                  _actionButton(
                    icon: _isVideo ? Icons.videocam : Icons.call,
                    color: AppTheme.online,
                    label: context.tr('accept'),
                    onTap: () => _accept(context),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ],
    );
  }
}
