import '../models/entry.dart';
import 'money.dart';

/// 명령어 해석과 실행. UI 와 저장소에 의존하지 않는 순수 로직이라 테스트하기 쉽다.

enum LogKind { cmd, ok, err, info }

class LogLine {
  const LogLine(this.kind, this.text);

  final LogKind kind;
  final String text;
}

class CommandResult {
  const CommandResult(
    this.data,
    this.lines, {
    this.route,
    this.month,
    this.clearLog = false,
    this.alert = false,
    this.added = false,
  });

  final MoneyData data;
  final List<LogLine> lines;

  /// 열어야 할 화면: 'stats' | 'help' | 'print' | 'pro' | 'restore'
  final String? route;

  /// stats · print 가 볼 달
  final DateTime? month;
  final bool clearLog;

  /// 방금 기록으로 이번 달 예산을 처음 넘었다 → 디스크 공간 부족 창
  final bool alert;

  /// 새 기록이 생겼다 (목록을 맨 아래로)
  final bool added;
}

const prompt = 'C:\\money>';

/// 메모에 들어 있으면 태그를 알아서 붙인다. 위에서부터 먼저 맞는 것.
const autoTags = <(String, List<String>)>[
  ('카페', ['커피', '카페', '아아', '라떼', '스벅', '스타벅스', '메가커피', '컴포즈', '빽다방', '음료', '디저트', '케이크', '빵']),
  ('식비', ['밥', '점심', '저녁', '아침', '야식', '김밥', '배달', '배민', '요기요', '장보기', '마트', '치킨', '피자', '떡볶이', '라면', '편의점', '고기', '식당', '국밥', '분식', '햄버거', '버거', '술', '맥주']),
  ('교통', ['택시', '버스', '지하철', '교통', '기차', 'ktx', 'srt', '주유', '기름', '주차', '톨비', '따릉이']),
  ('쇼핑', ['쿠팡', '옷', '가방', '신발', '쇼핑', '올리브영', '다이소', '무신사', '니트', '바지', '화장품', '29cm', '지그재그']),
  ('구독', ['넷플릭스', '유튜브', '구독', '멜론', '티빙', '왓챠', '쿠팡플레이', '디즈니', '스포티파이', '애플뮤직', 'icloud', '챗gpt', 'claude']),
  ('문화', ['영화', '공연', '콘서트', '책', '전시', '팝콘', '노래방', 'pc방', '게임', '굿즈']),
  ('의료', ['병원', '약국', '약', '치과', '안과', '피부과']),
  ('생활', ['관리비', '통신', '휴대폰', '핸드폰', '전기', '가스', '수도', '세탁', '미용실', '네일']),
  ('선물', ['선물', '생일', '축의금', '부조', '조의금']),
];

String guessTag(String memo) {
  final m = memo.toLowerCase();
  for (final (tag, words) in autoTags) {
    for (final w in words) {
      if (m.contains(w)) return tag;
    }
  }
  return '기타';
}

final _amountRe = RegExp(r'^-?(\d[\d,]*(?:\.\d+)?)(만|천)?원?$');

/// "-4,500" "1.2만" "3천원" → 원. 금액이 아니면 null.
int? parseAmount(String token) {
  final m = _amountRe.firstMatch(token);
  if (m == null) return null;
  final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
  if (v == null) return null;
  final unit = switch (m.group(2)) { '만' => 10000, '천' => 1000, _ => 1 };
  return (v * unit).round();
}

/// "9" "9월" "2026.09" "2026-9" → 그 달. 숫자만 쓰면 오늘 기준 가장 최근의 그 달.
DateTime? parseMonth(String arg, DateTime now) {
  final s = arg.trim().replaceAll('월', '');
  final full = RegExp(r'^(\d{4})[.\-/](\d{1,2})$').firstMatch(s);
  if (full != null) {
    final m = int.parse(full.group(2)!);
    if (m < 1 || m > 12) return null;
    return DateTime(int.parse(full.group(1)!), m);
  }
  final only = int.tryParse(s);
  if (only == null || only < 1 || only > 12) return null;
  return DateTime(only > now.month ? now.year - 1 : now.year, only);
}

const maxAmount = 99999999;
const maxMemo = 40;

