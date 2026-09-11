import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/theme/chat_wallpaper.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/widgets/image_picker_helper.dart';

/// #7 — Sohbete özel fotoğraf arka planı:
/// galeriden foto seç + bulanıklık + karartma, CANLI önizlemeli.
/// Her sohbet için ayrı saklanır; "Fotoğrafı kaldır" preset'e döndürür.
class ChatBackgroundScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatTitle;
  const ChatBackgroundScreen(
      {super.key, required this.chatId, required this.chatTitle});

  @override
  ConsumerState<ChatBackgroundScreen> createState() =>
      _ChatBackgroundScreenState();
}

class _ChatBackgroundScreenState extends ConsumerState<ChatBackgroundScreen> {
  String? _path;
  double _blur = 0;
  double _darken = 0.25;
  bool _loadedInitial = false;

  @override
  Widget build(BuildContext context) {
    // Mevcut kayitli ayari ilk gelişte forma yükle
    final saved = ref.watch(chatBgPhotoProvider(widget.chatId));
    if (!_loadedInitial && saved != null) {
      _path = saved.path;
      _blur = saved.blur;
      _darken = saved.darken;
      _loadedInitial = true;
    }
    final hasPhoto = _path != null && File(_path!).existsSync();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(context.tr('chat_background'),
            style: const TextStyle(color: AppTheme.textPrimary)),
      ),
      body: Column(
        children: [
          // ---- CANLI ÖNİZLEME ----
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasPhoto)
                      ImageFiltered(
                        imageFilter:
                            ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
                        child: Image.file(File(_path!), fit: BoxFit.cover),
                      )
                    else
                      Container(
                        decoration:
                            const BoxDecoration(color: AppTheme.background),
                        child: Center(
                          child: Text(context.tr('no_photo_selected'),
                              style: const TextStyle(
                                  color: AppTheme.textSecondary)),
                        ),
                      ),
                    if (hasPhoto)
                      ColoredBox(
                          color: Colors.black.withValues(alpha: _darken)),
                    // Örnek balonlar (okunabilirlik önizlemesi)
                    Positioned(
                      left: 14,
                      bottom: 64,
                      child: _demoBubble(context.tr('bg_sample_hi'), false),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 18,
                      child: _demoBubble(context.tr('bg_sample_q'), true),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ---- KONTROLLER ----
          Container(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPhoto) ...[
                  _slider(context.tr('blur'), _blur, 0, 20,
                      (v) => setState(() => _blur = v)),
                  _slider(context.tr('dim'), _darken, 0, 0.7,
                      (v) => setState(() => _darken = v)),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library_outlined,
                            color: AppTheme.primary),
                        label: Text(
                            hasPhoto
                                ? context.tr('change_photo')
                                : context.tr('pick_gallery'),
                            style: const TextStyle(color: AppTheme.primary)),
                        onPressed: _pick,
                      ),
                    ),
                    if (hasPhoto) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _save,
                          child: Text(context.tr('save')),
                        ),
                      ),
                    ],
                  ],
                ),
                if (saved != null)
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(chatBgPhotoProvider(widget.chatId).notifier)
                          .clear();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(context.tr('remove_photo_default'),
                        style: const TextStyle(color: AppTheme.danger)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _demoBubble(String text, bool mine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: mine ? AppTheme.bubbleSent : AppTheme.bubbleReceived,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
    );
  }

  Future<void> _pick() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (picked == null || !mounted) return;
    // ✂️ Duvar kâğıdını kırp/döndür (ekrana nasıl oturacağını seçsin)
    final croppedPath =
        await ImagePickerHelper.cropExisting(context, picked.path);
    if (croppedPath == null) return;
    // KALICILIK: image_picker'in cache yolu temizlenebilir; fotoyu uygulama
    // belgeler klasörüne kopyala (sohbet başına tek dosya, üstüne yazar).
    final dir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${dir.path}/chat_bg');
    if (!bgDir.existsSync()) bgDir.createSync(recursive: true);
    final dest = '${bgDir.path}/${widget.chatId}.jpg';
    await File(croppedPath).copy(dest);
    // Ayni yola yazildiginda Image cache eski kareyi gosterebilir; temizle.
    FileImage(File(dest)).evict();
    if (!mounted) return;
    setState(() => _path = dest);
  }

  Future<void> _save() async {
    if (_path == null) return;
    await ref
        .read(chatBgPhotoProvider(widget.chatId).notifier)
        .save(ChatBgPhoto(path: _path!, blur: _blur, darken: _darken));
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
