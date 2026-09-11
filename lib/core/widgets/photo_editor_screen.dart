import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../i18n/app_localizations.dart';
import '../../utils/app_theme.dart';
import 'image_picker_helper.dart';

/// 🎨 FOTOĞRAF EDİTÖRÜ
///
/// MİMARİ NOTU — neden yeniden yazıldı:
///
/// İlk sürümde her katmanın (emoji, yazı) KENDİ `GestureDetector`'ı
/// vardı, üstüne fotoğrafta çizim için bir tane daha. Flutter'ın jest
/// arenasında bunlar birbiriyle yarışıyordu:
///   • İki parmak jesti bazen katmana hiç ulaşmıyordu → dönmüyor,
///     büyümüyordu
///   • `Transform.scale` içindeki ✕ düğmesi ölçekle birlikte kayıyor,
///     dokunma hedefi görsel konumdan sapıyordu → işlevsiz kalıyordu
///   • `FractionalTranslation` + `Positioned` birlikte dokunma hesabını
///     bozuyordu
///
/// ÇÖZÜM — TEK JEST KAPISI:
/// Tüm dokunmalar tuvalin TEK `GestureDetector`'ından geçer. Hangi
/// öğenin hedeflendiği koordinat hesabıyla belirlenir. Katmanlar
/// `IgnorePointer` ile sarılıdır: yalnızca çizilirler, jest yakalamazlar.
/// Böylece arena çakışması YAPISAL OLARAK imkânsız hale gelir.
class PhotoEditorScreen extends StatefulWidget {
  final String imagePath;
  const PhotoEditorScreen({super.key, required this.imagePath});

  static Future<String?> open(BuildContext context, String path) {
    return Navigator.of(context).push<String>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoEditorScreen(imagePath: path),
    ));
  }

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  const _Stroke(this.points, this.color, this.width);
}

/// Fotoğraf üstündeki taşınabilir öğe (emoji veya yazı).
/// Tek sınıf: davranışları birebir aynı, ayırmak kod tekrarıydı.
class _Item {
  final bool isText;
  String content;
  Offset pos; // 0-1 oranlı merkez
  double scale;
  double rotation;
  Color color;

  // NOT: `scale` ve `rotation` yalnızca jestlerle DEĞİŞTİRİLİR, kurucudan
  // hiç verilmez. Kurucu parametresi olarak durmaları "kullanılmayan
  // parametre" uyarısı üretiyordu; alanlar varsayılanla başlatılır.
  _Item({
    required this.isText,
    required this.content,
    required this.pos,
    this.color = Colors.white,
  })  : scale = 1.0,
        rotation = 0;

  /// Dokunma hedefi yarıçapı — ölçekle birlikte büyür.
  double get radius {
    final base = isText ? math.max(70.0, content.length * 8.0) : 40.0;
    return base * scale;
  }
}

class _TextResult {
  final String text;
  final Color color;
  const _TextResult(this.text, this.color);
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();

  /// Üzerinde çalışılan görüntü. Kırpma yapılınca DEĞİŞİR — bu yüzden
  /// widget.imagePath yerine bu kullanılır.
  late String _workingPath = widget.imagePath;

  final List<_Stroke> _strokes = [];
  List<Offset>? _currentStroke;

  final List<_Item> _items = [];
  int? _activeIndex;

  bool _drawMode = false;
  Color _penColor = Colors.white;
  double _penWidth = 6;
  bool _saving = false;

  // Jest başlangıç durumu. `d.scale`/`d.rotation` jestin BAŞINDAN
  // itibaren kümülatiftir; her karede mevcut değere çarpmak üstel
  // büyüme yaratıyordu. Başlangıca uygulanır → birebir orantılı.
  double _startScale = 1;
  double _startRotation = 0;
  int? _dragIndex;

  Size _canvas = Size.zero;

