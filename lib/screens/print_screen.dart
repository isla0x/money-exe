import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/commands.dart';
import '../logic/money.dart';
import '../state/money_store.dart';
import '../theme/term_palette.dart';
import '../widgets/receipt_paper.dart';
import '../widgets/term_widgets.dart';

/// print: 그 달 내역이 영수증 프린터에서 한 줄씩 출력된다. 다 나오면 사진 저장 · 공유.
class PrintScreen extends StatefulWidget {
  const PrintScreen({super.key, required this.store, required this.month});

  final MoneyStore store;
  final DateTime month;

  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  final _paperKey = GlobalKey();
  final _scroll = ScrollController();
  late final List<ReceiptLine> _lines;
  Timer? _timer;
  int _shown = 0;
  bool _busy = false;
  String? _msg;
  bool _msgIsError = false;

  bool get _done => _shown >= _lines.length;
  DateTime get _month => monthOf(widget.month);
  String get _fileName => 'money-exe-${_month.year}-${two(_month.month)}';

  @override
  void initState() {
    super.initState();
    _lines = receiptLines(widget.store.data, _month, widget.store.now());
    // 줄이 많아도 3초 안쪽으로 끝나게.
    final ms = (2600 / _lines.length).clamp(25, 90).round();
    _timer = Timer.periodic(Duration(milliseconds: ms), (t) {
      if (!mounted || _done) {
        t.cancel();
        if (mounted && _done) HapticFeedback.lightImpact();
        return;
      }
      setState(() => _shown++);
      _follow();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// 출력 중에는 종이 끝(방금 나온 줄)을 따라간다.
  void _follow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// 출력 중에 탭하면 바로 끝까지.
  void _skip() {
    if (_done) return;
    _timer?.cancel();
    setState(() => _shown = _lines.length);
    _follow();
  }

  Future<Uint8List> _render() async {
    final boundary = _paperKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _save() async {
    if (!_done || _busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) {
          _say('access denied: photos\n설정 > money.exe 에서 사진 추가를 허용해 주세요.', error: true);
          return;
        }
      }
      await Gal.putImageBytes(await _render(), name: _fileName);
      _say('✓ saved to C:\\PICS\\$_fileName.png');
      HapticFeedback.mediumImpact();
    } on GalException catch (e) {
      _say('save failed: ${e.type.message}', error: true);
    } catch (e) {
      _say('save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (!_done || _busy) return;
    setState(() => _busy = true);
    try {
      final png = await _render();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_fileName.png');
      await file.writeAsBytes(png, flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      _say('share failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String msg, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _msg = msg;
      _msgIsError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = store.palette;
    final now = store.now();
    final arg = sameMonth(_month, now) ? '' : ' ${yearMonth(_month)}';
    final pct = (_shown * 100 / _lines.length).round();

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(palette: p, now: now),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _skip,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: '$prompt ', style: termStyle(p.fg, size: 13)),
                        TextSpan(text: 'print$arg', style: termStyle(p.cmd, size: 13)),
                        TextSpan(
                          text: _done ? '  출력 완료' : '  출력 중... $pct%',
                          style: termStyle(_done ? p.ok : p.dim, size: 13),
                        ),
                      ])),
                    ),
                    const SizedBox(height: 12),
                    // 프린터 출력구
                    Center(
                      child: Container(
                        width: 332,
                        height: 14,
                        decoration: BoxDecoration(
                          color: p.isLight ? const Color(0xFF3A3A3A) : const Color(0xFF2A2A2A),
                          border: Border.all(color: const Color(0xFF444444)),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(0, -7),
                        child: SingleChildScrollView(
                          controller: _scroll,
                          child: Center(
                            child: Semantics(
                              label: '영수증 ${_month.month}월',
                              child: RepaintBoundary(
                                key: _paperKey,
                                child: ReceiptPaper(lines: _lines, shown: _shown),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 36,
                    child: Text(
                      _msg ?? (_done ? '' : '화면을 탭하면 바로 끝까지 출력해요.'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: termStyle(_msg == null ? p.dim : (_msgIsError ? p.warn : p.ok), size: 12, height: 1.4),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Opacity(
                          opacity: _done && !_busy ? 1 : 0.4,
                          child: TermBoxButton(palette: p, label: 'SAVE .PNG', textColor: p.ok, onTap: _save),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Opacity(
                          opacity: _done && !_busy ? 1 : 0.4,
                          child: TermBoxButton(palette: p, label: 'SHARE', onTap: _share),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TermBoxButton(
                          palette: p,
                          label: 'CLOSE',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
