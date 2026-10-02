import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'logic/money.dart';

/// 홈 화면 · 잠금화면 위젯(iOS WidgetKit)으로 데이터를 넘기고, 위젯을 누르면 앱이 알게 한다.
///
/// 앱과 위젯은 App Group 저장소를 같이 쓴다. Xcode 에서 Runner 와 MoneyWidget
/// 두 타깃 모두 아래 [appGroupId] 로 App Groups 를 켜야 한다.
class WidgetSync {
  static const appGroupId = 'group.com.isla0x.moneyexe';
  static const iOSWidgetKind = 'MoneyWidget';
  static const snapshotKey = 'snapshot';

  /// 위젯을 누르면 열리는 주소. ios/Runner/Info.plist 의 URL scheme 과 같아야 한다.
  static const urlScheme = 'moneyexe';

  /// 위젯을 눌러서 "바로 입력" 을 원할 때마다 1씩 올라간다. 홈 화면이 듣고 입력칸을 연다.
  static final addRequests = ValueNotifier<int>(0);

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// 위젯을 눌러서 앱이 켜졌는지 (부팅 화면을 건너뛴다).
  static Future<bool> init() async {
    if (!_supported) return false;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      HomeWidget.widgetClicked.listen(_onClick, onError: (Object e) => debugPrint('money.exe widget: $e'));
      final first = await HomeWidget.initiallyLaunchedFromHomeWidget();
      return _isAdd(first);
    } catch (e) {
      debugPrint('money.exe widget: init 실패 ($e)');
      return false;
    }
  }

  static bool _isAdd(Uri? uri) => uri != null && uri.scheme == urlScheme;

  static void _onClick(Uri? uri) {
    if (_isAdd(uri)) addRequests.value++;
  }

  static Future<void> push(MoneyData d, DateTime now, {required bool pro}) async {
    if (!_supported) return;
    try {
      await HomeWidget.saveWidgetData<String>(snapshotKey, jsonEncode(widgetSnapshot(d, now, pro: pro)));
      await HomeWidget.updateWidget(iOSName: iOSWidgetKind);
    } catch (e) {
      // 위젯 타깃이 아직 없거나 App Group 이 꺼져 있어도 앱은 계속 동작해야 한다.
      debugPrint('money.exe widget: 업데이트 실패 ($e)');
    }
  }
}

/// 위젯이 읽는 JSON. Swift 쪽 `MoneySnapshot` 과 키가 같아야 한다.
///
/// 위젯은 날짜가 지나면 스스로 다시 계산한다: [until] 이 지나면 새 주기(빈 디스크)로,
/// 남은 날 · 하루 쓸 돈은 그날 날짜로. 그래서 시작 · 끝 시각을 같이 넘긴다.
Map<String, dynamic> widgetSnapshot(MoneyData d, DateTime now, {bool pro = false, int maxRecent = 3}) {
  final disk = Disk.of(d, now);
  final recent = entriesBetween(d, disk.start, disk.end)
    ..sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final last = recent.length > maxRecent ? recent.sublist(recent.length - maxRecent) : recent;
  return {
    'v': 1,
    'pro': pro,
    'period': d.period.name,
    // 위젯은 auto 일 때 iOS 의 다크/라이트 설정을 직접 따른다.
    'mode': d.mode,
    // 이번 주기 예산 (추가 예산 포함). 주기가 지나면 위젯은 기본 예산(base)으로 돌아간다.
    'budget': disk.budget,
    'base': d.budget,
    'spent': disk.spent,
    'count': disk.count,
    'from': disk.start.millisecondsSinceEpoch,
    'until': disk.end.millisecondsSinceEpoch,
    'recent': [
      for (final e in last) {'d': monthDay(e.at), 'm': e.memo, 'a': e.amount},
    ],
  };
}
