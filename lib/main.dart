import 'dart:async';

import 'package:flutter/material.dart';

import 'models/profile.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/tab_shell.dart';
import 'services/data_loader.dart';
import 'services/notification_scheduler.dart';
import 'services/storage_service.dart';
import 'services/theme_mode_controller.dart';
import 'services/widget_data_bridge.dart';
import 'theme/xuanli_theme.dart';

void main() {
  runApp(const XuanLiApp());
}

class XuanLiApp extends StatelessWidget {
  const XuanLiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: '玄曆',
          debugShowCheckedModeBanner: false,
          theme: XuanLiTheme.light(),
          darkTheme: XuanLiTheme.dark(),
          themeMode: mode,
          home: const _AppBootstrap(),
        );
      },
    );
  }
}

/// 啟動時做兩件事先顯示正式畫面：(1) 由 assets 讀 JSON 落 engine 嘅
/// init*() cache（[loadEngineData]）；(2) 睇下本機有冇已存 profile，
/// 決定跳去 onboarding 定係主 tab shell。
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late final Future<Profile?> _bootstrap = _run();

  Future<Profile?> _run() async {
    await loadEngineData();
    final settings = await StorageService().loadSettings();
    themeModeController.value = settings.themeMode;
    final profile = await StorageService().loadPrimaryProfile();
    if (profile != null) {
      // Fire-and-forget（唔 await）：widget 背景刷新唔應該延遲冷啟動
      // （spec §10 Phase 2 驗收：冷啟動 <2s）。WidgetDataBridge 本身
      // 內部已經 try/catch 晒 platform-write 嗰步，失敗唔會有未處理
      // 嘅 exception 冚出嚟；純 Dart 嘅計算部分冇 catch，如果嗰度爆
      // 係一個真 bug，應該可以喺開發/測試環境俾人發現，唔應該靜靜
      // 吞咗（見 widget_data_bridge.dart 嘅 Task 2 review 討論）。
      unawaited(WidgetDataBridge().refreshNext7Days(profile));
      unawaited(NotificationScheduler()
          .refreshNext7Days(profile: profile, settings: settings));
    }
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Profile?>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('載入失敗：${snapshot.error}')),
          );
        }
        final profile = snapshot.data;
        if (profile == null) {
          return const OnboardingFlow();
        }
        return TabShell(profile: profile);
      },
    );
  }
}
