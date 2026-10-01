/// 지출 한 건.
class Entry {
  const Entry({
    required this.id,
    required this.at,
    required this.amount,
    required this.memo,
    required this.tag,
  });

  final int id;

  /// 기록한 시각 (그 달 예산에 들어간다)
  final DateTime at;

  /// 원 단위, 항상 양수
  final int amount;
  final String memo;

  /// # 없이 저장한다. 예: 식비
  final String tag;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.millisecondsSinceEpoch,
        'amount': amount,
        'memo': memo,
        'tag': tag,
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: (j['id'] as num).toInt(),
        at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
        amount: (j['amount'] as num).toInt(),
        memo: (j['memo'] as String?) ?? '',
        tag: (j['tag'] as String?) ?? '기타',
      );
}
