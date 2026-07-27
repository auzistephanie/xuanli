import 'package:flutter/services.dart' show rootBundle;

import '../engine/almanac.dart';
import '../engine/activity.dart';
import '../engine/copywriter.dart';
import '../models/combo.dart';

/// 喺 app 啟動時 call 一次：由 `rootBundle` 讀返 4 個 JSON asset，
/// 餵落 `lib/engine`/`lib/models` 嘅 init*() cache。冇 call 過呢個
/// function 之前，`loadActivities()`／`loadCombos()`／宜忌個人化排序／
/// 貼身建議文案 全部會 throw `StateError`。
Future<void> loadEngineData() async {
  final results = await Future.wait([
    rootBundle.loadString('lib/data/activities.json'),
    rootBundle.loadString('lib/data/activity_categories.json'),
    rootBundle.loadString('lib/data/combos.json'),
    rootBundle.loadString('lib/data/mbti_tones.json'),
  ]);

  initActivities(results[0]);
  initActivityCategories(results[1]);
  initCombos(results[2]);
  initMbtiTones(results[3]);
}