  static const _palette = [
    Colors.white,
    Colors.black,
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFF0A84FF),
    Color(0xFF5856D6),
    Color(0xFFAF52DE),
    Color(0xFFFF2D55),
  ];

  // ------------------------------------------------------------
  // JEST — TEK KAPI
  // ------------------------------------------------------------

  Offset _center(_Item it) =>
      Offset(it.pos.dx * _canvas.width, it.pos.dy * _canvas.height);

  int? _hitTest(Offset p) {
    if (_canvas == Size.zero) return null;
    for (var i = _items.length - 1; i >= 0; i--) {
      if ((p - _center(_items[i])).distance <= _items[i].radius) return i;
    }
    return null;
  }

  Offset? _closeBtn() {
    final i = _activeIndex;
    if (i == null || _canvas == Size.zero) return null;
    final it = _items[i];
    return _center(it) + Offset(it.radius * 0.8, -it.radius * 0.8);
  }

  Offset? _editBtn() {
    final i = _activeIndex;
    if (i == null || _canvas == Size.zero) return null;
    final it = _items[i];
    if (!it.isText) return null;
    return _center(it) + Offset(-it.radius * 0.8, -it.radius * 0.8);
  }

  void _onStart(ScaleStartDetails d) {
    final p = d.localFocalPoint;

    if (_drawMode) {
      setState(() => _currentStroke = [p]);
      return;
    }

    // Düğmeler önce (küçük hedefler öncelikli)
    final close = _closeBtn();
    if (close != null && (p - close).distance < 30) {
      setState(() {
        _items.removeAt(_activeIndex!);
        _activeIndex = null;
        _dragIndex = null;
      });
      return;
    }
    final edit = _editBtn();
    if (edit != null && (p - edit).distance < 30) {
      final idx = _activeIndex!;
      _dragIndex = null;
      _editItem(idx);
      return;
    }

    final hit = _hitTest(p);
    setState(() {
      _activeIndex = hit;
      _dragIndex = hit;
      if (hit != null) {
        _startScale = _items[hit].scale;
        _startRotation = _items[hit].rotation;
      }
    });
  }

  void _onUpdate(ScaleUpdateDetails d) {
    if (_drawMode) {
      if (_currentStroke != null) {
        setState(() => _currentStroke!.add(d.localFocalPoint));
      }
      return;
    }

    final i = _dragIndex;
    if (i == null || i >= _items.length || _canvas == Size.zero) return;
    final it = _items[i];

    setState(() {
      // İKİ PARMAK: aç → büyüt, kapat → küçült, döndür → dön
      if (d.pointerCount >= 2) {
        it.scale = (_startScale * d.scale).clamp(0.25, 8.0);
        it.rotation = _startRotation + d.rotation;
      }
      // Öğe her durumda parmağın odak noktasını takip eder
      it.pos = Offset(
        (d.localFocalPoint.dx / _canvas.width).clamp(0.03, 0.97),
        (d.localFocalPoint.dy / _canvas.height).clamp(0.05, 0.95),
      );
    });
  }

  void _onEnd(ScaleEndDetails d) {
    if (_drawMode && _currentStroke != null) {
      setState(() {
        _strokes.add(_Stroke(List.of(_currentStroke!), _penColor, _penWidth));
        _currentStroke = null;
      });
      return;
    }
    _dragIndex = null;
  }

  // ------------------------------------------------------------
  // ÖĞE İŞLEMLERİ
  // ------------------------------------------------------------

  void _undo() {
    setState(() {
      if (_activeIndex != null) {
        _items.removeAt(_activeIndex!);
        _activeIndex = null;
      } else if (_items.isNotEmpty) {
        _items.removeLast();
      } else if (_strokes.isNotEmpty) {
        _strokes.removeLast();
      }
    });
  }

  Future<void> _addText() async {
    final r = await _textDialog();
    if (r == null || r.text.isEmpty) return;
    setState(() {
      _items.add(_Item(
          isText: true,
          content: r.text,
          pos: const Offset(0.5, 0.45),
          color: r.color));
      _activeIndex = _items.length - 1;
      _drawMode = false;
    });
  }

  Future<void> _editItem(int i) async {
    if (i >= _items.length) return;
    final it = _items[i];
    if (!it.isText) return;
    final r =
        await _textDialog(initialText: it.content, initialColor: it.color);
    if (r == null || !mounted) return;
    setState(() {
      if (r.text.isEmpty) {
        _items.removeAt(i);
        _activeIndex = null;
      } else {
        it.content = r.text;
        it.color = r.color;
      }
    });
  }

  /// ✂️ Mevcut görüntüyü kırp/döndür — sonuç editörde devam eder.
  ///
  /// NOT: Çizimler ve öğeler EKRANA göre konumlandığı için kırpma
  /// sonrası oranları kayabilir. Bu yüzden kırpma yapıldığında
  /// kullanıcı uyarılır ve isterse öğeler korunur (oransal konum
  /// zaten 0-1 aralığında, çoğu durumda makul kalır).
  Future<void> _cropCurrent() async {
    final cropped = await ImagePickerHelper.cropExisting(context, _workingPath);
    if (cropped == null || !mounted) return;
    setState(() => _workingPath = cropped);
  }

  Future<void> _addSticker() async {
    final picked = await _stickerPicker();
    if (picked == null || !mounted) return;
    setState(() {
      _items.add(
          _Item(isText: false, content: picked, pos: const Offset(0.5, 0.45)));
      _activeIndex = _items.length - 1;
      _drawMode = false;
    });
  }

  // ------------------------------------------------------------
  // KAYDET
  // ------------------------------------------------------------

  Future<void> _save() async {
    setState(() {
      _activeIndex = null; // seçim göstergeleri görüntüye girmesin
      _saving = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    try {
      final b = _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('görüntü alınamadı');

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (e) {
      debugPrint('Editör kaydetme hatası: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('editor_save_failed'))),
      );
    }
  }

  // ------------------------------------------------------------
  // ARAYÜZ
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_items.isNotEmpty || _strokes.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.undo),
                tooltip: context.tr('undo'),
                onPressed: _undo),
          IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined),
              tooltip: context.tr('add_sticker'),
              onPressed: _addSticker),
          IconButton(
              icon: const Icon(Icons.text_fields),
              tooltip: context.tr('add_text'),
              onPressed: _addText),
          IconButton(
            icon: Icon(Icons.brush,
                color: _drawMode ? AppTheme.primary : Colors.white),
            tooltip: context.tr('draw'),
            onPressed: () => setState(() {
              _drawMode = !_drawMode;
              _activeIndex = null;
            }),
          ),
          // ✂️ KIRPMA/DÖNDÜRME artık AYNI EKRANDA.
          // Eskiden ayrı adımdı ve "düzenle / olduğu gibi gönder"
          // sorusu araya giriyordu — akış bölünüyordu.
          IconButton(
            icon: const Icon(Icons.crop_rotate),
            tooltip: context.tr('crop_rotate'),
            onPressed: _saving ? null : _cropCurrent,
          ),
        ],
      ),
      body: Column(
        children: [
          // KULLANICI YÖNLENDİRMESİ: hangi jestin ne yaptığı yazılı.
          // Editörler sezgisel değildir; ipucu şeridi öğrenme yükünü alır.
          _hintBar(),
          Expanded(
            child: Center(
              child: LayoutBuilder(builder: (context, box) {
                final s = Size(box.maxWidth, box.maxHeight);
                if (_canvas != s) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _canvas = s);
                  });
                }
                return RepaintBoundary(
                  key: _canvasKey,
                  // ⬇️ TEK JEST KAPISI
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _onStart,
                    onScaleUpdate: _onUpdate,
                    onScaleEnd: _onEnd,
                    child: Stack(
                      children: [
                        Image.file(
                          File(_workingPath),
                          fit: BoxFit.contain,
                          width: box.maxWidth,
                          height: box.maxHeight,
                          // Kırpma sonrası yeni dosya gösterilsin diye
                          // anahtar yola bağlı (Flutter görüntü önbelleği)
                          key: ValueKey(_workingPath),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DrawPainter(
                              strokes: _strokes,
                              current: _currentStroke,
                              currentColor: _penColor,
                              currentWidth: _penWidth,
                            ),
                          ),
                        ),
                        for (var i = 0; i < _items.length; i++)
                          _itemWidget(i, box.maxWidth, box.maxHeight),
                        if (_activeIndex != null && !_saving) ..._buttons(),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          if (_drawMode) _penTools(),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _hintBar() {
    final String key;
    final Color bg;
    if (_drawMode) {
      key = 'editor_hint_draw';
      bg = AppTheme.primary.withValues(alpha: 0.18);
    } else if (_activeIndex != null) {
      key = 'editor_hint_item';
      bg = Colors.white12;
    } else if (_items.isEmpty && _strokes.isEmpty) {
      key = 'editor_hint_start';
      bg = Colors.white10;
    } else {
      key = 'editor_hint_tap';
      bg = Colors.white10;
    }
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
      child: Text(context.tr(key),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
    );
  }

  /// Öğenin görseli — `IgnorePointer` ile jestlerden yalıtılmış.
  Widget _itemWidget(int i, double w, double h) {
    final it = _items[i];
    final active = _activeIndex == i && !_saving;
    return Positioned(
      left: it.pos.dx * w,
      top: it.pos.dy * h,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Transform.rotate(
            angle: it.rotation,
            child: Transform.scale(
              scale: it.scale,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: active
                      ? Border.all(color: Colors.white70, width: 1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: it.isText
                    ? Text(it.content,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: it.color,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 6)
                          ],
                        ))
                    : Text(it.content, style: const TextStyle(fontSize: 46)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ✕ ve ✏️ — Transform DIŞINDA, SABİT boyutlu.
  /// Ölçek büyüse de düğmeler aynı boyutta kalır ve dokunma hedefi
  /// görsel konumla birebir örtüşür.
  List<Widget> _buttons() {
    final close = _closeBtn();
    final edit = _editBtn();
    Widget btn(IconData icon) => IgnorePointer(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        );
    return [
      if (close != null)
        Positioned(
            left: close.dx - 17, top: close.dy - 17, child: btn(Icons.close)),
      if (edit != null)
        Positioned(
            left: edit.dx - 17, top: edit.dy - 17, child: btn(Icons.edit)),
    ];
  }

  Widget _penTools() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.line_weight, color: Colors.white54, size: 18),
              Expanded(
                child: Slider(
                  value: _penWidth,
                  min: 2,
                  max: 26,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _penWidth = v),
                ),
              ),
            ],
          ),
          _colorRow((c) => setState(() => _penColor = c), _penColor),
        ],
      ),
    );
  }

  Widget _colorRow(ValueChanged<Color> onPick, Color selected) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (final c in _palette)
            GestureDetector(
              onTap: () => onPick(c),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == selected ? Colors.white : Colors.white24,
                    width: c == selected ? 3 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(context.tr('cancel'),
                    style: const TextStyle(color: Colors.white70)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(context.tr('done')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<_TextResult?> _textDialog({
    String initialText = '',
    Color initialColor = Colors.white,
  }) async {
    final ctrl = TextEditingController(text: initialText);
    Color chosen = initialColor;

    final text = await showDialog<String>(
      context: context,
      // ŞEFFAF ZEMİN: fotoğraf arkada görünsün, yalnızca yazı ve
      // imleç öne çıksın (Instagram davranışı).
      barrierColor: Colors.black38,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(ctx.tr('cancel'),
                          style: const TextStyle(color: Colors.white70)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: Text(ctx.tr('done'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        controller: ctrl,
                        autofocus: true,
                        maxLines: null,
                        textAlign: TextAlign.center,
                        cursorColor: Colors.white,
                        style: TextStyle(
                          color: chosen,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 8)
                          ],
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: ctx.tr('type_something'),
                          hintStyle: const TextStyle(
                              color: Colors.white38, fontSize: 26),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final c in _palette)
                        GestureDetector(
                          onTap: () => setInner(() => chosen = c),
                          child: Container(
                            width: 34,
                            height: 34,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 11),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    c == chosen ? Colors.white : Colors.white24,
                                width: c == chosen ? 3 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (text == null) return null;
    return _TextResult(text, chosen);
  }

  Future<String?> _stickerPicker() {
    const groups = <String, List<String>>{
      'yuz': [
        '😀',
        '😃',
        '😄',
        '😁',
        '😆',
        '😅',
        '😂',
        '🤣',
        '🥲',
        '🥹',
        '😊',
        '😇',
        '🙂',
        '🙃',
        '😉',
        '😌',
        '😍',
        '🥰',
        '😘',
        '😗',
        '😋',
        '😛',
        '🤪',
        '🤨',
        '🧐',
        '🤓',
        '😎',
        '🥸',
        '🤩',
        '🥳',
        '😏',
        '😒',
        '😞',
        '😔',
        '😟',
        '🙁',
        '😣',
        '😖',
        '😫',
        '😩',
        '🥺',
        '😢',
        '😭',
        '😤',
        '😠',
        '😡',
        '🤬',
        '🤯',
        '😳',
        '🥵',
        '🥶',
        '😱',
        '😨',
        '😰',
        '😥',
        '😓',
        '🤗',
        '🤔',
        '🤭',
        '🤫',
        '😶',
        '😐',
        '😑',
        '😬',
        '🙄',
        '😯',
        '😦',
        '😧',
        '😮',
        '😲',
        '🥱',
        '😴',
        '🤤',
        '😪',
        '😵',
        '🤐',
        '🥴',
        '🤢',
        '🤮',
        '🤧',
        '😷',
        '🤒',
        '🤕',
        '🤑',
        '🤠',
        '😈',
        '👿',
        '💀',
        '👻',
        '👽',
        '🤖',
        '🎃',
        '😺',
        '😸',
        '😹',
        '😻',
        '😼',
        '🙀',
        '😿',
        '😾'
      ],
      'el': [
        '👍',
        '👎',
        '👌',
        '🤌',
        '🤏',
        '✌️',
        '🤞',
        '🫰',
        '🤟',
        '🤘',
        '🤙',
        '👈',
        '👉',
        '👆',
        '👇',
        '☝️',
        '🫵',
        '👋',
        '🤚',
        '🖐️',
        '✋',
        '🖖',
        '👏',
        '🙌',
        '🫶',
        '👐',
        '🤲',
        '🤝',
        '🙏',
        '✍️',
        '💪',
        '🦾',
        '🦵',
        '🦶',
        '👂',
        '👃',
        '👀',
        '👁️',
        '👅',
        '👄'
      ],
      'kalp': [
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🖤',
        '🤍',
        '🤎',
        '💔',
        '❣️',
        '💕',
        '💞',
        '💓',
        '💗',
        '💖',
        '💘',
        '💝',
        '💟',
        '♥️',
        '✨',
        '⭐',
        '🌟',
        '💫',
        '⚡',
        '🔥',
        '💥',
        '💢',
        '💦',
        '💨'
      ],
      'nesne': [
        '🎉',
        '🎊',
        '🎈',
        '🎁',
        '🏆',
        '🥇',
        '🎯',
        '🎮',
        '🎲',
        '🎨',
        '🎵',
        '🎶',
        '🎧',
        '🎤',
        '📷',
        '📸',
        '🎬',
        '📱',
        '💻',
        '⌚',
        '💎',
        '👑',
        '🕶️',
        '👟',
        '🧢',
        '🎒',
        '☂️',
        '🌈',
        '☀️',
        '🌙',
        '☁️',
        '❄️',
        '🌊',
        '🌸',
        '🌹',
        '🌻',
        '🌷',
        '🍀',
        '🌴',
        '🌵',
        '🍕',
        '🍔',
        '🍟',
        '🌮',
        '🍿',
        '🍩',
        '🍪',
        '🎂',
        '🍰',
        '🍫',
        '☕',
        '🍵',
        '🧃',
        '🍺',
        '🥂',
        '🍎',
        '🍓',
        '🍉',
        '🍇',
        '🥑',
        '⚽',
        '🏀',
        '🏈',
        '⚾',
        '🎾',
        '🏐',
        '🏓',
        '🥊',
        '🚴',
        '🏊',
        '🚀',
        '✈️',
        '🚗',
        '🏍️',
        '⛵',
        '🗺️',
        '🏝️',
        '🏔️',
        '🎡',
        '🎠',
        '🐱',
        '🐶',
        '🐼',
        '🐨',
        '🦊',
        '🦁',
        '🐯',
        '🐸',
        '🐧',
        '🦄'
      ],
    };

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 460,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_emotions_outlined,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(ctx.tr('add_sticker'),
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final entry in groups.entries)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                            child: Text(ctx.tr('sticker_${entry.key}'),
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                          ),
                          Wrap(
                            children: [
                              for (final e in entry.value)
                                InkWell(
                                  onTap: () => Navigator.pop(ctx, e),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(e,
                                        style: const TextStyle(fontSize: 30)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final List<Offset>? current;
  final Color currentColor;
  final double currentWidth;

  const _DrawPainter({
    required this.strokes,
    required this.current,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void draw(List<Offset> pts, Color c, double w) {
      if (pts.isEmpty) return;
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, w / 2, Paint()..color = c);
        return;
      }
      final paint = Paint()
        ..color = c
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) {
      draw(s.points, s.color, s.width);
    }
    if (current != null) draw(current!, currentColor, currentWidth);
  }

  @override
  bool shouldRepaint(_DrawPainter old) => true;
}
