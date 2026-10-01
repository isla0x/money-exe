import 'package:flutter/material.dart';

import '../logic/commands.dart';
import '../logic/money.dart';
import '../state/money_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';
import 'help_screen.dart';
import 'print_screen.dart';

/// 태그별 사용량(폴더 크기처럼) + 최근 6개월.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.store, required this.month});

  final MoneyStore store;
  final DateTime month;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late DateTime _month = monthOf(widget.month);

  MoneyStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final p = store.palette;
    final now = store.now();
    final d = store.data;
    final list = entriesIn(d, _month);
    final spent = sumOf(list);
    final tags = byTag(list);
    final maxTag = tags.isEmpty ? 1 : tags.first.amount;
    final months = recentMonths(d, _month);
    var maxMonth = d.budget;
    for (final m in months) {
      if (m.amount > maxMonth) maxMonth = m.amount;
    }
    if (maxMonth <= 0) maxMonth = 1;
    final isNow = sameMonth(_month, now);
    final canNext = monthOf(now).isAfter(_month);
    final arg = isNow ? '' : ' ${yearMonth(_month)}';

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(
            palette: p,
            now: now,
            active: 'stats',
            onHelp: () => Navigator.of(context).pushReplacement(termRoute(HelpScreen(store: store))),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: '$prompt ', style: termStyle(p.fg)),
                  TextSpan(text: 'stats$arg', style: termStyle(p.cmd)),
                ])),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TermBoxButton(
                      palette: p,
                      label: '<',
                      semanticLabel: '이전 달',
                      onTap: () => setState(() => _month = addMonths(_month, -1)),
                    ),
                    Expanded(
                      child: Text(
                        '${_month.year}년 ${_month.month}월',
                        textAlign: TextAlign.center,
                        style: termStyle(p.hi, weight: FontWeight.w700),
                      ),
                    ),
                    Opacity(
                      opacity: canNext ? 1 : 0.3,
                      child: TermBoxButton(
                        palette: p,
                        label: '>',
                        semanticLabel: '다음 달',
                        onTap: () {
                          if (canNext) setState(() => _month = addMonths(_month, 1));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('C:\\money\\${_month.year}\\${two(_month.month)} 의 폴더 크기', style: termStyle(p.dim, size: 12)),
                const SizedBox(height: 4),
                if (tags.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('파일을 찾을 수 없습니다. (이 달 기록 없음)', style: termStyle(p.dim, size: 13)),
                  ),
                for (final t in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                    child: Semantics(
                      label: '${t.tag} ${won(t.amount)}원, ${t.count}건, ${(t.amount * 100 / spent).round()}퍼센트',
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text('<DIR>', style: termStyle(p.dim, size: 13)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${t.tag}  (${t.count})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: termStyle(p.tag, size: 13),
                                ),
                              ),
                              Text(won(t.amount), style: termStyle(p.hi, size: 13)),
                              SizedBox(
                                width: 46,
                                child: Text(
                                  '${(t.amount * 100 / spent).round()}%',
                                  textAlign: TextAlign.right,
                                  style: termStyle(p.dim, size: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _Bar(fill: t.amount / maxTag, color: p.cmd, track: p.line),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  '${tags.length}개 폴더 · ${list.length}개 파일 · ${won(spent)}원',
                  style: termStyle(p.fg, size: 13),
                ),
                if (d.budget > 0)
                  Text(
                    spent <= d.budget
                        ? '예산 ${won(d.budget)}원 중 ${won(d.budget - spent)}원 남음'
                        : '예산 ${won(d.budget)}원을 ${won(spent - d.budget)}원 넘음',
                    style: termStyle(spent <= d.budget ? p.dim : p.warn, size: 13),
                  ),
                const SizedBox(height: 22),
                Text('최근 6개월', style: termStyle(p.hi)),
                if (d.budget > 0) Text('| 표시 = 예산 ${won(d.budget)}원', style: termStyle(p.dim, size: 12)),
                const SizedBox(height: 8),
                for (final m in months)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      label: '${m.month.year}년 ${m.month.month}월 ${won(m.amount)}원',
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: Text(
                              yearMonth(m.month).substring(2),
                              style: termStyle(sameMonth(m.month, _month) ? p.hi : p.dim, size: 13),
                            ),
                          ),
                          Expanded(
                            child: _Bar(
                              fill: m.amount / maxMonth,
                              color: d.budget > 0 && m.amount > d.budget ? p.warn : p.ok,
                              track: p.line,
                              mark: d.budget > 0 ? d.budget / maxMonth : null,
                              markColor: p.hi,
                              height: 10,
                            ),
                          ),
                          SizedBox(
                            width: 96,
                            child: Text(won(m.amount), textAlign: TextAlign.right, style: termStyle(p.fg, size: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TermWideButton(
                      palette: p,
                      keyLabel: '[ ESC ]',
                      label: '돌아가기',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TermWideButton(
                      palette: p,
                      keyLabel: '[ P ]',
                      label: '영수증',
                      onTap: () => Navigator.of(context)
                          .pushReplacement(termRoute(PrintScreen(store: store, month: _month))),
                    ),
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

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fill,
    required this.color,
    required this.track,
    this.mark,
    this.markColor,
    this.height = 6,
  });

  final double fill;
  final Color color;
  final Color track;

  /// 예산 위치 (0 ~ 1)
  final double? mark;
  final Color? markColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: ColoredBox(color: track)),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: w * fill.clamp(0.0, 1.0),
                child: ColoredBox(color: color),
              ),
              if (mark != null)
                Positioned(
                  left: (w * mark!.clamp(0.0, 1.0)) - 1,
                  top: -3,
                  bottom: -3,
                  width: 2,
                  child: ColoredBox(color: markColor ?? color),
                ),
            ],
          );
        },
      ),
    );
  }
}
