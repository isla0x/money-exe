import '../models/entry.dart';

/// 밝기 모드. auto = 폰 설정을 따른다.
const modeIds = ['auto', 'light', 'dark'];

/// 예산 주기. 한 달(기본) 또는 매주 월요일에 다시 차는 일주일.
enum Period { month, week }

/// 앱에 저장되는 전부. UI 와 저장소에 의존하지 않는다.
class MoneyData {
  const MoneyData({
    required this.entries,
    required this.budget,
    required this.nextId,
    this.period = Period.month,
    this.mode = 'auto',
  });

  factory MoneyData.initial() => const MoneyData(entries: [], budget: 0, nextId: 1);

  /// 기록한 순서 (id 오름차순)
  final List<Entry> entries;

  /// 한 주기(한 달 또는 일주일) 예산 (원). 0 이면 아직 안 정했다.
  final int budget;
  final int nextId;
  final Period period;

  /// 화면 밝기: auto(폰 설정을 따름) | light | dark
  final String mode;

  MoneyData copyWith({List<Entry>? entries, int? budget, int? nextId, Period? period, String? mode}) => MoneyData(
        entries: entries ?? this.entries,
        budget: budget ?? this.budget,
        nextId: nextId ?? this.nextId,
        period: period ?? this.period,
        mode: mode ?? this.mode,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        'entries': [for (final e in entries) e.toJson()],
        'budget': budget,
        'period': period.name,
        'mode': mode,
        'nextId': nextId,
      };

