import 'dart:convert';
import 'dart:io';

import 'package:lunar/lunar.dart';
import 'wuxing_tables.dart';
import '../models/day_reading.dart';

/// `lunar` package 用嚟表示「呢日冇吉神／冇凶煞」嘅 placeholder 字串
/// （`LunarUtil.getDayJiShen`／`getDayXiongSha` 喺搵唔到嘢嘅時候會塞呢個
/// 入去，唔係代表真係有一個叫「无」嘅神煞）。計數要撇除佢。
const _kNone = '无';

/// 一日嘅通勝資料，全部已經繁體化、deterministic（純 [date] 做 input）。
class AlmanacDay {
  final DateTime date;
  final String lunarLabel; // "五月廿七"
  final String ganzhiDay; // "丙戌"
  final String zhiXing; // 建除："平"
  final String chong; // "沖龍煞北"
  final List<String> yi;
  final List<String> ji;
  final int jiShenCount;
  final int xiongShaCount;
  final bool isJiSevere; // 忌：諸事不宜
  final bool isYiVague; // 宜含「諸事不宜」或「餘事勿取」（唔限於淨係得呢一項）

  AlmanacDay._({
    required this.date,
    required this.lunarLabel,
    required this.ganzhiDay,
    required this.zhiXing,
    required this.chong,
    required this.yi,
    required this.ji,
    required this.jiShenCount,
    required this.xiongShaCount,
    required this.isJiSevere,
    required this.isYiVague,
  });

  factory AlmanacDay.forDate(DateTime date) {
    final lunar = Solar.fromYmd(date.year, date.month, date.day).getLunar();

    final lunarLabel = '${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
    final ganzhiDay = lunar.getDayInGanZhi();
    final zhiXing = traditionalize(lunar.getZhiXing());

    // 沖／煞兩個字都係 `lunar` 回傳嘅簡體字（例如生肖「鸡」、方位「东」），
    // 兩個都要繁體化，唔淨止得沖生肖嗰個。
    final chongAnimal = traditionalize(lunar.getDayChongShengXiao());
    final sha = traditionalize(lunar.getDaySha());
    final chong = '沖$chongAnimal煞$sha';

    final yi = lunar.getDayYi().map(traditionalize).toList();
    final ji = lunar.getDayJi().map(traditionalize).toList();

    final jiShenRaw = lunar.getDayJiShen();
    final xiongShaRaw = lunar.getDayXiongSha();

    final isJiSevere = ji.contains('諸事不宜');
    final isYiVague =
        yi.isEmpty || yi.contains('諸事不宜') || yi.contains('餘事勿取');

    return AlmanacDay._(
      date: date,
      lunarLabel: lunarLabel,
      ganzhiDay: ganzhiDay,
      zhiXing: zhiXing,
      chong: chong,
      yi: yi,
      ji: ji,
      jiShenCount: jiShenRaw.where((e) => e != _kNone).length,
      xiongShaCount: xiongShaRaw.where((e) => e != _kNone).length,
      isJiSevere: isJiSevere,
      isYiVague: isYiVague,
    );
  }

  /// 日支（`ganzhiDay` 第二個字）
  String get dayZhi => ganzhiDay.substring(1);

  /// 日干（`ganzhiDay` 第一個字）
  String get dayGan => ganzhiDay.substring(0, 1);

  /// 宜項目個人化排序：類別五行 ∈ [favorable] 嘅排前面，取頭 5（spec §6.5）。
  List<YjItem> personalizedYi({required List<String> favorable}) {
    return _personalize(yi, favorable: favorable, maxCount: 5);
  }

  /// 忌項目個人化排序：邏輯同 [personalizedYi]，取頭 4（spec §6.5）。
  List<YjItem> personalizedJi({required List<String> favorable}) {
    return _personalize(ji, favorable: favorable, maxCount: 4);
  }

  List<YjItem> _personalize(
    List<String> items, {
    required List<String> favorable,
    required int maxCount,
  }) {
    final scored = items.map((label) {
      final element = activityCategoryWuxing[label];
      final matches = element != null && favorable.contains(element);
      return YjItem(label: label, matchesUser: matches);
    }).toList();
    // 用顯式 stable partition 代替 sort：List.sort 淨係喺細過 32 個元素先用
    // insertion sort（stable），大過就轉用非 stable 演算法，唔可以靠呢個
    // undocumented 行為嚟保住 matched/unmatched 兩組入面嘅原本次序。
    final matched = scored.where((item) => item.matchesUser).toList();
    final unmatched = scored.where((item) => !item.matchesUser).toList();
    final ordered = [...matched, ...unmatched];
    final take = maxCount > ordered.length ? ordered.length : maxCount;
    return ordered.sublist(0, take);
  }
}

/// 通勝關鍵字 → 五行親和，源自 `lib/data/activity_categories.json`（spec §7）。
final Map<String, String> activityCategoryWuxing = _loadActivityCategories();

Map<String, String> _loadActivityCategories() {
  final file = File('lib/data/activity_categories.json');
  final jsonMap = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  return jsonMap.map((k, v) => MapEntry(k, v as String));
}
