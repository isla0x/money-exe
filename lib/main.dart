import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/boot_screen.dart';
import 'state/money_store.dart';
import 'theme/term_palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = MoneyStore();
  await store.load();
  store.systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  runApp(MoneyExeApp(store: store));
}

class MoneyExeApp extends StatefulWidget {
  const MoneyExeApp({super.key, required this.store});

  final MoneyStore store;

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
          home: BootScreen(store: store),
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