  factory MoneyData.fromJson(Map<String, dynamic> j) {
    final entries = [
      for (final e in (j['entries'] as List? ?? const [])) Entry.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    var next = (j['nextId'] as num?)?.toInt() ?? 1;
    for (final e in entries) {
      if (e.id >= next) next = e.id + 1;
    }
    return MoneyData(
      entries: entries,
      budget: (j['budget'] as num?)?.toInt() ?? 0,
      nextId: next,
      period: j['period'] == 'week' ? Period.week : Period.month,
      mode: modeIds.contains(j['mode']) ? j['mode'] as String : 'auto',
    );
  }
}

// ---------------------------------------------------------------- 숫자 · 날짜

/// 12345 → 12,345
String won(int n) {
  final neg = n < 0;
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return neg ? '-$b' : b.toString();
}

String two(int n) => n.toString().padLeft(2, '0');

const weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

/// 09.24 목
String shortDate(DateTime d) => '${two(d.month)}.${two(d.day)} ${weekdayKo[d.weekday - 1]}';

/// 09.24
String monthDay(DateTime d) => '${two(d.month)}.${two(d.day)}';

/// 2026.09
String yearMonth(DateTime m) => '${m.year}.${two(m.month)}';

DateTime monthOf(DateTime t) => DateTime(t.year, t.month);

DateTime addMonths(DateTime m, int n) => DateTime(m.year, m.month + n);

int daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;

bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime addDays(DateTime day, int n) => DateTime(day.year, day.month, day.day + n);

/// 그 주 월요일 0시
DateTime weekStart(DateTime t) => DateTime(t.year, t.month, t.day - (t.weekday - 1));

/// a 부터 b 까지 며칠 (서머타임이 있어도 안전하게)
int daysBetween(DateTime a, DateTime b) => (dayOf(b).difference(dayOf(a)).inHours / 24).round();

/// 9.21~9.27
String rangeLabel(DateTime from, DateTime toExclusive) {
  final last = addDays(toExclusive, -1);
  return '${from.month}.${from.day}~${last.month}.${last.day}';
}

/// [from] 이상 [to] 미만에 기록한 것
List<Entry> entriesBetween(MoneyData d, DateTime from, DateTime to) =>
    d.entries.where((e) => !e.at.isBefore(from) && e.at.isBefore(to)).toList();

/// 그 달 기록, 오래된 것부터.
List<Entry> entriesIn(MoneyData d, DateTime month) {
  final list = d.entries.where((e) => sameMonth(e.at, month)).toList();
  list.sort((a, b) {
    final c = a.at.compareTo(b.at);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return list;
}

int sumOf(Iterable<Entry> list) => list.fold(0, (s, e) => s + e.amount);

// ---------------------------------------------------------------- 디스크 (= 예산)

enum DiskLevel {
  /// 예산을 아직 안 정했다
  none,
  ok,

  /// 80% 이상 썼다
  warn,

  /// 예산을 넘었다
  full,
}

/// 이번 주기(이번 달 또는 이번 주) 예산을 디스크 용량처럼 본 숫자들.
class Disk {
  const Disk({
    required this.period,
    required this.month,
    required this.start,
    required this.end,
    required this.spent,
    required this.budget,
    required this.count,
    required this.daysLeft,
    this.weekShare,
    this.weekSpent = 0,
  });

  factory Disk.of(MoneyData d, DateTime now) {
    final today = dayOf(now);
    if (d.period == Period.week) {
      final start = weekStart(now);
      final end = addDays(start, 7);
      final list = entriesBetween(d, start, end);
      return Disk(
        period: Period.week,
        month: monthOf(now),
        start: start,
        end: end,
        spent: sumOf(list),
        budget: d.budget,
        count: list.length,
        daysLeft: daysBetween(today, end),
      );
    }
    final start = monthOf(now);
    final end = addMonths(start, 1);
    final list = entriesBetween(d, start, end);
    // 한 달 예산에서 이번 주 몫: 이번 주가 시작할 때 남아 있던 돈을 남은 날에 고르게 나눈 것.
    int? share;
    var weekSpent = 0;
    if (d.budget > 0) {
      var ws = weekStart(now);
      if (ws.isBefore(start)) ws = start;
      var we = addDays(weekStart(now), 7);
      if (we.isAfter(end)) we = end;
      final before = sumOf(entriesBetween(d, start, ws));
      weekSpent = sumOf(entriesBetween(d, ws, we));
      final daysFromWs = daysBetween(ws, end);
      share = daysFromWs <= 0 ? 0 : ((d.budget - before) * daysBetween(ws, we) / daysFromWs).floor();
    }
    return Disk(
      period: Period.month,
      month: start,
      start: start,
      end: end,
      spent: sumOf(list),
      budget: d.budget,
      count: list.length,
      daysLeft: daysBetween(today, end),
      weekShare: share,
      weekSpent: weekSpent,
    );
  }

  final Period period;

  /// 지금 달 (목록 · 영수증은 달 단위)
  final DateTime month;

  /// 이번 주기의 시작과 끝 (끝은 포함하지 않음)
  final DateTime start;
  final DateTime end;
  final int spent;
  final int budget;
  final int count;

  /// 오늘을 포함해 이번 주기에 남은 날
  final int daysLeft;

  /// 한 달 예산일 때 이번 주 몫과 이번 주에 쓴 돈
  final int? weekShare;
  final int weekSpent;

  bool get weekly => period == Period.week;

  int get free => budget - spent;

  /// 0 ~ (넘으면 100 이상). 소수 첫째 자리까지.
  double get pct => budget <= 0 ? 0 : (spent * 1000 / budget).round() / 10;

  /// 막대 길이 0 ~ 1
  double get fill => budget <= 0 ? 0 : (spent / budget).clamp(0, 1).toDouble();

  DiskLevel get level {
    if (budget <= 0) return DiskLevel.none;
    if (free < 0) return DiskLevel.full;
    if (pct >= 80) return DiskLevel.warn;
    return DiskLevel.ok;
  }

  /// 남은 날 동안 하루에 쓸 수 있는 돈 (100원 단위 내림)
  int get perDay => free <= 0 || daysLeft <= 0 ? 0 : (free ~/ daysLeft) ~/ 100 * 100;

  String get pctLabel => pct == pct.roundToDouble() ? '${pct.toInt()}%' : '$pct%';

  /// "9월" 또는 "이번 주"
  String get periodName => weekly ? '이번 주' : '${month.month}월';

  /// 디스크 상자 제목: 9월 예산 / 이번 주 예산 (9.28~10.4)
  String get title => weekly ? '이번 주 예산 (${rangeLabel(start, end)})' : '${month.month}월 예산';

  /// 디스크 상자 아래 한 줄
  String get message => switch (level) {
        DiskLevel.none => '예산이 아직 없어요. budget 700000 처럼 정해 보세요.',
        DiskLevel.full => weekly
            ? '디스크가 가득 찼어요: 예산을 ${won(-free)}원 넘었어요 · 월요일에 비워져요'
            : '디스크가 가득 찼어요: 예산을 ${won(-free)}원 넘었어요',
        DiskLevel.warn => '공간 부족 경고 · 여유 ${won(free)}원 · 남은 $daysLeft일, 하루 ${won(perDay)}원',
        DiskLevel.ok => '여유 공간 ${won(free)}원 · 남은 $daysLeft일, 하루 ${won(perDay)}원',
      };

  /// 한 달 예산일 때 이번 주 몫이 얼마나 남았는지. 보여줄 게 없으면 null.
  int? get weekLeft {
    final s = weekShare;
    if (weekly || s == null || level == DiskLevel.full) return null;
    return s - weekSpent;
  }

  String? get weekMessage {
    final left = weekLeft;
    if (left == null) return null;
    return left >= 0
        ? '이번 주 여유 ${won(left ~/ 100 * 100)}원 (이번 주 쓴 돈 ${won(weekSpent)}원)'
        : '이번 주 몫을 ${won(-left)}원 넘었어요 (이번 주 쓴 돈 ${won(weekSpent)}원)';
  }
}

// ---------------------------------------------------------------- 통계

class TagTotal {
  const TagTotal(this.tag, this.amount, this.count);

  final String tag;
  final int amount;
  final int count;
}

/// 태그별 합계, 많이 쓴 순.
List<TagTotal> byTag(List<Entry> list) {
  final sums = <String, int>{};
  final counts = <String, int>{};
  for (final e in list) {
    sums[e.tag] = (sums[e.tag] ?? 0) + e.amount;
    counts[e.tag] = (counts[e.tag] ?? 0) + 1;
  }
  final out = [for (final t in sums.keys) TagTotal(t, sums[t]!, counts[t]!)];
  out.sort((a, b) => b.amount.compareTo(a.amount));
  return out;
}

class MonthTotal {
  const MonthTotal(this.month, this.amount);

  final DateTime month;
  final int amount;
}

/// [month] 를 포함한 최근 [n] 달의 합계, 오래된 달부터.
List<MonthTotal> recentMonths(MoneyData d, DateTime month, {int n = 6}) => [
      for (var i = n - 1; i >= 0; i--)
        MonthTotal(addMonths(monthOf(month), -i), sumOf(entriesIn(d, addMonths(monthOf(month), -i)))),
    ];

// ---------------------------------------------------------------- 영수증

enum ReceiptKind { title, center, pair, total, rule, barcode }

class ReceiptLine {
  const ReceiptLine(this.kind, [this.left = '', this.right = '']);

  final ReceiptKind kind;
  final String left;
  final String right;
}

/// print 로 출력하는 그 달 영수증. 위에서부터 한 줄씩 출력된다.
List<ReceiptLine> receiptLines(MoneyData d, DateTime month, DateTime now) {
  final m = monthOf(month);
  final list = entriesIn(d, m);
  final spent = sumOf(list);
  final out = <ReceiptLine>[
    const ReceiptLine(ReceiptKind.title, 'money.exe'),
    ReceiptLine(ReceiptKind.center, 'RECEIPT · ${yearMonth(m)}'),
    ReceiptLine(ReceiptKind.center, 'C:\\money\\${m.year}\\${two(m.month)}.txt'),
    const ReceiptLine(ReceiptKind.rule),
  ];
  if (list.isEmpty) {
    out.add(const ReceiptLine(ReceiptKind.center, '(기록 없음)'));
  }
  for (final e in list) {
    out.add(ReceiptLine(ReceiptKind.pair, '${monthDay(e.at)} ${e.memo}', won(e.amount)));
  }
  out.add(const ReceiptLine(ReceiptKind.rule));
  out.add(ReceiptLine(ReceiptKind.total, '합계 (${list.length}건)', '${won(spent)}원'));
  if (d.budget > 0 && d.period == Period.month) {
    final free = d.budget - spent;
    out.add(ReceiptLine(ReceiptKind.pair, '예산', '${won(d.budget)}원'));
    out.add(ReceiptLine(ReceiptKind.total, free >= 0 ? '여유 공간' : '예산 초과', '${won(free.abs())}원'));
  }
  final tags = byTag(list);
  if (tags.isNotEmpty) {
    out.add(const ReceiptLine(ReceiptKind.rule));
    for (final t in tags.take(5)) {
      out.add(ReceiptLine(ReceiptKind.pair, '#${t.tag}', won(t.amount)));
    }
  }
  out.addAll([
    const ReceiptLine(ReceiptKind.rule),
    const ReceiptLine(ReceiptKind.center, '오늘도 아껴서, 천천히.'),
    const ReceiptLine(ReceiptKind.barcode, '|| ||| | |||| || ||| | || |||'),
    ReceiptLine(ReceiptKind.center, '${now.year}.${two(now.month)}.${two(now.day)} ${two(now.hour)}:${two(now.minute)}'),
  ]);
  return out;
}
