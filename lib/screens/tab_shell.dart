import 'package:flutter/material.dart';

import '../models/profile.dart';

/// 主畫面：底部三個 tab（今日／我想做／月曆），2c/2d/2e 逐個補真內容。
/// Tabbar 視覺（跟 design html 精確配色/字體）留返 2c 開始起真 Tab A 嗰陣
/// 一併做——依家用 Material NavigationBar 佔位，證明路由/切換行得通。
class TabShell extends StatefulWidget {
  final Profile profile;

  const TabShell({super.key, required this.profile});

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
