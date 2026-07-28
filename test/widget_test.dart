import 'package:app_links_platform_interface/app_links_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/main.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/models/settings.dart';
import 'package:xuanli/screens/calendar/calendar_screen.dart';
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

/// 假嘅 [AppLinksPlatform]，直接控制 getInitialLink() 想要嘅 URI——
/// 同 deep_link_router_test.dart 用緊嘅同一個 fake（見嗰邊嘅解釋：
/// `AppLinksPlatform.instance` 本身就係一個特登開俾人 inject 嘅
/// static setter，係佢自己推薦嘅測試方式）。
class _FakeAppLinksPlatform extends AppLinksPlatform {
  final Uri? initialLink;
  _FakeAppLinksPlatform(this.initialLink);

  @override
  Future<Uri?> getInitialLink() async => initialLink;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 起 test 之前捕捉住真實嘅預設 platform instance，等每個 test 完咗
  // 都可以復原返去——唔可以好似 plan 度噉樣用 `addTearDown(() =>
  // AppLinksPlatform.instance = _FakeAppLinksPlatform(null))`，嗰句
  // 淨係「換咗第二個 fake」，唔係「復原返真實預設值」，會令下一個喺
  // 同一個檔案跑嘅 test 繼承咗呢個 test 留低嘅 fake instance（同
  // deep_link_router_test.dart 果邊 Task 1 review 捉到嘅同一種
  // test-isolation bug）。
  final defaultAppLinksPlatform = AppLinksPlatform.instance;

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
    // _AppBootstrap._run() 而家會 await DeepLinkRouter().getInitialDayLink()
    // ——用真實嘅預設 AppLinksPlatform（未 mock 過任何 handler）喺
    // testWidgets 嘅 FakeAsync zone 入面，個 MethodChannel round-trip
    // 實測要真實時間先完成（唔淨係 microtask，`tester.pump()` 郁唔到
    // 佢，就算 `tester.runAsync()` 等 50ms 都仲未夠——同 loadEngineData()
    // 嗰種「真 I/O 要 runAsync() 先郁到」情況係同一類 zone 邊界問題，
    // 但呢個仲要更耐，會拖累成個檔案所有 test）。同 home_widget／
    // local_notifications 呢啲 channel 一致嘅做法：用假 platform 令
    // 呢一步喺全部 test 預設都即刻完成，唔使個個 test 都要自己等額外
    // 真實時間。個別 test（下面「冷啟動有 xuanli://day/... link」）
    // 先自己覆寫做帶住真 URI 嘅 fake。
    AppLinksPlatform.instance = _FakeAppLinksPlatform(null);
  });

  tearDown(() {
    themeModeController.value = ThemeMode.system;
    AppLinksPlatform.instance = defaultAppLinksPlatform;
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

  // 呢個 test 名講「唔會等佢完先顯示 TabShell」，但 pumpAndSettle() 會
  // drain 埋成個 fire-and-forget call 先至去到 assertion，所以實際上
  // 冇證明到「唔阻住」呢個 timing claim——淨係證明咗 bootstrap 期間
  // saveWidgetData 真係會被 call 到。真正嘅「唔阻住」保證嚟自
  // main.dart 冇 await 呢個 call（睇 _run() 嗰句 unawaited(...)），
  // 唔係嚟自呢個 test。
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

  testWidgets(
      'XuanLiApp：有已存 profile 時，bootstrap 會觸發一次 notification refresh',
      (tester) async {
    var initializeCalled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        if (call.method == 'initialize') initializeCalled = true;
        return true;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'Asia/Hong_Kong',
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('dexterous.com/flutter/local_notifications'), null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_timezone'), null);
    });

    await StorageService().savePrimaryProfile(_sampleProfileForBootstrapTest());

    await tester.pumpWidget(const XuanLiApp());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.byType(TabShell), findsOneWidget);
    expect(initializeCalled, isTrue);
  });

  testWidgets('XuanLiApp：冷啟動有 xuanli://day/... link → 直接去月曆 tab 揀咗嗰日',
      (tester) async {
    AppLinksPlatform.instance =
        _FakeAppLinksPlatform(Uri.parse('xuanli://day/2026-08-20'));

    await StorageService().savePrimaryProfile(_sampleProfileForBootstrapTest());

    await tester.pumpWidget(const XuanLiApp());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final calendarScreenFinder = find.byType(CalendarScreen);
    expect(calendarScreenFinder, findsOneWidget);
    final calendarScreen = tester.widget<CalendarScreen>(calendarScreenFinder);
    expect(calendarScreen.initialSelectedDate, DateTime(2026, 8, 20));
  });
}
