import 'package:flutter/material.dart';

import '../logic/commands.dart';
import '../logic/money.dart';
import '../pro/pro_controller.dart';
import '../state/money_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';

/// `upgrade` 화면: PRO(아이폰 위젯) 소개 + 구매 / 복원.
class ProScreen extends StatelessWidget {
  const ProScreen({super.key, required this.store});

  final MoneyStore store;

  static const _features = [
    ('홈 화면 위젯', '작게 · 중간. 디스크 막대, 여유 금액, 하루 쓸 돈, 최근 기록'),
    ('잠금화면 위젯', '직사각형 · 원형 게이지 · 시계 위 한 줄'),
    ('위젯 누르면 바로 입력', '앱이 입력칸을 연 채로 켜져요'),
    ('앞으로 나올 PRO 기능', '추가 결제 없이'),
  ];

  @override
  Widget build(BuildContext context) {
    final pro = store.pro;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        final isPro = store.isPro;
        return Scaffold(
          backgroundColor: p.bg,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TitleBar(palette: p, now: store.now()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '$prompt ', style: termStyle(p.fg)),
                      TextSpan(text: 'upgrade', style: termStyle(p.cmd)),
                    ])),
                    const SizedBox(height: 14),
                    Text('money.exe PRO', style: termStyle(p.hi, size: 22, weight: FontWeight.w700)),
                    Text('한 번 결제, 계속 사용', style: termStyle(p.dim, size: 13)),
                    const SizedBox(height: 16),
                    _WidgetPreview(disk: store.disk),
                    const SizedBox(height: 16),
                    DashedDivider(color: p.line),
                    const SizedBox(height: 8),
                    for (final f in _features)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isPro ? '[x]' : '[+]', style: termStyle(p.ok)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.$1, style: termStyle(p.hi)),
                                  Text(f.$2, style: termStyle(p.dim, size: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    DashedDivider(color: p.line),
                    const SizedBox(height: 14),
                    if (isPro) ..._activeInfo(p) else ..._buyInfo(p, pro),
                    if (pro?.message != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '> ${pro!.message}',
                          style: termStyle(pro.messageIsError ? p.warn : p.ok, size: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isPro) ...[
                        Opacity(
                          opacity: (pro?.busy ?? false) ? 0.5 : 1,
                          child: TermWideButton(
                            palette: p,
                            keyLabel: '[ ENTER ]',
                            label: pro?.price == null ? '구매하기' : '${pro!.price} 구매하기',
                            onTap: () => pro?.buy(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TermBoxButton(
                                palette: p,
                                label: '구매 복원',
                                textColor: p.cmd,
                                onTap: () => pro?.restore(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TermBoxButton(
                                palette: p,
                                label: '[ ESC ] 닫기',
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        TermWideButton(
                          palette: p,
                          keyLabel: '[ ESC ]',
                          label: '돌아가기',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _activeInfo(TermPalette p) => [
        Text('✓ PRO 활성화됨', style: termStyle(p.ok, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('홈 화면 위젯: 홈 화면 길게 누르기 → 편집 → 위젯 추가 → money.exe', style: termStyle(p.dim, size: 13)),
        const SizedBox(height: 4),
        Text('잠금화면 위젯: 잠금화면 길게 누르기 → 사용자화 → 잠금 화면 → 위젯', style: termStyle(p.dim, size: 13)),
      ];

  List<Widget> _buyInfo(TermPalette p, ProController? pro) {
    final String status;
    if (pro == null || !pro.available) {
      status = '스토어에 연결되지 않았어요.';
    } else if (pro.price == null) {
      status = '가격을 불러오는 중...';
    } else {
      status = '가격 ${pro.price} · 한 번만 결제';
    }
    return [
      Text(status, style: termStyle(p.fg, size: 13)),
      Text('같은 Apple ID 로는 다른 기기에서도 복원할 수 있어요.', style: termStyle(p.dim, size: 13)),
    ];
  }
}

/// 지금 내 숫자로 그린 위젯 미리보기 (작게 + 잠금화면 직사각형).
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.disk});

  final Disk disk;

  static const _bg = Color(0xFF0C0C0C);
  static const _hi = Color(0xFFF2F2F2);
  static const _fg = Color(0xFFCCCCCC);
  static const _dim = Color(0xFF8A8A8A);

  Color get _level => switch (disk.level) {
        DiskLevel.full => const Color(0xFFE74856),
        DiskLevel.warn => const Color(0xFFF9F1A5),
        _ => const Color(0xFF16C60C),
      };

  @override
  Widget build(BuildContext context) {
    final none = disk.level == DiskLevel.none;
    final pct = none ? '--' : disk.pctLabel;
    final free = none ? '예산 없음' : (disk.free >= 0 ? '여유 ${won(disk.free)}원' : '${won(-disk.free)}원 초과');
    final perDay = none ? 'budget 로 정하기' : '하루 ${won(disk.perDay)}원';
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 150,
            height: 150,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Text('>_ ', style: termStyle(const Color(0xFF16C60C), size: 10, weight: FontWeight.w700)),
                  Text('money.exe', style: termStyle(_hi, size: 10, weight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Text('C: · ${disk.weekly ? '이번 주' : '${disk.month.month}월'} 예산',
                    maxLines: 1, style: termStyle(_dim, size: 9)),
                const SizedBox(height: 4),
                Container(
                  height: 11,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(border: Border.all(color: _dim)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(widthFactor: disk.fill, heightFactor: 1, child: ColoredBox(color: _level)),
                  ),
                ),
                Text(pct, style: termStyle(_hi, size: 20, weight: FontWeight.w700, height: 1.4)),
                const Spacer(),
                Text(free, maxLines: 1, style: termStyle(_fg, size: 10)),
                Text(perDay, maxLines: 1, style: termStyle(_level, size: 10)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF2B2E37), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('잠금화면', style: termStyle(_dim, size: 10)),
                  const SizedBox(height: 4),
                  Text('C:\\money> $pct', maxLines: 1, style: termStyle(Colors.white, size: 12, weight: FontWeight.w700)),
                  Text('> $free', maxLines: 1, overflow: TextOverflow.ellipsis, style: termStyle(Colors.white, size: 11)),
                  Text('> $perDay', maxLines: 1, overflow: TextOverflow.ellipsis, style: termStyle(Colors.white, size: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
