import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../theme/xuanli_theme.dart';

/// 主畫面：底部三個 tab（今日／我想做／月曆）。Tabbar 樣式跟
/// design/design-preview.html 嘅 `.tabbar` 精確配色：選中用朱紅+粗體，
/// 未選中用淡墨，頂部一條幼線分隔，冇 Material ripple/預設高亮。
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
      bottomNavigationBar: _TabBar(
        selectedIndex: _index,
        tabs: _tabs,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int selectedIndex;
  final List<_TabInfo> tabs;
  final ValueChanged<int> onSelect;

  const _TabBar({
    required this.selectedIndex,
    required this.tabs,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.cardSurface.withValues(alpha: 0.85),
        border: Border(top: BorderSide(color: colors.ink12)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 22),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  behavior: HitTestBehavior.opaque,
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    label: tabs[i].label,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tabs[i].icon,
                          style: TextStyle(
                            fontSize: 19,
                            color: i == selectedIndex ? colors.red : colors.ink60,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tabs[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w400,
                            color: i == selectedIndex ? colors.red : colors.ink60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
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
