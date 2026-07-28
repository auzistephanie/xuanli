import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import '../models/settings.dart';

/// Profile 持久化（spec §5：`profiles: [Profile]`，MVP 淨係用 `profiles[0]`）。
/// 用 `shared_preferences` 存一個 JSON-encoded list string。
class StorageService {
  static const _profilesKey = 'xuanli_profiles';

  Future<List<Profile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null) return [];
    final list = json.decode(raw) as List;
    return list
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProfiles(List<Profile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, raw);
  }

  /// MVP 用戶入口：淨係讀/寫 `profiles[0]`。
  Future<Profile?> loadPrimaryProfile() async {
    final profiles = await loadProfiles();
    return profiles.isEmpty ? null : profiles.first;
  }

  /// MVP 用戶入口：覆蓋成個 profiles list 做淨係得一個 profile
  /// （未來多檔案支援 —— spec §2 決定 11 講嘅第二版功能 —— 先會有第二個）。
  Future<void> savePrimaryProfile(Profile profile) async {
    await saveProfiles([profile]);
  }

  static const _settingsKey = 'xuanli_settings';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return AppSettings.defaults;
    return AppSettings.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, json.encode(settings.toJson()));
  }

  /// 「重新做 Onboarding」用（spec §9.8）：清走已存嘅 profile，等
  /// [_AppBootstrap]／[SettingsScreen] 之後嘅 `loadPrimaryProfile()`
  /// 返回 null，跳返去 onboarding。唔清 settings（深色模式/通知偏好
  /// 呢啲同「你係邊個」冇關，用戶冇必要因為重做 onboarding 而丟失）。
  Future<void> clearProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profilesKey);
  }
}
