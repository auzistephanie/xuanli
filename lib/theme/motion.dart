// lib/theme/motion.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// 持續循環嘅「環境動畫」（天體儀轉、星閃、感應器傾斜）嘅總閘。
/// 一次性動畫（搖籤、翻卡、淡入）唔經呢度，照舊睇 `disableAnimations`。
/// 測試由 `test/flutter_test_config.dart` 關咗佢，否則 `pumpAndSettle` 會永遠等唔完。
class Motion {
  static bool ambientEnabled = true;

  static bool ambient(BuildContext context) =>
      ambientEnabled && !MediaQuery.of(context).disableAnimations;

  /// 陀螺儀／加速計：web 冇可靠權限流程，一律用拖動代替。
  static bool sensors(BuildContext context) => ambient(context) && !kIsWeb;
}
