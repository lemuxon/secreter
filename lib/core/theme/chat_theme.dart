import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_theme.dart';
import '../i18n/app_localizations.dart';

/// SOHBET TEMASI (#8): Uygulama temasindan BAGIMSIZ sohbet rengi.
/// - Global varsayilan: Ayarlar > Sohbet rengi (tum sohbetler)
/// - Sohbete ozel: sohbet menusunden secilir, globali gecersiz kilar
/// Duvar kagidindan ayridir; ikisi birlikte kullanilabilir.
class BubbleTheme {
  final String id;
  final String name;

  /// Benim mesaj balonumun zemin rengi (koyu, okunur ton).
  final Color bubble;

  /// Gonder butonu / vurgu gradyani.
  final Color a;
  final Color b;

  const BubbleTheme(this.id, this.name, this.bubble, this.a, this.b);
}

/// Koyu-tema dostu hazir sohbet renkleri.
/// 'teal' = uygulamanin mevcut varsayilan gorunumu (birebir ayni degerler).
const List<BubbleTheme> bubbleThemes = [
  BubbleTheme('teal', 'color_teal', Color(0xFF14323F), AppTheme.primary,
      AppTheme.primaryDark),
  BubbleTheme('mavi', 'color_blue', Color(0xFF16294A), Color(0xFF4D8DFF),
      Color(0xFF2E63D6)),
  BubbleTheme('mor', 'color_purple', Color(0xFF2B1F49), Color(0xFFA07BFF),
      Color(0xFF7B52E8)),
  BubbleTheme('yesil', 'color_green', Color(0xFF14392B), Color(0xFF3DDC97),
      Color(0xFF23B377)),
  BubbleTheme('turuncu', 'color_orange', Color(0xFF3D2A16), Color(0xFFFFA94D),
      Color(0xFFE8862E)),
  BubbleTheme('pembe', 'color_pink', Color(0xFF3C1B30), Color(0xFFFF7BAE),
      Color(0xFFE85290)),
];

BubbleTheme bubbleThemeById(String? id) => bubbleThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => bubbleThemes.first,
    );

const String _globalKey = 'bubble_theme_global';
String _chatKey(String chatId) => 'bubble_theme_$chatId';

/// Global (uygulama geneli) sohbet rengi.
class GlobalBubbleNotifier extends StateNotifier<String> {
  GlobalBubbleNotifier() : super('teal') {
    _load();
  }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_globalKey);
    if (v != null && mounted) state = v;
  }

  Future<void> set(String id) async {
    state = id;
    final p = await SharedPreferences.getInstance();
    await p.setString(_globalKey, id);
  }
}

final globalBubbleThemeProvider =
    StateNotifierProvider<GlobalBubbleNotifier, String>(
        (ref) => GlobalBubbleNotifier());

/// Sohbete ozel gecersiz kilma (null = globali takip et).
class ChatBubbleOverrideNotifier extends StateNotifier<String?> {
  final String chatId;
  ChatBubbleOverrideNotifier(this.chatId) : super(null) {
    _load();
  }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) state = p.getString(_chatKey(chatId));
  }

  Future<void> set(String? id) async {
    state = id;
    final p = await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove(_chatKey(chatId));
    } else {
      await p.setString(_chatKey(chatId), id);
    }
  }
}

final chatBubbleOverrideProvider =
    StateNotifierProvider.family<ChatBubbleOverrideNotifier, String?, String>(
  (ref, chatId) => ChatBubbleOverrideNotifier(chatId),
);

/// Etkin tema: sohbete ozel varsa o, yoksa global. Ikisi de canli izlenir.
final effectiveBubbleThemeProvider =
    Provider.family<BubbleTheme, String>((ref, chatId) {
  final override = ref.watch(chatBubbleOverrideProvider(chatId));
  final global = ref.watch(globalBubbleThemeProvider);
  return bubbleThemeById(override ?? global);
});

/// Ortak renk secici (Ayarlar: chatId null = global; sohbet: chatId dolu).
void showBubbleThemePicker(BuildContext context, WidgetRef ref,
    {String? chatId}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    builder: (_) {
      final current = chatId == null
          ? ref.read(globalBubbleThemeProvider)
          : (ref.read(chatBubbleOverrideProvider(chatId)) ?? '');
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                chatId == null
                    ? context.tr('chat_color')
                    : context.tr('this_chat_color'),
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16),
              ),
            ),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                if (chatId != null)
                  _Swatch(
                    label: context.tr('default_word'),
                    selected: current.isEmpty,
                    gradient: const [AppTheme.surfaceLight, AppTheme.surface],
                    icon: Icons.sync,
                    onTap: () {
                      ref
                          .read(chatBubbleOverrideProvider(chatId).notifier)
                          .set(null);
                      Navigator.pop(context);
                    },
                  ),
                ...bubbleThemes.map((t) => _Swatch(
                      label: context.tr(t.name),
                      selected: current == t.id,
                      gradient: [t.a, t.b],
                      onTap: () {
                        if (chatId == null) {
                          ref
                              .read(globalBubbleThemeProvider.notifier)
                              .set(t.id);
                        } else {
                          ref
                              .read(chatBubbleOverrideProvider(chatId).notifier)
                              .set(t.id);
                        }
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
            const SizedBox(height: 18),
          ],
        ),
      );
    },
  );
}

class _Swatch extends StatelessWidget {
  final String label;
  final bool selected;
  final List<Color> gradient;
  final IconData? icon;
  final VoidCallback onTap;
  const _Swatch({
    required this.label,
    required this.selected,
    required this.gradient,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              border: Border.all(
                color: selected ? AppTheme.textPrimary : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: icon != null
                ? Icon(icon, color: AppTheme.textSecondary, size: 22)
                : (selected
                    ? const Icon(Icons.check,
                        color: Color(0xFF04141C), size: 24)
                    : null),
          ),
          const SizedBox(height: 6),
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
