import 'package:flutter/material.dart' show ThemeMode;

/// 用戶設定（spec §9.8）：深色模式跟隨方式、每朝通知開關/時間。
/// 同 [Profile] 一樣用 `shared_preferences` 存做 JSON string——見
/// `StorageService.loadSettings()`/`saveSettings()`。
///
/// [notificationHour]/[notificationMinute] 淨係「用戶想要嘅時間」呢個
/// 偏好本身；Phase 2g 唔會真係用呢兩個值去排通知（`flutter_local_
/// notifications` 嘅 `zonedSchedule` 屬於 Phase 3 先做嘅嘢），淨係存低
/// 畀 Phase 3 起嗰陣讀。
class AppSettings {
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final int notificationHour;
  final int notificationMinute;

  const AppSettings({
    required this.themeMode,
    required this.notificationsEnabled,
    required this.notificationHour,
    required this.notificationMinute,
  });

  /// 未存過任何設定時嘅預設值——spec §9.7 講嘅預設 07:30、通知預設開。
  static const defaults = AppSettings(
    themeMode: ThemeMode.system,
    notificationsEnabled: true,
    notificationHour: 7,
    notificationMinute: 30,
  );

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'notificationsEnabled': notificationsEnabled,
        'notificationHour': notificationHour,
        'notificationMinute': notificationMinute,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: ThemeMode.values.byName(json['themeMode'] as String),
        notificationsEnabled: json['notificationsEnabled'] as bool,
        notificationHour: json['notificationHour'] as int,
        notificationMinute: json['notificationMinute'] as int,
      );
}
