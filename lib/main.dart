import 'package:flutter/material.dart';

import 'models/profile.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/tab_shell.dart';
import 'services/data_loader.dart';
import 'services/storage_service.dart';
import 'theme/xuanli_theme.dart';

void main() {
  runApp(const XuanLiApp());
}

class XuanLiApp extends StatelessWidget {
  const XuanLiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '玄曆',
      debugShowCheckedModeBanner: false,
      theme: XuanLiTheme.light(),
      darkTheme: XuanLiTheme.dark(),
      home: const _AppBootstrap(),
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
    return StorageService().loadPrimaryProfile();
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
