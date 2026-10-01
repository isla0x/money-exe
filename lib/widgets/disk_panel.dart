import 'package:flutter/material.dart';

import '../logic/money.dart';
import '../theme/term_palette.dart';

/// 이번 달 예산을 "로컬 디스크 (C:)" 처럼 보여준다.
///   여유 → 초록, 80% 이상 → 노랑, 넘으면 → 빨강
class DiskPanel extends StatelessWidget {
  const DiskPanel({super.key, required this.disk, required this.palette, this.onTap, this.compact = false});

  final Disk disk;
  final TermPalette palette;

  /// 탭하면 (예산 명령어를 채워 넣는 등)
  final VoidCallback? onTap;

  /// 키보드가 올라왔을 때: 막대와 한 줄 안내만
  final bool compact;

  Color barColor(TermPalette p) => switch (disk.level) {
        DiskLevel.full => p.warn,
        DiskLevel.warn => p.tag,
        _ => p.ok,
      };

  Color msgColor(TermPalette p) => switch (disk.level) {
        DiskLevel.full => p.warn,
        DiskLevel.warn => p.tag,
        DiskLevel.none => p.dim,
        DiskLevel.ok => p.fg,
      };

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final d = disk;
    final none = d.level == DiskLevel.none;
    return Semantics(
      label: none
          ? '이번 달 ${won(d.spent)}원 사용. ${d.message}'
          : '${d.title} ${won(d.budget)}원 중 ${won(d.spent)}원 사용, ${d.pctLabel}. ${d.message} ${d.weekMessage ?? ''}',
      excludeSemantics: true,
      button: onTap != null,
      child: Material(
        color: p.panel,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(compact ? 10 : 14),
            decoration: BoxDecoration(border: Border.all(color: p.line)),
            child: compact ? _compact(p) : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '로컬 디스크 (C:) · ${d.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: termStyle(p.dim, size: 12),
                      ),
                    ),
                    Text(none ? '--' : '${d.pctLabel} 사용', style: termStyle(p.dim, size: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                _bar(p),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('사용 ', style: termStyle(p.fg, size: 13)),
                    Text('${won(d.spent)}원', style: termStyle(p.hi, size: 13, weight: FontWeight.w700)),
                    const Spacer(),
                    if (!none) Text('/ ${won(d.budget)}원', style: termStyle(p.dim, size: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(d.message, style: termStyle(msgColor(p), size: 12)),
                if (d.weekMessage != null)
                  Text(d.weekMessage!, style: termStyle((d.weekLeft ?? 0) < 0 ? p.warn : p.dim, size: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(TermPalette p, {double height = 20}) => Container(
        height: height,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: p.bg, border: Border.all(color: p.dim)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: disk.fill,
            heightFactor: 1,
            child: ColoredBox(color: barColor(p)),
          ),
        ),
      );

  Widget _compact(TermPalette p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _bar(p, height: 14)),
              const SizedBox(width: 10),
              Text(disk.level == DiskLevel.none ? '${won(disk.spent)}원' : disk.pctLabel,
                  style: termStyle(p.hi, size: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(disk.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: termStyle(msgColor(p), size: 12)),
        ],
      );
}
