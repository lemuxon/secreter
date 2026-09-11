import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../main.dart' show rootNavigatorKey;
import '../../../services/deep_link_service.dart';
import '../../../services/privacy_service.dart';
import '../../../services/biometric_service.dart';
import '../../../utils/app_theme.dart';
import '../../../core/i18n/app_localizations.dart';

enum LockMode { setup, verify, setupDecoy, change }

/// PIN giriş ekranı.
/// - setup: ilk PIN belirleme
/// - verify: açılışta kilit doğrulama
/// - setupDecoy: sahte PIN belirleme
/// - change: PIN değiştirme
class PinLockScreen extends StatefulWidget {
  final LockMode mode;
  final VoidCallback? onSuccess; // Doğru PIN
  final VoidCallback? onDecoyEntered; // Sahte PIN girildi

  const PinLockScreen({
    super.key,
    required this.mode,
    this.onSuccess,
    this.onDecoyEntered,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  String _firstPin = ''; // setup'ta onaylama için
  bool _confirming = false;
  String? _error;
  bool _biometricAvailable = false;
  int _attempts = 0;

  static const int _pinLength = 6;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    if (widget.mode == LockMode.verify) {
      final enabled = await PrivacyService.isBiometricEnabled();
      final available = await BiometricService.isAvailable();
      if (enabled && available) {
        setState(() => _biometricAvailable = true);
        _tryBiometric();
      }
    }
  }

  Future<void> _tryBiometric() async {
    // Çeviri ANAHTARI değil, çevrilmiş METİN geçilir — aksi halde sistem
    // diyalogunda kullanıcıya "biometric_prompt" yazısı görünüyordu.
    final ok = await BiometricService.authenticate(
      reason: context.tr('biometric_prompt'),
    );
    if (ok && mounted) {
      _unlockSucceeded();
    }
  }

  /// Kilit açıldığında: bekleyen derin bağlantıyı da işle.
  void _unlockSucceeded() {
    widget.onSuccess?.call();
    // Kilitliyken gelen davet bağlantısı beklemeye alınmıştı; şimdi güvenli.
    DeepLinkService.processPending(rootNavigatorKey);
  }

  void _onDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == _pinLength) {
      _onComplete();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _onComplete() async {
    switch (widget.mode) {
      case LockMode.setup:
      case LockMode.change:
      case LockMode.setupDecoy:
        if (!_confirming) {
          // İlk giriş — onay iste
          setState(() {
            _firstPin = _pin;
            _confirming = true;
            _pin = '';
          });
        } else {
          // Onay girişi
          if (_pin == _firstPin) {
            if (widget.mode == LockMode.setupDecoy) {
              await PrivacyService.setDecoyPin(_pin);
            } else {
              await PrivacyService.setPin(_pin);
            }
            if (mounted) {
              Navigator.pop(context, true);
            }
          } else {
            setState(() {
              _error = 'PIN\'ler eşleşmiyor, tekrar dene';
              _pin = '';
              _firstPin = '';
              _confirming = false;
            });
          }
        }
        break;

      case LockMode.verify:
        // ── KABA KUVVET KORUMASI ──
        // Eskiden deneme sayısı yalnızca ekranda gösteriliyor, hiçbir
        // sınır uygulanmıyordu: saldırgan 4-6 haneli PIN'i sınırsız
        // deneyebiliyordu. Artık gecikme sunucusuz da olsa kalıcı
        // (secure storage) ve uygulama yeniden başlatmayla sıfırlanmaz.
        final wait = await PrivacyService.lockoutRemaining();
        if (wait > Duration.zero) {
          if (!mounted) return;
          setState(() {
            _error = context.tr('lock_too_many_attempts') + _formatWait(wait);
            _pin = '';
          });
          HapticFeedback.heavyImpact();
          return;
        }

        // Önce sahte PIN kontrolü (panik modu)
        if (await PrivacyService.isDecoyPin(_pin)) {
          widget.onDecoyEntered?.call();
          return;
        }
        // Gerçek PIN
        if (await PrivacyService.verifyPin(_pin)) {
          _unlockSucceeded();
        } else {
          _attempts = await PrivacyService.failedAttempts();
          final next = await PrivacyService.lockoutRemaining();
          if (!mounted) return;
          setState(() {
            _error = next > Duration.zero
                ? context.tr('lock_too_many_attempts') + _formatWait(next)
                : '${context.tr('wrong_pin')} ($_attempts)';
            _pin = '';
          });
          HapticFeedback.heavyImpact();
        }
        break;
    }
  }

  static String _formatWait(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes} dk';
    return '${d.inSeconds} sn';
  }

  String get _titleText {
    switch (widget.mode) {
      case LockMode.setup:
      case LockMode.change:
        return _confirming ? 'PIN\'i tekrar gir' : 'Yeni PIN belirle';
      case LockMode.setupDecoy:
        return _confirming ? 'Sahte PIN\'i tekrar gir' : 'Sahte PIN belirle';
      case LockMode.verify:
        return context.tr('enter_pin');
    }
  }

  String get _subtitleText {
    switch (widget.mode) {
      case LockMode.setupDecoy:
        return context.tr('decoy_pin_note');
      case LockMode.verify:
        return 'Devam etmek için PIN\'ini gir';
      default:
        return '6 haneli bir PIN seç';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            const Icon(Icons.lock_rounded, color: AppTheme.primary, size: 56),
            const SizedBox(height: 24),
            Text(
              _titleText,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitleText,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 36),

            // PIN noktaları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppTheme.primary : Colors.transparent,
                    border: Border.all(
                      color: filled ? AppTheme.primary : AppTheme.textSecondary,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13)),

            const Spacer(flex: 1),

            // Tuş takımı
            _buildKeypad(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          for (var row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((d) => _keypadButton(d)).toList(),
            ),
          // Son satır: biyometrik / 0 / sil
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _biometricAvailable
                  ? _iconButton(Icons.fingerprint, _tryBiometric)
                  : const SizedBox(width: 72, height: 72),
              _keypadButton('0'),
              _iconButton(Icons.backspace_outlined, _onBackspace),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keypadButton(String digit) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: AppTheme.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _onDigit(digit),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Text(digit,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(icon, color: AppTheme.textSecondary, size: 28),
        ),
      ),
    );
  }
}
