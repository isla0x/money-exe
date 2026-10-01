import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/commands.dart';
import '../logic/money.dart';
import '../models/entry.dart';
import '../state/money_store.dart';
import '../theme/term_palette.dart';
import '../widgets/disk_panel.dart';
import '../widgets/term_widgets.dart';
import 'disk_full_dialog.dart';
import 'help_screen.dart';
import 'print_screen.dart';
import 'stats_screen.dart';

/// 메인 화면: 디스크(예산) + 이번 달 기록 + 명령어 입력창.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final MoneyStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  int? _histIdx;

  MoneyStore get store => widget.store;

  /// (칩 이름, 누르면 채워 넣을 글자 — null 이면 바로 실행)
  static const _chips = <(String, String?)>[
    ('- 지출', '-'),
    ('dir', null),
    ('print', null),
    ('stats', null),
    ('budget', 'budget '),
    ('undo', null),
    ('help', null),
    ('cls', null),
  ];

  @override
  void initState() {
    super.initState();
    _scrollToEnd(animate: false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _run(String raw, {bool fromInput = false}) {
    if (raw.trim().isEmpty) return;
    final out = store.run(raw);
    if (fromInput) _ctrl.clear();
    _histIdx = null;
    if (out == null) return;
    if (out.added) _scrollToEnd();
    if (out.alert) _showDiskFull();
    if (out.route != null) _open(out.route!, month: out.month);
  }

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      animate
          ? _scroll.animateTo(end, duration: const Duration(milliseconds: 200), curve: Curves.easeOut)
          : _scroll.jumpTo(end);
    });
  }

  void _open(String route, {DateTime? month}) {
    final m = month ?? monthOf(store.now());
    final Widget page = switch (route) {
      'stats' => StatsScreen(store: store, month: m),
      'print' => PrintScreen(store: store, month: m),
      _ => HelpScreen(store: store),
    };
    _focus.unfocus();
    Navigator.of(context).push(termRoute(page));
  }

  Future<void> _showDiskFull() async {
    _focus.unfocus();
    final raise = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xA8000000),
      builder: (context) => DiskFullDialog(store: store),
    );
    if (raise == true && mounted) {
      // 지금 쓴 돈보다 큰 다음 10만 원 단위를 제안한다.
      final spent = store.disk.spent;
      final next = (spent ~/ 100000 + 1) * 100000;
      _prefill('budget $next');
    }
  }

  void _prefill(String text) {
    _ctrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    _focus.requestFocus();
  }

  /// 하드웨어 키보드 ↑ ↓ 로 이전 명령어 불러오기.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final up = e.logicalKey == LogicalKeyboardKey.arrowUp;
    final down = e.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!up && !down) return KeyEventResult.ignored;
    final h = store.history;
    if (h.isEmpty) return KeyEventResult.ignored;
    final cur = _histIdx ?? h.length;
    final i = up ? math.max(0, cur - 1) : math.min(h.length, cur + 1);
    _histIdx = i;
    final text = i == h.length ? '' : h[i];
    _ctrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    return KeyEventResult.handled;
  }

  Color _logColor(TermPalette p, LogKind k) => switch (k) {
        LogKind.cmd => p.fg,
        LogKind.ok => p.ok,
        LogKind.err => p.warn,
        LogKind.info => p.dim,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        final disk = store.disk;
        final list = entriesIn(store.data, disk.month);
        final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

        return Scaffold(
          backgroundColor: p.bg,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TitleBar(
                palette: p,
                now: store.now(),
                onStats: () => _open('stats'),
                onHelp: () => _open('help'),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 키보드가 올라오면 머리말을 접고 디스크도 한 줄로 줄인다 (작은 폰에서 넘치지 않게).
                      if (!typing) ...[
                        Text('MONEY [Version 1.0.0]', style: termStyle(p.hi)),
                        Text('오늘도 아껴서, 천천히.', style: termStyle(p.dim, size: 13)),
                        const SizedBox(height: 12),
                        Text.rich(TextSpan(children: [
                          TextSpan(text: '$prompt ', style: termStyle(p.fg)),
                          TextSpan(text: 'dir', style: termStyle(p.cmd)),
                        ])),
                        const SizedBox(height: 10),
                      ],
                      DiskPanel(
                        disk: disk,
                        palette: p,
                        compact: typing,
                        onTap: () => _prefill(disk.budget > 0 ? 'budget ${disk.budget}' : 'budget '),
                      ),
                      SizedBox(height: typing ? 8 : 16),
                      Row(
                        children: [
                          Expanded(child: Text('${disk.month.month}월 기록', style: termStyle(p.dim, size: 12))),
                          Text('${list.length}개 항목', style: termStyle(p.dim, size: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(height: 1, color: p.line),
                      Expanded(
                        child: list.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text.rich(TextSpan(children: [
                                  TextSpan(text: '이번 달 기록이 없어요.\n', style: termStyle(p.dim, size: 13)),
                                  TextSpan(text: '-4500 커피', style: termStyle(p.cmd, size: 13)),
                                  TextSpan(text: ' 처럼 한 줄이면 끝.', style: termStyle(p.dim, size: 13)),
                                ])),
                              )
                            : ListView.builder(
                                controller: _scroll,
                                padding: EdgeInsets.zero,
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: list.length,
                                itemBuilder: (context, i) => _EntryRow(
                                  key: ValueKey(list[i].id),
                                  entry: list[i],
                                  palette: p,
                                  onRemove: () => store.remove(list[i].id),
                                ),
                              ),
                      ),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          alignment: Alignment.bottomLeft,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final l in store.log) Text(l.text, style: termStyle(_logColor(p, l.kind), size: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextFieldTapRegion(child: _footer(p)),
            ],
          ),
        );
      },
    );
  }

  Widget _footer(TermPalette p) {
    return Container(
      decoration: BoxDecoration(color: p.bar, border: Border(top: BorderSide(color: p.line))),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (label, fill) in _chips)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TermBoxButton(
                        palette: p,
                        label: label,
                        textColor: p.cmd,
                        semanticLabel: label == '- 지출' ? '지출 입력' : null,
                        onTap: () => fill != null ? _prefill(fill) : _run(label),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 50,
              padding: const EdgeInsets.only(left: 12, right: 2),
              decoration: BoxDecoration(color: p.bg, border: Border.all(color: p.line)),
              child: Row(
                children: [
                  Text(prompt, style: termStyle(p.hi)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Focus(
                      onKeyEvent: _onKey,
                      child: Semantics(
                        label: '명령어 입력',
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          style: termStyle(p.hi, size: 16, height: 1.2),
                          cursorColor: p.ok,
                          keyboardAppearance: p.isLight ? Brightness.light : Brightness.dark,
                          cursorWidth: 9,
                          cursorHeight: 18,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration.collapsed(
                            hintText: '-4500 커피',
                            hintStyle: termStyle(p.dim, size: 16, height: 1.2),
                          ),
                          onChanged: (_) => _histIdx = null,
                          onTapOutside: (_) => _focus.unfocus(),
                          onSubmitted: (v) => _run(v, fromInput: true),
                          // 비워두면 Enter 후에도 키보드가 닫히지 않는다.
                          onEditingComplete: () {},
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '실행',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () {
                        _run(_ctrl.text, fromInput: true);
                        _focus.requestFocus();
                      },
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(child: CustomPaint(size: const Size(18, 18), painter: ReturnIconPainter(p.ok))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatefulWidget {
  const _EntryRow({super.key, required this.entry, required this.palette, required this.onRemove});

  final Entry entry;
  final TermPalette palette;
  final VoidCallback onRemove;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

/// rm 은 두 번 눌러야 지워진다: 한 번 누르면 `rm?` 으로 바뀌고 3초 안에 한 번 더.
class _EntryRowState extends State<_EntryRow> {
  Timer? _timer;
  bool _armed = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tapRm() {
    if (_armed) {
      _timer?.cancel();
      widget.onRemove();
      return;
    }
    setState(() => _armed = true);
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _armed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final e = widget.entry;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: '${e.at.month}월 ${e.at.day}일 ${e.memo} ${won(e.amount)}원, ${e.tag}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Text(monthDay(e.at), style: termStyle(p.dim, size: 13)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.memo, maxLines: 1, overflow: TextOverflow.ellipsis, style: termStyle(p.hi, size: 13)),
                  ),
                  const SizedBox(width: 8),
                  Text('-${won(e.amount)}', style: termStyle(p.hi, size: 13)),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, maxWidth: 64),
                    child: Text(
                      '#${e.tag}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: termStyle(p.tag, size: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Semantics(
            button: true,
            label: _armed ? '한 번 더 누르면 삭제: ${e.memo}' : '삭제: ${e.memo} ${won(e.amount)}원',
            excludeSemantics: true,
            child: InkWell(
              onTap: _tapRm,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(_armed ? 'rm?' : 'rm', style: termStyle(_armed ? p.warn : p.dim, size: 12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
