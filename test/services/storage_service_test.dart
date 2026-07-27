import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/models/profile.dart';
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
}
