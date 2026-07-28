import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/main.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/models/settings.dart';
import 'package:xuanli/screens/tab_shell.dart';
import 'package:xuanli/services/storage_service.dart';
import 'package:xuanli/services/theme_mode_controller.dart';

Profile _sampleProfileForBootstrapTest() => buildProfile(
      id: 'p1',
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthPlace: '香港',
      mbti: 'ISFP',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // rootBundle 係 process-level singleton，CachingAssetBundle 會將
    // loadString() 嘅 Future cache 住（跨 test）。但每個 testWidgets
    // 跑喺自己個 FakeAsync zone，一個舊 zone 完成咗嘅 cached Future
    // 喺新 zone 度 await 永遠唔會 resolve（Flutter test framework 嘅
    // zone 邊界問題）。呢個 repo 而家有多過一個 testWidgets 會經
    // loadEngineData() 觸發真 asset 讀取，所以要喺 setUp() 清一清
    // cache，確保每個 test 用返自己個 zone 讀一次新鮮嘅。
    rootBundle.clear();
  });

  tearDown(() {
    themeModeController.value = ThemeMode.system;
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

  testWidgets(
      'XuanLiApp：bootstrap 會由 storage 讀返已存嘅深色模式設定，更新 themeModeController',
      (tester) async {
    await StorageService().saveSettings(const AppSettings(
      themeMode: ThemeMode.dark,
      notificationsEnabled: true,
      notificationHour: 7,
      notificationMinute: 30,
    ));

    await tester.pumpWidget(const XuanLiApp());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(themeModeController.value, ThemeMode.dark);
  });

  testWidgets(
      'XuanLiApp：有已存 profile 時，bootstrap 會觸發一次 widget data refresh（唔會等佢完先顯示 TabShell）',
      (tester) async {
    var saveWidgetDataCalled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
      if (call.method == 'saveWidgetData') saveWidgetDataCalled = true;
      return true;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    });

    await StorageService().savePrimaryProfile(_sampleProfileForBootstrapTest());

    await tester.pumpWidget(const XuanLiApp());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.byType(TabShell), findsOneWidget);
    expect(saveWidgetDataCalled, isTrue);
  });
}
