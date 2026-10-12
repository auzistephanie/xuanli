import 'package:flutter/painting.dart';

/// 用家睇到嘅品牌名。內部識別（package／bundle ID／prefs key／備份格式／
/// 日曆識別碼「玄曆識別碼」）刻意保留 xuanli／玄曆，見 Kairo design spec D1。
const kBrandName = 'Kairo';
const kBrandSeal = '吉時';
const kBrandSealShort = '吉';

/// Kairo 裝飾色（唔入 XuanLiColors，因為深淺模式都一樣）。
class KairoPalette {
  static const night = Color(0xFF0D1120);
  static const night2 = Color(0xFF141A2E);
  static const navy = Color(0xFF1C2440);
  static const gold = Color(0xFFC9A24B);
  static const goldBright = Color(0xFFF0D78C);
  static const goldDeep = Color(0xFF8A6A28);
  static const jadeBright = Color(0xFF6FC3AD);
  static const sealRed = Color(0xFFB23A3A);
  static const paper = Color(0xFFE9DFC9);
}
