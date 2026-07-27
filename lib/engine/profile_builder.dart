import 'bazi.dart';
import 'wuxing_tables.dart';
import 'ziwei.dart';
import '../models/profile.dart';

/// 由出生資料 + MBTI 組成一個完整 [Profile]（spec §5/§6.1）——
/// 純函數，onboarding（2b）同 `tool/demo.dart` 共用呢個入口，
/// 唔好各自砌一份重複邏輯。
///
/// [birthHour] 為 null = 唔知時辰（三柱降級模式，見 [computeBazi]）。
Profile buildProfile({
  required String id,
  required String name,
  required DateTime birthDate,
  int? birthHour,
  int birthMinute = 0,
  required String birthPlace,
  required String mbti,
}) {
  final bazi = computeBazi(
    birthDate: birthDate,
    birthHour: birthHour,
    birthMinute: birthMinute,
  );
  final userYearZhi = bazi.pillars[0].substring(1);
  final userDayZhi = bazi.pillars[2].substring(1);

  return Profile(
    id: id,
    name: name,
    birthDate: birthDate,
    birthHour: birthHour,
    birthPlace: birthPlace,
    mbti: mbti,
    pillars: bazi.pillars,
    wuxing: bazi.wuxing,
    favorable: bazi.favorable,
    unfavorable: bazi.unfavorable,
    dayMaster: bazi.dayMaster,
    ziweiStar: ziweiStarForDayZhi(userDayZhi),
    zodiac: zhiToZodiac[userYearZhi]!,
  );
}
