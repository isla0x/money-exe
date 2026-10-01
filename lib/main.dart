import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pro/pro_controller.dart';
import 'screens/boot_screen.dart';
import 'screens/home_screen.dart';
import 'state/money_store.dart';
import 'theme/term_palette.dart';
import 'widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final pro = ProController();
  await pro.init();
  final store = MoneyStore(pro: pro);
  await store.load();
  store.systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

  // 위젯은 기록 · 예산 · PRO 상태가 바뀔 때마다 새로 그린다. (store 는 pro 변화도 알려준다)
  final fromWidget = await WidgetSync.init();
  void pushWidget() => WidgetSync.push(store.data, store.now(), pro: store.isPro);
  pushWidget();
  store.addListener(pushWidget);

  runApp(MoneyExeApp(store: store, fromWidget: fromWidget));
}

class MoneyExeApp extends StatefulWidget {
  const MoneyExeApp({super.key, required this.store, this.fromWidget = false});

  final MoneyStore store;

  /// 위젯을 눌러서 켜졌으면 부팅 화면 없이 바로 입력칸을 연다.
  final bool fromWidget;

  @override
  State<MoneyExeApp> createState() => _MoneyExeAppState();
}

class _MoneyExeAppState extends State<MoneyExeApp> with WidgetsBindingObserver {
  MoneyStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 폰에서 다크/라이트를 바꾸면 바로 따라간다.
  @override
  void didChangePlatformBrightness() {
    store.systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  /// 자정을 넘겨 다시 열면 날짜(이번 달 디스크)가 바뀌어 있어야 한다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) store.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        return MaterialApp(
          title: 'money.exe',
          debugShowCheckedModeBanner: false,
          theme: _theme(p),
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: (p.isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light).copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: p.bar,
              systemNavigationBarIconBrightness: p.isLight ? Brightness.dark : Brightness.light,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: widget.fromWidget ? HomeScreen(store: store, focusInput: true) : BootScreen(store: store),
        );
      },
    );
  }

  ThemeData _theme(TermPalette p) => ThemeData(
        useMaterial3: true,
        brightness: p.isLight ? Brightness.light : Brightness.dark,
        scaffoldBackgroundColor: p.bg,
        fontFamily: monoFamily,
        fontFamilyFallback: monoFallback,
        colorScheme: p.isLight
            ? ColorScheme.light(surface: p.bg, primary: p.ok, secondary: p.cmd, error: p.warn)
            : ColorScheme.dark(surface: p.bg, primary: p.ok, secondary: p.cmd, error: p.warn),
        splashFactory: NoSplash.splashFactory,
        highlightColor: p.fg.withAlpha(30),
        hoverColor: p.fg.withAlpha(16),
        focusColor: p.cmd.withAlpha(48),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: p.ok,
          selectionColor: p.cmd.withAlpha(90),
          selectionHandleColor: p.ok,
        ),
      );
}
