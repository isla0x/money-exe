import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_exe/screens/home_screen.dart';
import 'package:money_exe/state/money_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<MoneyStore> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = MoneyStore(clock: () => DateTime(2026, 9, 24, 12));
    await store.load();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store)));
    return store;
  }

  testWidgets('입력하면 목록과 디스크가 바뀐다', (tester) async {
    final store = await pump(tester);
    expect(find.textContaining('이번 달 기록이 없어요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'budget 10000');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '-4500 커피');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(store.data.entries.single.tag, '카페');
    expect(find.text('커피'), findsOneWidget);
    expect(find.text('-4,500'), findsOneWidget);
    expect(find.text('#카페'), findsOneWidget);
    expect(find.text('45% 사용'), findsOneWidget);
  });

  testWidgets('예산을 넘으면 디스크 공간 부족 창', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'budget 10000');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '-12000 가방');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('money.exe - 디스크 공간 부족'), findsOneWidget);
    expect(find.textContaining('2,000원 초과'), findsWidgets);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('money.exe - 디스크 공간 부족'), findsNothing);
  });

  testWidgets('rm 은 두 번 눌러야 지워진다', (tester) async {
    final store = await pump(tester);
    store.run('-3000 떡볶이');
    await tester.pump();
    await tester.tap(find.text('rm'));
    await tester.pump();
    expect(store.data.entries, hasLength(1));
    await tester.tap(find.text('rm?'));
    await tester.pump();
    expect(store.data.entries, isEmpty);
    await tester.pump(const Duration(seconds: 4));
  });
}
