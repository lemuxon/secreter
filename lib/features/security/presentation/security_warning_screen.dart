import 'package:flutter/material.dart';
import '../../../core/security/security_service.dart';
import '../../../utils/app_theme.dart';
import '../../../core/i18n/app_localizations.dart';

/// Güvenlik tehdidi tespit edildiğinde gösterilen ekran.
///
/// - Kritik tehdit (root, hooking, debugger): uygulamaya devam ENGELLENİR
/// - Uyarı (emulator, dev mode): kullanıcı "yine de devam et" diyebilir
class SecurityWarningScreen extends StatelessWidget {
  final SecurityCheckResult result;
  // Sadece uyari durumunda. Ekranin KENDI context'i verilir — cagiranin
  // (muhtemelen coktan yok edilmis) state'ine bagimlilik yoktur.
  final void Function(BuildContext context)? onContinueAnyway;

  const SecurityWarningScreen({
    super.key,
    required this.result,
    this.onContinueAnyway,
  });

  @override
  Widget build(BuildContext context) {
    final hasCritical = result.hasCriticalThreat;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                hasCritical ? Icons.gpp_bad : Icons.gpp_maybe,
                size: 72,
                color: hasCritical ? AppTheme.danger : const Color(0xFFFFA726),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(hasCritical ? 'sec_risk_title' : 'sec_warn_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(hasCritical ? 'sec_risk_desc' : 'sec_warn_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 32),

              // Tehdit listesi
              ...result.threats.map((threat) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: threat.isCritical
                            ? AppTheme.danger.withValues(alpha: 0.5)
                            : const Color(0xFFFFA726).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          threat.isCritical ? Icons.error : Icons.warning_amber,
                          color: threat.isCritical
                              ? AppTheme.danger
                              : const Color(0xFFFFA726),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr(threat.titleKey),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr(threat.descriptionKey),
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),

              const SizedBox(height: 24),

              // Sadece kritik değilse "devam et" izni
              if (!hasCritical && onContinueAnyway != null)
                ElevatedButton(
                  onPressed: () => onContinueAnyway!(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA726),
                  ),
                  child: Text(context.tr('understood_continue')),
                ),

              if (hasCritical)
                const Text(
                  'Güvenli bir cihazda tekrar deneyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
