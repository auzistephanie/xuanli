import 'package:flutter/material.dart';

import 'models/profile.dart';
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
          return const _OnboardingPlaceholder();
        }
        return const TabShell();
      },
    );
  }
}

/// 2b 先起真正嘅 onboarding 三步流程（出生資料/MBTI/檔案卡）；
/// 呢度暫時得個殼，證明「冇 profile → 跳 onboarding」路由行得通。
class _OnboardingPlaceholder extends StatelessWidget {
  const _OnboardingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Onboarding — 2b 起')),
    );
  }
}

/// 主畫面：底部三個 tab（今日／我想做／月曆），2c/2d/2e 逐個補真內容。
/// Tabbar 視覺（跟 design html 精確配色/字體）留返 2c 開始起真 Tab A 嗰陣
/// 一併做——依家用 Material NavigationBar 佔位，證明路由/切換行得通。
class TabShell extends StatefulWidget {
  const TabShell({super.key});

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  int _index = 0;

  static const _tabs = [
    _TabInfo(icon: '☀', label: '今日', placeholder: 'Tab A — 2c 起'),
    _TabInfo(icon: '✦', label: '我想做', placeholder: 'Tab B — 2d 起'),
    _TabInfo(icon: '▦', label: '月曆', placeholder: 'Tab C — 2e 起'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (final tab in _tabs) Center(child: Text(tab.placeholder)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(icon: Text(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _TabInfo {
  final String icon;
  final String label;
  final String placeholder;
  const _TabInfo({
    required this.icon,
    required this.label,
    required this.placeholder,
  });
}
