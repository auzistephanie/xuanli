import 'package:app_links/app_links.dart';

/// 解析 app 冷啟動嗰陣嘅 launch URI（spec §9.6：撳 widget → deep link
/// `xuanli://day/2026-07-11`）。淨係處理冷啟動嗰刻嘅 link——app 已經
/// 開緊嗰陣先收到嘅新 link（`AppLinks().uriLinkStream`）呢個 plan
/// 未處理，係刻意嘅 follow-up（見 plan 文件嘅 scope decision #1）。
///
/// 任何唔啱嘅 URI（冇 link、唔啱 scheme/host、日期格式錯、platform
/// channel 冇 native implementation）一律靜靜返 null，唔會 throw——
/// 普通開 app（冇經 widget）本身就冇 link，同「有 link 但格式錯」／
/// 「平台完全冇實作」呢幾種情況對用戶嚟講應該一樣：跳去正常嘅今日
/// tab，冇分別。呢個設計原則同 `CalendarSyncService`／
/// `WidgetDataBridge`／`NotificationScheduler` 一致。
class DeepLinkRouter {
  final AppLinks _appLinks;

  // 呢個構造函數參數淨係為咗同其餘服務嘅 DI pattern 睇落一致
  // （cosmetic）——`AppLinks` 本身係 private constructor 嘅 true
  // singleton（`factory AppLinks() => _instance`），冇第二個可以傳入嘅
  // 實例可以用嚟測試。真正嘅 test seam 係 `AppLinksPlatform.instance`
  // （見 test 檔點做）。
  DeepLinkRouter({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  Future<DateTime?> getInitialDayLink() async {
    Uri? uri;
    try {
      uri = await _appLinks.getInitialLink();
    } catch (_) {
      // Platform channel 冇註冊 native implementation（呢個 repo 開發用嘅
      // Mac 冇 simulator/device 就係呢個情況，`flutter test` 環境本身都
      // 一樣）會拋 MissingPluginException——同 CalendarSyncService／
      // WidgetDataBridge 一致嘅 best-effort 處理：當「冇 link」一樣睇待，
      // 唔應該累到成個 app 冷啟動失敗。
      return null;
    }
    if (uri == null) return null;
    if (uri.scheme != 'xuanli' || uri.host != 'day') return null;
    if (uri.pathSegments.length != 1) return null;

    return _parseStrictDate(uri.pathSegments.first);
  }
}

/// [CalendarScreen] 自己嘅月曆導航範圍（`_minMonth`／`_maxMonth`）——
/// 呢度要同佢保持一致，唔可以放行呢個範圍以外嘅年份。見底下
/// `_parseStrictDate` 入面點解要喺呢一層攔截嘅解釋。
const _minValidYear = 1900;
const _maxValidYear = 2100;

/// 嚴格解析 "YYYY-MM-DD"。[DateTime.parse] 對超出範圍嘅月/日會自動
/// 進位而唔係拋 [FormatException]——例如 `"2026-13-45"` 會變成
/// `2027-02-14`，`"2026-02-30"` 會變成 `2026-03-02`——所以淨係 catch
/// FormatException 唔夠，會漏咗呢種「睇落似日期、實際上係亂數」嘅
/// input。呢度用兩步驗證：(1) 原字串要啱 regex 格式，(2) 用解析出嚟
/// 嘅 year/month/day 砌返一次 "YYYY-MM-DD" 字串，要同原字串完全一樣
/// ——如果唔一樣，即係話原字串本身已經進位咗，要當 malformed input
/// 處理，返 null，唔可以靜靜噉返個「啱啱好搭夠嘅錯日期」出去。
///
/// 仲有第三步：年份範圍檢查。上面 regex `^\d{4}-\d{2}-\d{2}$` 淨係
/// 保證「四位數字」，任何 0000-9999 嘅年都會 match——但
/// [CalendarScreen] 個月曆導航（`_changeMonth`）淨係接受
/// `[1900-01, 2100-12]` 呢個範圍，出咗呢個範圍就企硬唔畀再撳（兩個
/// 方向都係），變相係一條單程路：`initState()` 淨係用呢個 router
/// 嘅結果去 seed `_displayedMonth`，冇再做多一次範圍檢查。如果呢度
/// 冇攔截，一個 `xuanli://day/9999-01-01` 就會令個月曆一開波就停喺
/// 9999 年、然後兩邊都撳唔返出嚟——成個 app 裝住嗰段時間，月曆 tab
/// 永久壞咗，冇任何辦法喺 app 入面自己救返。呢個風險特別要喺呢一層
/// （而唔止响 [CalendarScreen] 度）攔截，係因為呢個 commit 將
/// `xuanli://` scheme 註冊咗做全機層面（`AndroidManifest.xml`／
/// `Info.plist`）——即係話唔止我哋自己嘅 widget 會發呢種 link，機
/// 入面隨便邊個第三方 app 都可以send一個呢種 URI 過嚟，呢個唔再係
/// 一個「內部自己控制得晒嘅 data source」，所以喺入口呢一層做嚴格
/// 防禦（而唔淨係靠 CalendarScreen 嗰邊嘅 UI 導航限制）先合理。
DateTime? _parseStrictDate(String input) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) return null;

  DateTime parsed;
  try {
    parsed = DateTime.parse(input);
  } on FormatException {
    return null;
  }

  final reconstructed = '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  if (reconstructed != input) return null;

  if (parsed.year < _minValidYear || parsed.year > _maxValidYear) return null;

  return parsed;
}
