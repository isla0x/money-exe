import 'package:flutter/material.dart';

import '../logic/money.dart';
import '../theme/term_palette.dart';

/// 영수증 종이. [shown] 줄까지만 출력된 상태로 그린다.
class ReceiptPaper extends StatelessWidget {
  const ReceiptPaper({super.key, required this.lines, required this.shown, this.width = 300});

  final List<ReceiptLine> lines;
  final int shown;
  final double width;

  @override
  Widget build(BuildContext context) {
    final n = shown.clamp(0, lines.length).toInt();
    return Container(
      width: width,
      color: paperColor,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (var i = 0; i < n; i++) _line(lines[i])],
      ),
    );
  }

  Widget _line(ReceiptLine l) {
    final base = termStyle(paperInk, size: 12, height: 1.6);
    final bold = termStyle(paperInk, size: 12, height: 1.6, weight: FontWeight.w700);
    switch (l.kind) {
      case ReceiptKind.rule:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: _Dashes(),
        );
      case ReceiptKind.title:
        return Text(l.left, textAlign: TextAlign.center, style: termStyle(paperInk, size: 16, weight: FontWeight.w700));
      case ReceiptKind.center:
        return Text(l.left, textAlign: TextAlign.center, style: base);
      case ReceiptKind.barcode:
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l.left, textAlign: TextAlign.center, softWrap: false, style: termStyle(paperInk, size: 17, height: 1.3)),
        );
      case ReceiptKind.pair:
      case ReceiptKind.total:
        final s = l.kind == ReceiptKind.total ? bold : base;
        return Row(
          children: [
            Expanded(child: Text(l.left, maxLines: 1, overflow: TextOverflow.ellipsis, style: s)),
            const SizedBox(width: 10),
            Text(l.right, style: s),
          ],
        );
    }
  }
}

class _Dashes extends StatelessWidget {
  const _Dashes();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, width: double.infinity, child: CustomPaint(painter: _DashPainter()));
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = paperRule
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 3, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}