CommandResult runCommand(MoneyData d, String raw, DateTime now) {
  final s = raw.trim();
  final echo = LogLine(LogKind.cmd, '$prompt $s');
  final parts = s.split(RegExp(r'\s+'));
  final head = parts.first.toLowerCase();
  final arg = parts.skip(1).join(' ');
  CommandResult reply(List<LogLine> lines, {MoneyData? data}) => CommandResult(data ?? d, [echo, ...lines]);

  switch (head) {
    case 'dir' || 'ls':
      return reply(const []);
    case 'cls' || 'clear':
      return CommandResult(d, const [], clearLog: true);
    case 'help' || '?':
      return CommandResult(d, [echo], route: 'help');
    case 'upgrade' || 'pro':
      return CommandResult(d, [echo], route: 'pro');
    case 'restore':
      return CommandResult(d, [echo], route: 'restore');
    case 'stats' || 'print':
      final month = arg.isEmpty ? monthOf(now) : parseMonth(arg, now);
      if (month == null) {
        return reply([LogLine(LogKind.err, "달을 알 수 없어요: '$arg' (예: $head 9)")]);
      }
      return CommandResult(d, [echo], route: head, month: month);
    case 'undo':
      if (d.entries.isEmpty) return reply(const [LogLine(LogKind.err, '지울 기록이 없어요.')]);
      final last = d.entries.reduce((a, b) => a.id > b.id ? a : b);
      return reply(
        [LogLine(LogKind.ok, '✓ 지웠어요: ${last.memo} ${won(last.amount)}원')],
        data: d.copyWith(entries: [for (final e in d.entries) if (e.id != last.id) e]),
      );
    case 'budget':
      return _budget(d, arg, now, echo);
  }

  if (s.startsWith('+')) {
    return reply(const [LogLine(LogKind.err, 'money.exe 는 쓴 돈만 기록해요. 금액 앞에 - 를 붙이거나 그냥 숫자만 써 주세요.')]);
  }

  // 금액이 들어 있으면 지출 기록. "-" 붙은 금액을 먼저, 없으면 처음 나온 숫자.
  var idx = parts.indexWhere((t) => t.startsWith('-') && parseAmount(t) != null);
  if (idx < 0) idx = parts.indexWhere((t) => parseAmount(t) != null);
  if (idx < 0) {
    return reply([
      LogLine(LogKind.err, "'${parts.first}'은(는) 내부 또는 외부 명령, 실행할 수 있는 프로그램, 또는 배치 파일이 아닙니다."),
      const LogLine(LogKind.info, "'help' 를 입력하면 명령어를 볼 수 있어요."),
    ]);
  }
  final amount = parseAmount(parts[idx])!;
  if (amount <= 0) return reply(const [LogLine(LogKind.err, '0원은 기록할 수 없어요.')]);
  if (amount > maxAmount) return reply(const [LogLine(LogKind.err, '금액이 너무 커요. (최대 99,999,999원)')]);

  final rest = [...parts.take(idx), ...parts.skip(idx + 1)];
  final tagWord = rest.firstWhere((t) => t.startsWith('#') && t.length > 1, orElse: () => '');
  var memo = rest.where((t) => !t.startsWith('#')).join(' ').trim();
  final tag = tagWord.isNotEmpty ? tagWord.substring(1) : guessTag(memo);
  if (memo.isEmpty) memo = tag;
  if (memo.length > maxMemo) memo = memo.substring(0, maxMemo);

  final before = Disk.of(d, now);
  final data = d.copyWith(
    entries: [...d.entries, Entry(id: d.nextId, at: now, amount: amount, memo: memo, tag: tag)],
    nextId: d.nextId + 1,
  );
  final after = Disk.of(data, now);
  final tail = switch (after.level) {
    DiskLevel.none => '이번 달 ${won(after.spent)}원',
    DiskLevel.full => '예산 ${won(-after.free)}원 초과',
    _ => '여유 ${won(after.free)}원',
  };
  return CommandResult(
    data,
    [echo, LogLine(after.level == DiskLevel.full ? LogKind.err : LogKind.ok, '✓ ${won(amount)}원 기록 · #$tag · $tail')],
    alert: after.level == DiskLevel.full && before.level != DiskLevel.full,
    added: true,
  );
}

const _weekWords = {'/week', 'week', '/w', '주', '/주', '주간', '매주', '일주일'};
const _monthWords = {'/month', 'month', '/m', '월', '/월', '달', '월간', '매달', '한달'};

CommandResult _budget(MoneyData d, String arg, DateTime now, LogLine echo) {
  // "budget 150000 /week" "budget 주간 15만" "budget 700000" (주기를 안 쓰면 지금 주기 그대로)
  Period? period;
  final rest = <String>[];
  for (final t in arg.split(RegExp(r'\s+')).where((t) => t.isNotEmpty)) {
    final w = t.toLowerCase();
    if (_weekWords.contains(w)) {
      period = Period.week;
    } else if (_monthWords.contains(w)) {
      period = Period.month;
    } else {
      rest.add(t);
    }
  }
  final a = rest.join();
  String name(Period p) => p == Period.week ? '주간' : '한 달';
  if (a.isEmpty && period == null) {
    return CommandResult(d, [
      echo,
      LogLine(
        LogKind.info,
        d.budget <= 0
            ? '아직 예산이 없어요.'
            : d.period == Period.week
                ? '주간 예산: ${won(d.budget)}원 (매주 월요일에 다시 차요)'
                : '한 달 예산: ${won(d.budget)}원',
      ),
      const LogLine(LogKind.info, '바꾸려면: budget 700000  ·  주간: budget 150000 /week  ·  끄기: budget 0'),
    ]);
  }
  final b = a.isEmpty ? d.budget : parseAmount(a);
  if (b == null || b < 0 || b > maxAmount) {
    return CommandResult(d, [echo, LogLine(LogKind.err, "예산을 알 수 없어요: '$arg' (예: budget 700000)")]);
  }
  final data = d.copyWith(budget: b, period: period ?? d.period);
  if (b == 0) return CommandResult(data, [echo, const LogLine(LogKind.ok, '✓ 예산을 껐어요.')]);
  final disk = Disk.of(data, now);
  final tail = disk.free >= 0 ? '여유 ${won(disk.free)}원' : '${won(-disk.free)}원 초과';
  return CommandResult(data, [
    echo,
    LogLine(LogKind.ok, '✓ ${name(data.period)} 예산을 ${won(b)}원으로 정했어요 · $tail'),
    if (data.period == Period.week) const LogLine(LogKind.info, '매주 월요일에 디스크가 다시 비워져요.'),
  ]);
}

/// 목록의 rm 버튼.
CommandResult removeEntry(MoneyData d, int id) {
  final hit = d.entries.where((e) => e.id == id).toList();
  if (hit.isEmpty) return CommandResult(d, const []);
  final e = hit.first;
  return CommandResult(
    d.copyWith(entries: [for (final x in d.entries) if (x.id != id) x]),
    [LogLine(LogKind.ok, '✓ 지웠어요: ${monthDay(e.at)} ${e.memo} ${won(e.amount)}원')],
  );
}
