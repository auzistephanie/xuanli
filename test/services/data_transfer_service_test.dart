import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/models/data_backup.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/models/settings.dart';
import 'package:xuanli/services/data_transfer_service.dart';
import 'package:xuanli/services/storage_service.dart';

Profile profile(String id) => Profile(
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('export 交畀 share sheet 嘅係完整 backup JSON 同穩定檔名', () async {
    final storage = StorageService();
    await storage.saveProfiles([profile('p1'), profile('p2')]);
    await storage.saveSettings(const AppSettings(
      themeMode: ThemeMode.dark,
      notificationsEnabled: false,
      notificationHour: 8,
      notificationMinute: 15,
    ));
    Uint8List? sharedBytes;
    String? sharedName;
    final service = DataTransferService(
      storage: storage,
      share: (bytes, filename, origin) async {
        sharedBytes = bytes;
        sharedName = filename;
      },
    );

    await service.exportBackup(now: DateTime(2026, 8, 30));

    final decoded = XuanLiBackup.decode(utf8.decode(sharedBytes!));
    expect(decoded.profiles.length, 2);
    expect(decoded.settings.themeMode, ThemeMode.dark);
    expect(sharedName, 'xuanli-backup-20260830.json');
  });

  test('picker 取消返回 null；壞 JSON 拒絕而且完全唔改舊資料', () async {
    final storage = StorageService();
    await storage.savePrimaryProfile(profile('old'));
    await storage.saveSettings(AppSettings.defaults);

    final cancelled = DataTransferService(
      storage: storage,
      pick: () async => null,
    );
    expect(await cancelled.pickBackup(), isNull);

    final invalid = DataTransferService(
      storage: storage,
      pick: () async => Uint8List.fromList(utf8.encode('{bad')),
    );
    expect(invalid.pickBackup(), throwsA(isA<BackupFormatException>()));
    expect((await storage.loadPrimaryProfile())!.id, 'old');
    expect((await storage.loadSettings()).themeMode, ThemeMode.system);
  });

  test('有效 backup 確認 import 後一次過取代 profiles list 同 settings', () async {
    final storage = StorageService();
    await storage.savePrimaryProfile(profile('old'));
    final incoming = XuanLiBackup(
      profiles: [profile('new1'), profile('new2')],
      settings: const AppSettings(
        themeMode: ThemeMode.dark,
        notificationsEnabled: false,
        notificationHour: 9,
        notificationMinute: 45,
      ),
      exportedAt: DateTime.utc(2026, 8, 30),
    );
    final service = DataTransferService(
      storage: storage,
      pick: () async => Uint8List.fromList(utf8.encode(incoming.encode())),
    );

    final picked = await service.pickBackup();
    expect((await storage.loadPrimaryProfile())!.id, 'old');
    await service.importBackup(picked!);

    expect((await storage.loadProfiles()).map((item) => item.id), ['new1', 'new2']);
    expect((await storage.loadSettings()).themeMode, ThemeMode.dark);
  });
}
