import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/locale_provider.dart';
import '../../../utils/app_theme.dart';

/// 🌐 Dil seçim ekranı — ilk açılışta (girişten önce) ve Ayarlar'dan.
/// [onDone] verilirse seçim sonrası çağrılır (ilk açılış akışı); yoksa
/// ekran kendini kapatır (Ayarlar'dan açıldığında).
class LanguageScreen extends ConsumerWidget {
  /// Secim sonrasi cagirilir; ekranin KENDI (canli) context'i gecilir
  /// — splash'in olu context'i degil (Devam butonu bug'inin koku).
  final void Function(BuildContext ctx)? onDone;
  const LanguageScreen({super.key, this.onDone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider)?.languageCode;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.language, color: AppTheme.primary, size: 40),
                  const SizedBox(height: 14),
                  Text(context.tr('choose_language'),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(context.tr('choose_language_sub'),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: AppLanguages.all.length,
                itemBuilder: (context, i) {
                  final lang = AppLanguages.all[i];
                  final selected = lang.code == current;
                  return Card(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.14)
                        : AppTheme.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: selected ? AppTheme.primary : Colors.transparent,
                        width: 1.4,
                      ),
                    ),
                    child: ListTile(
                      leading:
                          Text(lang.flag, style: const TextStyle(fontSize: 24)),
                      title: Text(lang.native,
                          style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 16)),
                      trailing: selected
                          ? const Icon(Icons.check_circle,
                              color: AppTheme.primary)
                          : null,
                      onTap: () async {
                        await ref
                            .read(localeProvider.notifier)
                            .setLocale(lang.code);
                        if (onDone == null && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            if (onDone != null)
              Padding(
                padding: const EdgeInsets.all(18),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      // hic secmediyse varsayilan: cihaz dili yoksa Ingilizce
                      if (ref.read(localeProvider) == null) {
                        ref.read(localeProvider.notifier).setLocale('en');
                      }
                      onDone!(context); // CANLI context
                    },
                    child: Text(context.tr('continue')),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
