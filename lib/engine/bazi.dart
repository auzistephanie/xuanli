import 'package:lunar/lunar.dart';
import 'wuxing_tables.dart';

/// 農曆年月日（+閏月 flag）轉公曆 DateTime，畀 onboarding 農曆輸入用。
DateTime lunarToSolarDate({
  required int year,
  required int month,
  required int day,
  required bool isLeapMonth,
}) {
  final lunar = Lunar.fromYmd(year, isLeapMonth ? -month : month, day);
  final solar = lunar.getSolar();
  return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
}

/// 八字四柱、五行分佈、喜用神計算結果（spec §6.1）。
class BaziResult {
  final List<String> pillars; // 4 個（缺時辰得 3 個），["己卯","癸酉","乙亥","辛巳"]
  final Map<String, int> wuxingWeighted; // 未歸一嘅權重
  final Map<String, int> wuxing; // 歸一做百分比，總和 100
  final String dayMaster; // "乙木"
  final bool isBodyStrong; // 同黨 >= 45%
  final List<String> favorable; // 固定 2 個
  final List<String> unfavorable; // 固定 2 個

  BaziResult({
    required this.pillars,
    required this.wuxingWeighted,
    required this.wuxing,
    required this.dayMaster,
    required this.isBodyStrong,
    required this.favorable,
    required this.unfavorable,
  });
}

const List<String> _wuxingOrder = ['木', '火', '土', '金', '水'];

/// 計算四柱八字、五行分佈同喜用神。
///
/// [birthHour] 為 null 表示唔知時辰（三柱降級模式，用中午 12:00 做安全預設攞年月日）。
BaziResult computeBazi({
  required DateTime birthDate,
  int? birthHour, // null = 唔知時辰（三柱降級模式）
  int birthMinute = 0,
}) {
  // 冇時辰時用中午 12:00 做安全預設（遠離子時邊界），只攞年月日三柱。
  final hour = birthHour ?? 12;
  final solar = Solar.fromYmdHms(
      birthDate.year, birthDate.month, birthDate.day, hour, birthMinute, 0);
  final lunar = solar.getLunar();
  final eightChar = lunar.getEightChar();
  eightChar.setSect(1); // 晚子時日柱歸翌日流派，lunar 預設係流派 2，必須顯式設

  final fourPillars = [
    eightChar.getYear(),
    eightChar.getMonth(),
    eightChar.getDay(),
    eightChar.getTime(),
  ];
  final pillars = birthHour == null ? fourPillars.sublist(0, 3) : fourPillars;

  final dayGan = pillars[2].substring(0, 1);
  final dayMasterElement = ganWuxing[dayGan]!;
  final dayMaster = '$dayGan$dayMasterElement';

  final wuxingWeighted = _weightedWuxing(pillars);
  final wuxing = _normalizeToPercent(wuxingWeighted);

  final sameParty = _sameSideElements(dayMasterElement);
  final sameWeight =
      sameParty.fold<int>(0, (sum, el) => sum + (wuxingWeighted[el] ?? 0));
  final totalWeight = wuxingWeighted.values.fold<int>(0, (a, b) => a + b);
  final samePartyPercent = totalWeight == 0 ? 0 : sameWeight * 100 / totalWeight;
  final isBodyStrong = samePartyPercent >= 45;

  final List<String> favorable;
  final List<String> unfavorable;
  if (isBodyStrong) {
    // 身強：喜 = 剋日主(官殺) + 日主所生(食傷)；忌 = 生日主(印) + 同日主(比劫)
    favorable = [
      elementThatControls(dayMasterElement),
      elementGeneratedBy(dayMasterElement),
    ];
    unfavorable = [
      elementThatGenerates(dayMasterElement),
      dayMasterElement,
    ];
  } else {
    // 身弱：喜 = 生日主(印) + 同日主(比劫)；忌 = 剋日主(官殺) + 日主所剋(財)
    favorable = [
      elementThatGenerates(dayMasterElement),
      dayMasterElement,
    ];
    unfavorable = [
      elementThatControls(dayMasterElement),
      elementControlledBy(dayMasterElement),
    ];
  }

  return BaziResult(
    pillars: pillars,
    wuxingWeighted: wuxingWeighted,
    wuxing: wuxing,
    dayMaster: dayMaster,
    isBodyStrong: isBodyStrong,
    favorable: favorable,
    unfavorable: unfavorable,
  );
}

/// 同黨 = 生日主(印) + 同日主(比劫) 嘅五行
List<String> _sameSideElements(String dayMasterElement) {
  return [elementThatGenerates(dayMasterElement), dayMasterElement];
}

/// 逐柱計權重：天干 ×1、地支本氣 ×1，月支（pillars[1] 嘅地支）×2。
Map<String, int> _weightedWuxing(List<String> pillars) {
  final weighted = <String, int>{for (final e in _wuxingOrder) e: 0};
  for (var i = 0; i < pillars.length; i++) {
    final gan = pillars[i].substring(0, 1);
    final zhi = pillars[i].substring(1, 2);
    final isMonthPillar = i == 1;

    final ganElement = ganWuxing[gan]!;
    weighted[ganElement] = weighted[ganElement]! + 1;

    final zhiElement = zhiWuxing[zhi]!;
    weighted[zhiElement] = weighted[zhiElement]! + (isMonthPillar ? 2 : 1);
  }
  return weighted;
}

/// 四捨五入做百分比，殘差加喺權重最大嗰行（同分按 木火土金水 序）。
Map<String, int> _normalizeToPercent(Map<String, int> weighted) {
  final total = weighted.values.fold<int>(0, (a, b) => a + b);
  if (total == 0) return {for (final e in _wuxingOrder) e: 0};

  final rounded = <String, int>{};
  for (final e in _wuxingOrder) {
    rounded[e] = ((weighted[e]! * 100) / total).round();
  }
  final sum = rounded.values.fold<int>(0, (a, b) => a + b);
  final residual = 100 - sum;
  if (residual != 0) {
    final target =
        _wuxingOrder.reduce((a, b) => weighted[a]! >= weighted[b]! ? a : b);
    rounded[target] = rounded[target]! + residual;
  }
  return rounded;
}
