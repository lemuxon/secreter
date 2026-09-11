import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/story_notifier.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/widgets/image_picker_helper.dart';
import '../../../../core/widgets/photo_editor_screen.dart';

/// Durum/hikaye oluşturma ekranı (yeni mimari).
class StoryCreatorScreen extends ConsumerStatefulWidget {
  const StoryCreatorScreen({super.key});

  @override
  ConsumerState<StoryCreatorScreen> createState() => _StoryCreatorScreenState();
}

class _StoryCreatorScreenState extends ConsumerState<StoryCreatorScreen> {
  final _textController = TextEditingController();
  File? _pickedImage; // secilen fotograf (onizlemede bekler)
  int _bgColorIndex = 0;

  static const _bgColors = [
    '#2AABEE',
    '#E91E63',
    '#4CAF50',
    '#9C27B0',
    '#FF5722',
    '#3F51B5',
    '#009688',
    '#795548',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Color _color(String hex) => Color(int.parse(hex.replaceFirst('#', '0xff')));

  Future<void> _postText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final ok = await ref
        .read(storyNotifierProvider.notifier)
        .postText(text, _bgColors[_bgColorIndex]);
    if (ok && mounted) Navigator.pop(context);
  }

  /// Fotoğraf SEÇ (hemen paylaşmaz).
  ///
  /// ESKİ DAVRANIŞ: fotoğraf seçilir seçilmez paylaşılıyordu; üzerine yazı
  /// eklemek imkânsızdı. Artık seçilen fotoğraf ÖNİZLEME olarak gösterilir,
  /// üzerine yazı yazılabilir ve paylaş düğmesiyle gönderilir.
  Future<void> _pickImage() async {
    // ✂️ Seçim + KIRPMA/DÖNDÜRME
    final path = await ImagePickerHelper.pickAndCrop(
      context,
      allowEdit: true,
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (path == null || !mounted) return;
    setState(() => _pickedImage = File(path));
  }

  /// Seçili fotoğrafı yeniden düzenle (editörü tekrar aç).
  Future<void> _reEdit() async {
    final img = _pickedImage;
    if (img == null) return;
    final edited = await PhotoEditorScreen.open(context, img.path);
    if (edited == null || !mounted) return;
    setState(() => _pickedImage = File(edited));
  }

  Future<void> _postImage() async {
    final img = _pickedImage;
    if (img == null) return;
    final caption = _textController.text.trim();
    final ok = await ref
        .read(storyNotifierProvider.notifier)
        .postImage(img, caption.isEmpty ? null : caption);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isPosting = ref.watch(storyNotifierProvider).isPosting;

    return Scaffold(
      backgroundColor: _pickedImage == null
          ? _color(_bgColors[_bgColorIndex])
          : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(context.tr('create_status')),
        actions: [
          IconButton(
            icon: const Icon(Icons.image, color: Colors.white),
            // Artik yalnizca SECER; paylasim FAB ile yapilir
            onPressed: isPosting ? null : _pickImage,
            tooltip: context.tr('photo_status'),
          ),
        ],
      ),
      body: isPosting
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Secilen fotograf ARKA PLAN olur; yazi UZERINE gelir
                      if (_pickedImage != null)
                        Image.file(
                          _pickedImage!,
                          fit: BoxFit.contain,
                          // ÖNBELLEK SORUNU: Flutter aynı yol için
                          // görüntüyü önbellekler. Editörden dönen yeni
                          // dosya farklı bir yol taşısa da widget
                          // yeniden kurulmazsa eski kare görünüyordu.
                          // `key` dosya yolunu içerince widget
                          // gerçekten yenilenir.
                          key: ValueKey(_pickedImage!.path),
                        ),
                      if (_pickedImage != null)
                        // Yazi okunabilirligi icin hafif karartma
                        Container(color: Colors.black26),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: TextField(
                            controller: _textController,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            maxLines: null,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: _pickedImage == null
                                  ? context.tr('whats_on_mind')
                                  : context.tr('add_caption'),
                              hintStyle: const TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      // Fotograf secilmisse: düzenle + kaldır
                      if (_pickedImage != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            children: [
                              // ✏️ TEKRAR DÜZENLE — editöre dönüş yolu.
                              // Eskiden bir kez düzenledikten sonra
                              // editöre geri dönmek mümkün değildi.
                              IconButton(
                                icon: const Icon(Icons.brush_outlined,
                                    color: Colors.white),
                                tooltip: context.tr('edit_photo'),
                                onPressed: _reEdit,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                tooltip: context.tr('cancel_it'),
                                onPressed: () =>
                                    setState(() => _pickedImage = null),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Renk secimi yalnizca METIN modunda anlamli
                if (_pickedImage == null)
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _bgColors.length,
                      itemBuilder: (context, i) {
                        final selected = i == _bgColorIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _bgColorIndex = i),
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 10),
                            decoration: BoxDecoration(
                              color: _color(_bgColors[i]),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: selected ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
      floatingActionButton: isPosting
          ? null
          : FloatingActionButton(
              // Fotograf secilmisse fotografi+yaziyi, degilse metni paylas
              onPressed: _pickedImage == null ? _postText : _postImage,
              backgroundColor: Colors.white,
              child: Icon(Icons.send,
                  color: _pickedImage == null
                      ? _color(_bgColors[_bgColorIndex])
                      : Colors.black),
            ),
    );
  }
}
