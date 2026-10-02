import 'package:flutter_test/flutter_test.dart';
import 'package:money_exe/logic/commands.dart';
import 'package:money_exe/logic/money.dart';
import 'package:money_exe/widget_sync.dart';

void main() {
  final now = DateTime(2026, 9, 24, 12);
  MoneyData run(MoneyData d, String s, [DateTime? at]) => runCommand(d, s, at ?? now).data;

  test('위젯 JSON: 이번 달 숫자 · 최근 3개 · 주기 끝', () {
    var d = run(MoneyData.initial(), 'budget 700000');
    d = run(d, '-50000 장보기', DateTime(2026, 8, 30)); // 지난달은 빠진다
    for (final s in ['-1000 a', '-2000 b', '-3000 c', '-4000 d']) {
      d = run(d, s);
    }
    final j = widgetSnapshot(d, now, pro: true);
    expect(j['pro'], isTrue);
    expect(j['period'], 'month');
    expect(j['budget'], 700000);
    expect(j['spent'], 10000);
    expect(j['count'], 4);
    expect(j['from'], DateTime(2026, 9).millisecondsSinceEpoch);
    expect(j['until'], DateTime(2026, 10).millisecondsSinceEpoch);
    expect((j['recent'] as List).map((r) => r['m']), ['b', 'c', 'd']);
    expect((j['recent'] as List).last, {'d': '09.24', 'm': 'd', 'a': 4000});
  });

  test('위젯 JSON: 주간 예산이면 이번 주만', () {
    var d = run(MoneyData.initial(), 'budget 100000 /week');
    d = run(d, '-30000 지난주', DateTime(2026, 9, 20, 22));
    d = run(d, '-1000 커피');
    final j = widgetSnapshot(d, now);
    expect(j['pro'], isFalse);
    expect(j['period'], 'week');
    expect(j['spent'], 1000);
    expect(j['from'], DateTime(2026, 9, 21).millisecondsSinceEpoch);
    expect(j['until'], DateTime(2026, 9, 28).millisecondsSinceEpoch);
  });

  test('위젯 JSON: 추가 예산은 이번 주기 budget 에만, base 는 기본 예산', () {
    var d = run(MoneyData.initial(), 'budget 5만 /week');
    d = run(d, 'budget +5만');
    final j = widgetSnapshot(d, now);
    expect(j['budget'], 100000);
    expect(j['base'], 50000);
  });

  test('upgrade · restore 는 PRO 화면으로', () {
    final d = MoneyData.initial();
    expect(runCommand(d, 'upgrade', now).route, 'pro');
    expect(runCommand(d, 'pro', now).route, 'pro');
    expect(runCommand(d, 'restore', now).route, 'restore');
  });
}
