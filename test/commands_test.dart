import 'package:flutter_test/flutter_test.dart';
import 'package:money_exe/logic/commands.dart';
import 'package:money_exe/logic/money.dart';

void main() {
  final now = DateTime(2026, 9, 24, 21, 7);
  MoneyData run(MoneyData d, String s) => runCommand(d, s, now).data;

  test('won', () {
    expect(won(0), '0');
    expect(won(4500), '4,500');
    expect(won(1234567), '1,234,567');
    expect(won(-12400), '-12,400');
  });

  test('parseAmount', () {
    expect(parseAmount('-4500'), 4500);
    expect(parseAmount('4,500원'), 4500);
    expect(parseAmount('1.2만'), 12000);
    expect(parseAmount('3천원'), 3000);
    expect(parseAmount('1만원'), 10000);
    expect(parseAmount('2인분'), isNull);
    expect(parseAmount('커피'), isNull);
  });

  test('지출 기록: 순서 자유, 태그 자동', () {
    var d = MoneyData.initial();
    d = run(d, '-4500 커피');
    d = run(d, '점심 김밥 9000');
    d = run(d, '1.2만 다이소 #생활');
    d = run(d, '-30000');
    expect(d.entries.map((e) => e.amount), [4500, 9000, 12000, 30000]);
    expect(d.entries.map((e) => e.tag), ['카페', '식비', '생활', '기타']);
    expect(d.entries.map((e) => e.memo), ['커피', '점심 김밥', '다이소', '기타']);
    expect(d.entries.map((e) => e.id), [1, 2, 3, 4]);
  });

  test('- 붙은 금액이 먼저: 2 인분 피자 -18000', () {
    final d = run(MoneyData.initial(), '피자 2 -18000');
    expect(d.entries.single.amount, 18000);
    expect(d.entries.single.memo, '피자 2');
  });

  test('모르는 명령어는 cmd 처럼 에러', () {
    final r = runCommand(MoneyData.initial(), 'hello', now);
    expect(r.data.entries, isEmpty);
    expect(r.lines[1].kind, LogKind.err);
    expect(r.lines[1].text, contains('배치 파일이 아닙니다'));
  });

  test('+ 수입은 안 받는다', () {
    final r = runCommand(MoneyData.initial(), '+30000 월급', now);
    expect(r.data.entries, isEmpty);
    expect(r.lines.last.kind, LogKind.err);
  });

  test('budget 과 디스크', () {
    var d = run(MoneyData.initial(), 'budget 70만');
    expect(d.budget, 700000);
    d = run(d, '-560000 월세');
    final disk = Disk.of(d, now);
    expect(disk.pct, 80);
    expect(disk.level, DiskLevel.warn);
    expect(disk.daysLeft, 7);
    expect(disk.perDay, 20000);
    expect(disk.message, contains('하루 20,000원'));
  });

  test('예산을 처음 넘을 때만 경고창', () {
    var d = run(MoneyData.initial(), 'budget 10000');
    final first = runCommand(d, '-12000 가방', now);
    expect(first.alert, isTrue);
    expect(first.lines.last.text, contains('2,000원 초과'));
    final second = runCommand(first.data, '-1000 커피', now);
    expect(second.alert, isFalse);
  });

  test('예산 없으면 경고 없음', () {
    final r = runCommand(MoneyData.initial(), '-990000 노트북', now);
    expect(r.alert, isFalse);
    expect(Disk.of(r.data, now).level, DiskLevel.none);
  });

  test('지난 달 기록은 이번 달 디스크에 안 들어간다', () {
    var d = runCommand(MoneyData.initial(), '-50000 장보기', DateTime(2026, 8, 30)).data;
    d = run(d, '-1000 커피');
    expect(Disk.of(d, now).spent, 1000);
    expect(entriesIn(d, DateTime(2026, 8)).single.amount, 50000);
  });

  test('undo 는 마지막 기록, rm 은 그 기록', () {
    var d = MoneyData.initial();
    d = run(d, '-1000 a');
    d = run(d, '-2000 b');
    d = run(d, '-3000 c');
    d = run(d, 'undo');
    expect(d.entries.map((e) => e.memo), ['a', 'b']);
    d = removeEntry(d, 1).data;
    expect(d.entries.map((e) => e.memo), ['b']);
    d = run(d, '-4000 d');
    expect(d.entries.last.id, 4);
  });

  test('stats · print 는 달을 고를 수 있다', () {
    final d = MoneyData.initial();
    expect(runCommand(d, 'print', now).month, DateTime(2026, 9));
    expect(runCommand(d, 'stats 8', now).month, DateTime(2026, 8));
    expect(runCommand(d, 'print 11월', now).month, DateTime(2025, 11));
    expect(runCommand(d, 'print 2025.03', now).month, DateTime(2025, 3));
    expect(runCommand(d, 'print 13', now).route, isNull);
  });

  test('저장했다 불러오기', () {
    var d = run(MoneyData.initial(), 'budget 500000');
    d = run(d, '-4500 커피');
    final back = MoneyData.fromJson(d.toJson());
    expect(back.budget, 500000);
    expect(back.entries.single.memo, '커피');
    expect(back.entries.single.at, now);
    expect(back.nextId, 2);
  });

  test('영수증', () {
    var d = run(MoneyData.initial(), 'budget 10000');
    d = run(d, '-4500 커피');
    d = run(d, '-9000 점심');
    final lines = receiptLines(d, now, now);
    expect(lines.first.left, 'money.exe');
    final texts = lines.map((l) => '${l.left}|${l.right}').toList();
    expect(texts, contains('09.24 커피|4,500'));
    expect(texts, contains('합계 (2건)|13,500원'));
    expect(texts, contains('예산 초과|3,500원'));
  });

  test('recentMonths', () {
    var d = runCommand(MoneyData.initial(), '-50000 장보기', DateTime(2026, 7, 3)).data;
    d = run(d, '-1000 커피');
    final m = recentMonths(d, now, n: 3);
    expect(m.map((x) => x.month.month), [7, 8, 9]);
    expect(m.map((x) => x.amount), [50000, 0, 1000]);
  });
}
