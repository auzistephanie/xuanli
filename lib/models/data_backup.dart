import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;

import 'profile.dart';
import 'settings.dart';

class BackupFormatException implements Exception {
  final String message;

  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

class XuanLiBackup {
  static const schemaVersion = 1;
  static const _elements = {'木', '火', '土', '金', '水'};
  static const _mbtiTypes = {
    'ISTJ', 'ISFJ', 'INFJ', 'INTJ', 'ISTP', 'ISFP', 'INFP', 'INTP',
    'ESTP', 'ESFP', 'ENFP', 'ENTP', 'ESTJ', 'ESFJ', 'ENFJ', 'ENTJ',
  };
  static const _dayMasters = {
    '甲木', '乙木', '丙火', '丁火', '戊土',
    '己土', '庚金', '辛金', '壬水', '癸水',
  };
  static const _zodiacs = {
    '鼠', '牛', '虎', '兔', '龍', '蛇', '馬', '羊', '猴', '雞', '狗', '豬',
  };

  final List<Profile> profiles;
  final AppSettings settings;
  final DateTime exportedAt;

  const XuanLiBackup({
    required this.profiles,
    required this.settings,
    required this.exportedAt,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'profiles': profiles.map((profile) => profile.toJson()).toList(),
        'settings': settings.toJson(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory XuanLiBackup.decode(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const BackupFormatException('檔案唔係有效 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException('備份最外層格式唔正確');
    }
    if (decoded['schemaVersion'] != schemaVersion) {
      throw const BackupFormatException('備份版本唔支援');
    }

    final exportedAtRaw = decoded['exportedAt'];
    final exportedAt = exportedAtRaw is String
        ? DateTime.tryParse(exportedAtRaw)
        : null;
    if (exportedAt == null) {
      throw const BackupFormatException('備份日期格式唔正確');
    }

    final profileList = decoded['profiles'];
    if (profileList is! List || profileList.isEmpty) {
      throw const BackupFormatException('備份冇有效命理檔案');
    }
    final profiles = <Profile>[];
    for (final value in profileList) {
      if (value is! Map<String, dynamic>) {
        throw const BackupFormatException('命理檔案格式唔正確');
      }
      profiles.add(_parseProfile(value));
    }

    final settingsJson = decoded['settings'];
    if (settingsJson is! Map<String, dynamic>) {
      throw const BackupFormatException('設定格式唔正確');
    }
    final settings = _parseSettings(settingsJson);
    return XuanLiBackup(
      profiles: profiles,
      settings: settings,
      exportedAt: exportedAt,
    );
  }

  static Profile _parseProfile(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw BackupFormatException('命理檔案欄位 $key 唔正確');
      }
      return value;
    }

    List<String> stringList(String key) {
      final value = json[key];
      if (value is! List || value.any((item) => item is! String)) {
        throw BackupFormatException('命理檔案欄位 $key 唔正確');
      }
      return List<String>.from(value);
    }

    final birthDateRaw = requiredString('birthDate');
    final birthDate = DateTime.tryParse(birthDateRaw);
    if (birthDate == null || birthDate.year < 1900 || birthDate.year > 2100) {
      throw const BackupFormatException('出生日期唔正確');
    }
    final birthHour = json['birthHour'];
    if (birthHour != null &&
        (birthHour is! int || birthHour < 0 || birthHour > 23)) {
      throw const BackupFormatException('出生時辰唔正確');
    }

    final mbti = requiredString('mbti');
    if (!_mbtiTypes.contains(mbti)) {
      throw const BackupFormatException('MBTI 類型唔正確');
    }
    final pillars = stringList('pillars');
    if (pillars.length != (birthHour == null ? 3 : 4) ||
        pillars.any((pillar) => pillar.length != 2)) {
      throw const BackupFormatException('八字資料唔完整');
    }

    final wuxingRaw = json['wuxing'];
    if (wuxingRaw is! Map || wuxingRaw.keys.toSet().difference(_elements).isNotEmpty) {
      throw const BackupFormatException('五行資料唔正確');
    }
    final wuxing = <String, int>{};
    for (final element in _elements) {
      final value = wuxingRaw[element];
      if (value is! int || value < 0 || value > 100) {
        throw const BackupFormatException('五行資料唔正確');
      }
      wuxing[element] = value;
    }
    if (wuxing.values.fold<int>(0, (sum, value) => sum + value) != 100) {
      throw const BackupFormatException('五行比例總和唔正確');
    }

    final favorable = stringList('favorable');
    final unfavorable = stringList('unfavorable');
    if (favorable.length != 2 ||
        unfavorable.length != 2 ||
        [...favorable, ...unfavorable].any((item) => !_elements.contains(item))) {
      throw const BackupFormatException('喜忌五行資料唔正確');
    }
    final dayMaster = requiredString('dayMaster');
    if (!_dayMasters.contains(dayMaster)) {
      throw const BackupFormatException('日主資料唔正確');
    }
    final zodiac = requiredString('zodiac');
    if (!_zodiacs.contains(zodiac)) {
      throw const BackupFormatException('生肖資料唔正確');
    }

    return Profile(
      id: requiredString('id'),
      name: requiredString('name'),
      birthDate: birthDate,
      birthHour: birthHour as int?,
      birthPlace: requiredString('birthPlace'),
      mbti: mbti,
      pillars: pillars,
      wuxing: wuxing,
      favorable: favorable,
      unfavorable: unfavorable,
      dayMaster: dayMaster,
      ziweiStar: requiredString('ziweiStar'),
      zodiac: zodiac,
    );
  }

  static AppSettings _parseSettings(Map<String, dynamic> json) {
    final themeName = json['themeMode'];
    final enabled = json['notificationsEnabled'];
    final hour = json['notificationHour'];
    final minute = json['notificationMinute'];
    if (themeName is! String ||
        !ThemeMode.values.any((mode) => mode.name == themeName) ||
        enabled is! bool ||
        hour is! int || hour < 0 || hour > 23 ||
        minute is! int || minute < 0 || minute > 59) {
      throw const BackupFormatException('設定內容唔正確');
    }
    return AppSettings(
      themeMode: ThemeMode.values.byName(themeName),
      notificationsEnabled: enabled,
      notificationHour: hour,
      notificationMinute: minute,
    );
  }
}
