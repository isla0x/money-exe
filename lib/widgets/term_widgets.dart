import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/money.dart';
import '../theme/term_palette.dart';

/// 화면 전환: 터미널답게 짧은 페이드.
Route<T> termRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );

/// 상단 창 제목줄: `>_ money.exe  09.24 목      stats  help`
class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.palette,
    required this.now,
    this.active,
    this.onStats,
    this.onHelp,
  });

  final TermPalette palette;
  final DateTime now;

  /// 'stats' | 'help' | null
  final String? active;
  final VoidCallback? onStats;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      decoration: BoxDecoration(
        color: p.bar,
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 4),
            child: Row(
              children: [
                CustomPaint(size: const Size(16, 16), painter: PromptIconPainter(p.hi)),
                const SizedBox(width: 8),
                Text('money.exe', style: termStyle(p.hi, size: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shortDate(now),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: termStyle(p.dim, size: 12),
                  ),
                ),
                if (onStats != null || active == 'stats')
                  _TabLink(label: 'stats', active: active == 'stats', palette: p, onTap: onStats),
                if (onHelp != null || active == 'help')
                  _TabLink(label: 'help', active: active == 'help', palette: p, onTap: onHelp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabLink extends StatelessWidget {
  const _TabLink({required this.label, required this.active, required this.palette, this.onTap});

  final String label;
  final bool active;
  final TermPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? p.fg : Colors.transparent,
        child: InkWell(
          onTap: active ? null : onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: Text(label, style: termStyle(active ? p.bg : p.dim, size: 13)),
          ),
        ),
      ),
    );
  }
}

/// 테두리 있는 네모 버튼. 선택되면 색이 반전된다.
class TermBoxButton extends StatelessWidget {
  const TermBoxButton({
    super.key,
    required this.palette,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.textColor,
    this.semanticLabel,
  });

  final TermPalette palette;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? textColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: selected ? p.fg : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: selected ? p.fg : p.line)),
            child: Text(label, style: termStyle(selected ? p.bg : (textColor ?? p.fg), size: 13)),
          ),
        ),
      ),
    );
  }
}

/// 화면 아래 큰 버튼: `[ ESC ] 목록으로`
class TermWideButton extends StatelessWidget {
  const TermWideButton({
    super.key,
    required this.palette,
    required this.keyLabel,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final TermPalette palette;
  final String keyLabel;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 52,
            decoration: BoxDecoration(border: Border.all(color: p.fg)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(keyLabel, style: termStyle(p.dim, size: 15)),
                const SizedBox(width: 12),
                Text(label, style: termStyle(p.hi, size: 15)),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 깜빡이는 `_` 커서.
class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({super.key, required this.style});

  final TextStyle style;

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor> {
  Timer? _timer;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) setState(() => _on = !_on);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: Opacity(opacity: _on ? 1 : 0, child: Text('_', style: widget.style)));
}

/// 점선 구분선.
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 1, width: double.infinity, child: CustomPaint(painter: _DashPainter(color)));
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 4, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// `>_` 아이콘.
class PromptIconPainter extends CustomPainter {
  PromptIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 16;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final chevron = Path()
      ..moveTo(2.5 * s, 4.5 * s)
      ..lineTo(6 * s, 8 * s)
      ..lineTo(2.5 * s, 11.5 * s);
    canvas.drawPath(chevron, paint);
    canvas.drawLine(Offset(8 * s, 12 * s), Offset(13.5 * s, 12 * s), paint);
  }

  @override
  bool shouldRepaint(PromptIconPainter old) => old.color != color;
}

/// 실행(⏎) 아이콘.
class ReturnIconPainter extends CustomPainter {
  ReturnIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final stem = Path()
      ..moveTo(15 * s, 3 * s)
      ..lineTo(15 * s, 9 * s)
      ..quadraticBezierTo(15 * s, 11 * s, 13 * s, 11 * s)
      ..lineTo(3.5 * s, 11 * s);
    final head = Path()
      ..moveTo(7 * s, 7.5 * s)
      ..lineTo(3.5 * s, 11 * s)
      ..lineTo(7 * s, 14.5 * s);
    canvas
      ..drawPath(stem, paint)
      ..drawPath(head, paint);
  }

  @override
  bool shouldRepaint(ReturnIconPainter old) => old.color != color;
}
