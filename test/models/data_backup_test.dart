import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/models/data_backup.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/models/settings.dart';

Profile sampleProfile({String id = 'p1'}) => Profile(
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
  final backup = XuanLiBackup(
    profiles: [sampleProfile(), sampleProfile(id: 'p2')],
    settings: const AppSettings(
      themeMode: ThemeMode.dark,
      notificationsEnabled: false,
      notificationHour: 8,
      notificationMinute: 15,
    ),
    exportedAt: DateTime.utc(2026, 8, 30, 2, 30),
  );

  test('encode/decode 保留完整 profiles list、settings 同 schema version', () {
    final encoded = backup.encode();
    final decoded = XuanLiBackup.decode(encoded);

    expect(jsonDecode(encoded)['schemaVersion'], 1);
    expect(decoded.profiles.map((profile) => profile.id), ['p1', 'p2']);
    expect(decoded.settings.themeMode, ThemeMode.dark);
    expect(decoded.settings.notificationsEnabled, isFalse);
    expect(decoded.settings.notificationHour, 8);
    expect(decoded.exportedAt, DateTime.utc(2026, 8, 30, 2, 30));
  });

  test('拒絕非 JSON、未知 schema、空 profiles', () {
    expect(() => XuanLiBackup.decode('not json'), throwsA(isA<BackupFormatException>()));

    final unknown = backup.toJson()..['schemaVersion'] = 99;
    expect(
      () => XuanLiBackup.decode(jsonEncode(unknown)),
      throwsA(isA<BackupFormatException>()),
    );

    final empty = backup.toJson()..['profiles'] = [];
    expect(
      () => XuanLiBackup.decode(jsonEncode(empty)),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('拒絕錯日期、MBTI、時辰、五行總和及 settings 範圍', () {
    Map<String, dynamic> mutatedProfile(String key, Object? value) {
      final map = jsonDecode(backup.encode()) as Map<String, dynamic>;
      (map['profiles'] as List).first[key] = value;
      return map;
    }

    for (final invalid in [
      mutatedProfile('birthDate', 'not-a-date'),
      mutatedProfile('mbti', 'XXXX'),
      mutatedProfile('birthHour', 24),
      mutatedProfile('wuxing', {'木': 100, '火': 14, '土': 13, '金': 15, '水': 28}),
    ]) {
      expect(
        () => XuanLiBackup.decode(jsonEncode(invalid)),
        throwsA(isA<BackupFormatException>()),
      );
    }

    final invalidSettings = backup.toJson();
    (invalidSettings['settings'] as Map<String, dynamic>)['notificationMinute'] = 60;
    expect(
      () => XuanLiBackup.decode(jsonEncode(invalidSettings)),
      throwsA(isA<BackupFormatException>()),
    );
  });
}
