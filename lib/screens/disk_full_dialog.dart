import 'package:flutter/material.dart';

import '../logic/money.dart';
import '../state/money_store.dart';
import '../theme/term_palette.dart';

/// 예산을 처음 넘었을 때 뜨는 윈도우 경고창. "예산 늘리기" 를 누르면 true.
class DiskFullDialog extends StatelessWidget {
  const DiskFullDialog({super.key, required this.store});

  final MoneyStore store;

  @override
  Widget build(BuildContext context) {
    final p = store.palette;
    final disk = store.disk;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: p.bar,
          border: Border.all(color: p.dim),
          boxShadow: const [BoxShadow(color: Color(0xFF000000), offset: Offset(6, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 40,
              color: p.warn,
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'money.exe - 디스크 공간 부족',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: termStyle(const Color(0xFF0C0C0C), size: 13, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '닫기',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(false),
                      child: const SizedBox(
                        width: 44,
                        height: 40,
                        child: Center(child: Icon(Icons.close, size: 18, color: Color(0xFF0C0C0C))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 34, color: p.warn),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('C: 드라이브의 공간이 부족합니다.', style: termStyle(p.hi, size: 13, weight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('${disk.periodName} 예산을 ${won(-disk.free)}원 초과했어요.', style: termStyle(p.fg, size: 13)),
                        const SizedBox(height: 4),
                        Text(
                          disk.daysLeft > 1
                              ? '남은 ${disk.daysLeft}일은 조금만 아껴볼까요?'
                              : (disk.weekly ? '내일(월요일)이면 디스크가 다시 비워져요.' : '오늘이 이번 달 마지막 날이에요.'),
                          style: termStyle(p.dim, size: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _button(p, '예산 늘리기', filled: false, onTap: () => Navigator.of(context).pop(true)),
                  const SizedBox(width: 8),
                  _button(p, '확인', filled: true, onTap: () => Navigator.of(context).pop(false)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(TermPalette p, String label, {required bool filled, required VoidCallback onTap}) => Semantics(
        button: true,
        child: Material(
          color: filled ? p.hi : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: filled ? p.hi : p.dim)),
              child: Text(
                label,
                style: termStyle(filled ? p.bg : p.fg, size: 13, weight: filled ? FontWeight.w700 : FontWeight.w400),
              ),
            ),
          ),
        ),
      );
}
