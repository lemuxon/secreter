import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/chat_wallpaper.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';

/// Sohbet duvar kağıdı seçimi (hazır renk/gradyan ızgarası).
class WallpaperScreen extends ConsumerWidget {
  const WallpaperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wallpaperProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('chat_wallpaper'))),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: chatWallpapers.length,
        itemBuilder: (context, i) {
          final wp = chatWallpapers[i];
          final isSelected = wp.id == selected;
          return GestureDetector(
            onTap: () => ref.read(wallpaperProvider.notifier).select(wp.id),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: wp.decoration.copyWith(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.surfaceLight,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(Icons.check_circle,
                                color: AppTheme.primary, size: 28),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(wp.name),
                  style: TextStyle(
                    color:
                        isSelected ? AppTheme.primary : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
