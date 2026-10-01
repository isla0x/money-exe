import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/commands.dart';
import '../logic/money.dart';
import '../pro/pro_controller.dart';
import '../theme/term_palette.dart';

/// 앱 상태. 명령어를 실행하고 폰 안에만 저장한다 (서버 없음).
class MoneyStore extends ChangeNotifier {
  MoneyStore({DateTime Function()? clock, this.pro}) : _clock = clock ?? DateTime.now {
    pro?.addListener(notifyListeners);
  }

  /// PRO 결제 상태 (아이폰 위젯). 없으면 무료로 취급한다.
  final ProController? pro;
  bool get isPro => pro?.isPro ?? false;

  static const _key = 'money_exe_state_v1';
  static const _maxLog = 4;
  static const _maxHistory = 50;

  final DateTime Function() _clock;
  MoneyData _data = MoneyData.initial();
  SharedPreferences? _prefs;

  final List<LogLine> _log = [
    const LogLine(LogKind.info, "'help' 를 입력하면 명령어 목록을 볼 수 있어요."),
  ];
  final List<String> _history = [];

  MoneyData get data => _data;
  List<LogLine> get log => List.unmodifiable(_log);
  List<String> get history => List.unmodifiable(_history);
  DateTime now() => _clock();
  Disk get disk => Disk.of(_data, _clock());

  Brightness _brightness = Brightness.dark;
  set systemBrightness(Brightness value) {
    if (value == _brightness) return;
    _brightness = value;
    notifyListeners();
  }

  TermPalette get palette => TermPalette.of(_brightness);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) return;
    try {
      _data = MoneyData.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (e) {
      debugPrint('money.exe: 저장된 데이터를 읽지 못해 새로 시작합니다. ($e)');
    }
  }

  /// 명령어를 실행한다. 화면 이동 · 경고창은 돌려준 결과를 보고 화면이 한다.
  CommandResult? run(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    _history.add(s);
    if (_history.length > _maxHistory) _history.removeAt(0);
    // 디버그 빌드 전용: 결제 없이 PRO 켜고 끄기.
    if (kDebugMode && pro != null && s.toLowerCase() == 'pro --dev') {
      pro!.debugToggle();
      return _apply(CommandResult(_data, [
        LogLine(LogKind.cmd, '$prompt $s'),
        LogLine(LogKind.info, '[dev] PRO ${pro!.isPro ? 'on' : 'off'}'),
      ]));
    }
    return _apply(runCommand(_data, s, _clock()));
  }

  void remove(int id) => _apply(removeEntry(_data, id));

  /// 화면 로그에 안내 한 줄.
  void note(String text) => _apply(CommandResult(_data, [LogLine(LogKind.info, text)]));

  /// 날짜가 바뀌었을 수 있으니 다시 그린다 (앱으로 돌아왔을 때).
  void refresh() => notifyListeners();

  CommandResult _apply(CommandResult out) {
    final changed = !identical(out.data, _data);
    _data = out.data;
    if (out.clearLog) {
      _log.clear();
    } else {
      _log.addAll(out.lines);
      if (_log.length > _maxLog) _log.removeRange(0, _log.length - _maxLog);
    }
    notifyListeners();
    if (changed) _prefs?.setString(_key, jsonEncode(_data.toJson()));
    return out;
  }

  @override
  void dispose() {
    pro?.removeListener(notifyListeners);
    super.dispose();
  }
}
