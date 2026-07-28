import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/screens/onboarding/onboarding_flow.dart';
import 'package:xuanli/screens/settings/settings_screen.dart';
import 'package:xuanli/services/storage_service.dart';
import 'package:xuanli/services/theme_mode_controller.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

Profile _sampleProfile() => Profile(
      id: 'p1',
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthPlace: '香港',
      mbti: 'ISFP',
      pillars: const ['己卯', '癸酉', '乙亥', '辛巳'],
      wuxing: const {'木': 30, '火': 14, '土': 13, '金': 15, '水': 28},
      favorable: const ['水', '木'],
      unfavorable: const ['金', '土'],
      dayMaster: '乙木',
      ziweiStar: '太陰',
      zodiac: '兔',
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    themeModeController.value = ThemeMode.system;
  });

  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: child);

  testWidgets('顯示三個外觀選項＋通知開關（預設開・07:30）＋資料/關於嘅動作列', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('跟系統'), findsOneWidget);
    expect(find.text('常開'), findsOneWidget);
    expect(find.text('常關'), findsOneWidget);
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('匯出 JSON'), findsOneWidget);
    expect(find.text('匯入 JSON'), findsOneWidget);
    expect(find.text('重新做 Onboarding'), findsOneWidget);
    expect(find.text('免責聲明全文'), findsOneWidget);
    expect(find.text('關於玄曆'), findsOneWidget);
  });

  testWidgets('撳「常開」會即刻更新 themeModeController 並存落 storage', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('常開'));
    await tester.pumpAndSettle();

    expect(themeModeController.value, ThemeMode.dark);
    final saved = await StorageService().loadSettings();
    expect(saved.themeMode, ThemeMode.dark);
  });

  testWidgets('關咗「每朝推送」，推送時間列會消失；開返會再顯示', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('推送時間'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('推送時間'), findsNothing);

    final saved = await StorageService().loadSettings();
    expect(saved.notificationsEnabled, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('推送時間'), findsOneWidget);
  });

  testWidgets('撳「匯出 JSON」／「匯入 JSON」會顯示 stub SnackBar', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('匯出 JSON'));
    await tester.pump();
    expect(find.textContaining('之後有 device 先驗證'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(find.text('匯入 JSON'));
    await tester.pump();
    expect(find.textContaining('之後有 device 先驗證'), findsOneWidget);
  });

  testWidgets('撳「重新做 Onboarding」→ 確定：清咗 profile 並跳去 OnboardingFlow', (tester) async {
    await StorageService().savePrimaryProfile(_sampleProfile());

    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新做 Onboarding'));
    await tester.pumpAndSettle();
    expect(find.text('確定'), findsOneWidget);

    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(await StorageService().loadPrimaryProfile(), isNull);
  });

  testWidgets('撳「重新做 Onboarding」→ 取消：留喺設定頁，profile 冇被清', (tester) async {
    await StorageService().savePrimaryProfile(_sampleProfile());

    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新做 Onboarding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(await StorageService().loadPrimaryProfile(), isNotNull);
  });

  testWidgets('撳「免責聲明全文」／「關於玄曆」會彈 dialog，撳「知道喇」會關返', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('免責聲明全文'));
    await tester.pumpAndSettle();
    expect(find.textContaining('僅供參考'), findsOneWidget);
    await tester.tap(find.text('知道喇'));
    await tester.pumpAndSettle();
    expect(find.textContaining('僅供參考'), findsNothing);

    await tester.tap(find.text('關於玄曆'));
    await tester.pumpAndSettle();
    expect(find.textContaining('版本'), findsOneWidget);
    await tester.tap(find.text('知道喇'));
    await tester.pumpAndSettle();
    expect(find.textContaining('版本'), findsNothing);
  });

  testWidgets('撳返頭嘅 ‹ 會 pop 返上一頁', (tester) async {
    await tester.pumpWidget(wrap(Builder(builder: (context) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      );
    })));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });
}
