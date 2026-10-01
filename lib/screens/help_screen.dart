import 'package:flutter/material.dart';

import '../logic/commands.dart';
import '../logic/money.dart';
import '../state/money_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';
import 'stats_screen.dart';

/// (명령어, 인자, 설명, 예시)
const _entries = <(String, String, String, String?)>[
  ('<금액> <메모>', '[#태그]', '쓴 돈 기록. 금액과 메모 순서는 자유, 태그는 메모를 보고 알아서 붙어요.', '-4500 커피'),
  ('', '', '만 · 천 · 쉼표 · 원도 알아들어요.', '1.2만 장보기 #생활'),
  ('budget', '<금액>', '한 달 예산 정하기. 디스크 용량이 돼요. 0 이면 꺼요.', 'budget 700000'),
  ('dir', '', '이번 달 디스크와 기록 보기 (ls 도 같아요).', null),
  ('stats', '[달]', '태그별 사용량과 최근 6개월. 달을 쓰면 그 달.', 'stats 9'),
  ('print', '[달]', '그 달 내역을 영수증으로 출력해요. 사진 저장 · 공유도 돼요.', 'print 2026.09'),
  ('undo', '', '마지막으로 기록한 한 건을 지워요.', null),
  ('rm', '', '목록 오른쪽 rm 을 두 번 누르면 그 기록을 지워요.', null),
  ('cls', '', '화면 로그만 지워요. 기록은 그대로예요.', null),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.store});

  final MoneyStore store;

  @override
  Widget build(BuildContext context) {
    final p = store.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(
            palette: p,
            now: store.now(),
            active: 'help',
            onStats: () => Navigator.of(context)
                .pushReplacement(termRoute(StatsScreen(store: store, month: monthOf(store.now())))),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: '$prompt ', style: termStyle(p.fg)),
                  TextSpan(text: 'help', style: termStyle(p.cmd)),
                ])),
                const SizedBox(height: 10),
                Text('명령어 목록', style: termStyle(p.hi)),
                Text('한 줄이면 기록 끝.  <필수>  [선택]', style: termStyle(p.dim, size: 13)),
                const SizedBox(height: 10),
                DashedDivider(color: p.line),
                for (final e in _entries)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.$1.isNotEmpty)
                          Text.rich(TextSpan(children: [
                            TextSpan(text: e.$1, style: termStyle(p.cmd)),
                            if (e.$2.isNotEmpty) TextSpan(text: ' ${e.$2}', style: termStyle(p.fg)),
                          ])),
                        const SizedBox(height: 2),
                        Text(e.$3, style: termStyle(p.dim, size: 13)),
                        if (e.$4 != null) Text('예) ${e.$4}', style: termStyle(p.tag, size: 13)),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Text('자동 태그', style: termStyle(p.hi)),
                const SizedBox(height: 6),
                for (final (tag, words) in autoTags)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 64, child: Text('#$tag', style: termStyle(p.tag, size: 13))),
                        Expanded(
                          child: Text(
                            words.take(6).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: termStyle(p.dim, size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text('기록은 이 폰 안에만 저장돼요. 서버로 보내지 않아요.', style: termStyle(p.dim, size: 13)),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TermWideButton(
                palette: p,
                keyLabel: '[ ESC ]',
                label: '돌아가기',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
