import 'package:flutter/material.dart';

/// 全局深色模式 state（spec §9.8：跟系統/常開/常關）。[XuanLiApp] 監聽
/// 呢個 value 嚟決定 `MaterialApp.themeMode`；[SettingsScreen] 改呢個
/// value 即刻全 app 生效，唔使重新 bootstrap。一個 module-level
/// singleton——呢個 app 淨係呢一個 cross-cutting value 需要咁做，冇必要
/// 因為佢一個引入成套 state management package。
final ValueNotifier<ThemeMode> themeModeController = ValueNotifier(ThemeMode.system);
