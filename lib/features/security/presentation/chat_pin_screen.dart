import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/security/chat_lock_service.dart';
import '../../../core/i18n/app_localizations.dart';

/// Sohbet kilidi PIN ekranı.
/// - setup: yeni PIN belirle (iki kez onay)
/// - verify: kilitli sohbeti açmak için PIN doğrula
class ChatPinScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;
  final bool setup;

  const ChatPinScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.setup,
  });

  @override
  State<ChatPinScreen> createState() => _ChatPinScreenState();
}

class _ChatPinScreenState extends State<ChatPinScreen> {
  String _pin = '';
  String _first = '';
  String? _error;
  bool _confirming = false;

  static const int _len = 4;

  Future<void> _onDigit(String d) async {
    if (_pin.length >= _len) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == _len) {
      await Future.delayed(const Duration(milliseconds: 120));
      _submit();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (widget.setup) {
      if (!_confirming) {
        setState(() {
          _first = _pin;
          _pin = '';
          _confirming = true;
        });
      } else {
        if (_pin == _first) {
          await ChatLockService.setPin(widget.chatId, _pin);
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() {
            _pin = '';
            _first = '';
            _confirming = false;
            _error = 'PIN\'ler eşleşmedi, tekrar deneyin';
          });
        }
      }
    } else {
      final ok = await ChatLockService.verifyPin(widget.chatId, _pin);
      if (ok) {
        if (mounted) Navigator.pop(context, true);
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _pin = '';
          _error = context.tr('wrong_pin');
        });
      }
    }
  }

  String get _title {
    if (!widget.setup) return context.tr('enter_pin');
    return _confirming ? 'PIN\'i tekrar girin' : 'Yeni PIN belirle';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.chatTitle,
            style: const TextStyle(color: AppTheme.textPrimary)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.lock, color: AppTheme.primary, size: 48),
            const SizedBox(height: 20),
            Text(_title,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_len, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppTheme.primary : Colors.transparent,
                    border: Border.all(color: AppTheme.primary, width: 1.5),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 20,
              child: Text(_error ?? '',
                  style: const TextStyle(color: AppTheme.danger)),
            ),
            const Spacer(),
            _keypad(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _keypad() {
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) {
      return SizedBox(
        width: 78,
        height: 78,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: icon != null
                  ? Icon(icon, color: AppTheme.textPrimary, size: 26)
                  : Text(label,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w500)),
            ),
          ),
        ),
      );
    }

    Widget row(List<Widget> c) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: c
            .map((w) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8), child: w))
            .toList());

    return Column(
      children: [
        row([
          key('1', onTap: () => _onDigit('1')),
          key('2', onTap: () => _onDigit('2')),
          key('3', onTap: () => _onDigit('3')),
        ]),
        row([
          key('4', onTap: () => _onDigit('4')),
          key('5', onTap: () => _onDigit('5')),
          key('6', onTap: () => _onDigit('6')),
        ]),
        row([
          key('7', onTap: () => _onDigit('7')),
          key('8', onTap: () => _onDigit('8')),
          key('9', onTap: () => _onDigit('9')),
        ]),
        row([
          const SizedBox(width: 78),
          key('0', onTap: () => _onDigit('0')),
          key('', icon: Icons.backspace_outlined, onTap: _onDelete),
        ]),
      ],
    );
  }
}
