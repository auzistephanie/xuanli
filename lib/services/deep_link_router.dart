import 'package:app_links/app_links.dart';

/// 解析 app 冷啟動嗰陣嘅 launch URI（spec §9.6：撳 widget → deep link
/// `xuanli://day/2026-07-11`）。淨係處理冷啟動嗰刻嘅 link——app 已經
/// 開緊嗰陣先收到嘅新 link（`AppLinks().uriLinkStream`）呢個 plan
/// 未處理，係刻意嘅 follow-up（見 plan 文件嘅 scope decision #1）。
///
/// 任何唔啱嘅 URI（冇 link、唔啱 scheme/host、日期格式錯）一律靜靜
/// 返 null，唔會 throw——普通開 app（冇經 widget）本身就冇 link，
/// 同「有 link 但格式錯」呢兩種情況對用戶嚟講應該一樣：跳去正常嘅
/// 今日 tab，冇分別。
class DeepLinkRouter {
  final AppLinks _appLinks;

  DeepLinkRouter({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  Future<DateTime?> getInitialDayLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri == null) return null;
    if (uri.scheme != 'xuanli' || uri.host != 'day') return null;
    if (uri.pathSegments.length != 1) return null;

    try {
      return DateTime.parse(uri.pathSegments.first);
    } on FormatException {
      return null;
    }
  }
}
