import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/main.dart';
import 'package:xuanli/screens/tab_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'XuanLiApp：冇已存 profile 時，先顯示載入中，再跳去 onboarding 流程',
      (tester) async {
    await tester.pumpWidget(const XuanLiApp());

    // Bootstrap future（loadEngineData + loadPrimaryProfile）未 resolve
    // 之前，一個 pump() 應該只行到 loading 狀態。
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // loadEngineData() 靠 rootBundle.loadString() 讀真 asset，
    // 呢個係真實 async I/O，唔係 fake-clock timer——單靠 pump()／
    // pumpAndSettle() 嘅 FakeAsync clock 郁唔到佢，會一直卡喺
    // loading 畫面（甚至 pumpAndSettle 會 timeout）。要用 runAsync()
    // 跳出 fake async zone 等真實 I/O 完成，再 pump 一次攞新畫面。
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    // 冇存過 profile → 應該路由去真正 onboarding 流程（第一步係
    // BirthDataStep，唔係 TabShell）。
    expect(find.text('你嘅出生一刻'), findsOneWidget);
    expect(find.byType(TabShell), findsNothing);

    // 注意：有已存 profile → TabShell 呢條路由未有覆蓋，
    // 因為要預先落一個完整 serialized Profile 落 SharedPreferences，
    // 超出呢次補漏嘅範圍。
  });
}
