import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/models/settings.dart';
import 'package:xuanli/services/storage_service.dart';

Profile _sampleProfile({String id = 'p1'}) => Profile(
      id: id,
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService', () {
    test('loadPrimaryProfile() 喺未存過任何嘢時返回 null', () async {
      final result = await StorageService().loadPrimaryProfile();
      expect(result, isNull);
    });

    test('savePrimaryProfile() 之後 loadPrimaryProfile() 攞返同一個 profile', () async {
      final service = StorageService();
      await service.savePrimaryProfile(_sampleProfile());

      final loaded = await service.loadPrimaryProfile();
      expect(loaded, isNotNull);
      expect(loaded!.id, 'p1');
      expect(loaded.name, '阿玄');
      expect(loaded.pillars, ['己卯', '癸酉', '乙亥', '辛巳']);
      expect(loaded.wuxing, {'木': 30, '火': 14, '土': 13, '金': 15, '水': 28});
    });

    test('savePrimaryProfile() 覆蓋舊 profile（MVP 淨係用 profiles[0]）', () async {
      final service = StorageService();
      await service.savePrimaryProfile(_sampleProfile(id: 'first'));
      await service.savePrimaryProfile(_sampleProfile(id: 'second'));

      final profiles = await service.loadProfiles();
      expect(profiles.length, 1);
      expect(profiles.first.id, 'second');
    });
  });

  group('StorageService — settings', () {
    test('loadSettings() 喺未存過時返回 AppSettings.defaults（跟系統・通知開・07:30）', () async {
      final result = await StorageService().loadSettings();
      expect(result.themeMode, ThemeMode.system);
      expect(result.notificationsEnabled, isTrue);
      expect(result.notificationHour, 7);
      expect(result.notificationMinute, 30);
    });

    test('saveSettings() 之後 loadSettings() 攞返同一組設定', () async {
      final service = StorageService();
      await service.saveSettings(const AppSettings(
        themeMode: ThemeMode.dark,
        notificationsEnabled: false,
        notificationHour: 22,
        notificationMinute: 15,
      ));

      final loaded = await service.loadSettings();
      expect(loaded.themeMode, ThemeMode.dark);
      expect(loaded.notificationsEnabled, isFalse);
      expect(loaded.notificationHour, 22);
      expect(loaded.notificationMinute, 15);
    });

    test('copyWith() 淨係改指定欄位，其餘保留', () async {
      const original = AppSettings(
        themeMode: ThemeMode.system,
        notificationsEnabled: true,
        notificationHour: 7,
        notificationMinute: 30,
      );
      final updated = original.copyWith(themeMode: ThemeMode.light);
      expect(updated.themeMode, ThemeMode.light);
      expect(updated.notificationsEnabled, isTrue);
      expect(updated.notificationHour, 7);
      expect(updated.notificationMinute, 30);
    });
  });

  group('StorageService — clearProfiles', () {
    test('clearProfiles() 之後 loadPrimaryProfile() 返回 null', () async {
      final service = StorageService();
      await service.savePrimaryProfile(_sampleProfile());
      expect(await service.loadPrimaryProfile(), isNotNull);

      await service.clearProfiles();
      expect(await service.loadPrimaryProfile(), isNull);
    });
  });
}
