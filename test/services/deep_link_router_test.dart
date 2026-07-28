import 'package:app_links_platform_interface/app_links_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/services/deep_link_router.dart';

/// 假嘅 [AppLinksPlatform]，直接控制 getInitialLink() 想要嘅 URI，
/// 唔使 mock 底層 MethodChannel（`AppLinksPlatform.instance` 本身
/// 就係一個特登開俾人 inject 嘅 static setter，呢個先係佢自己
/// 推薦嘅測試方式）。
class _FakeAppLinksPlatform extends AppLinksPlatform {
  final Uri? initialLink;
  _FakeAppLinksPlatform(this.initialLink);

  @override
  Future<Uri?> getInitialLink() async => initialLink;
}

void main() {
  // 起 test 之前捕捉住真實嘅預設 platform instance（`AppLinksMethodChannel`,
  // 未 mock 過任何 handler 嗰個），等每個 test 完咗都可以復原返去
  // ——原本嘅 tearDown（`instance = instance`）其實係一個 no-op，
  // 完全冇復原到任何嘢，會令下一個 test 執行嗰陣繼承咗上一個 test
  // 留低嘅 fake instance。「冇 platform channel implementation」嗰個
  // test group 需要真正嘅預設 instance（先會拋 MissingPluginException），
  // 所以呢度一併修好。
  final defaultAppLinksPlatform = AppLinksPlatform.instance;
  tearDown(() {
    AppLinksPlatform.instance = defaultAppLinksPlatform;
  });

  group('DeepLinkRouter.getInitialDayLink', () {
    test('冇 launch URI（一般開 app 嘅情況）→ null', () async {
      AppLinksPlatform.instance = _FakeAppLinksPlatform(null);
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });

    test('啱嘅 xuanli://day/2026-07-11 → DateTime(2026, 7, 11)', () async {
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('xuanli://day/2026-07-11'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), DateTime(2026, 7, 11));
    });

    test('其他 scheme 嘅 URI（例如普通 http link）→ null', () async {
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('https://example.com/day/2026-07-11'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });

    test('啱嘅 scheme 但 host 唔啱（唔係 "day"）→ null', () async {
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('xuanli://settings'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });

    test('path 唔係啱嘅日期格式 → null，唔會 throw', () async {
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('xuanli://day/not-a-date'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });

    test('多過一個 path segment → null', () async {
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('xuanli://day/2026-07-11/extra'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });

    test('超出範圍嘅月份（會被 DateTime.parse 靜靜進位）→ null，唔會' '返個進位咗嘅錯日期', () async {
      // DateTime.parse('2026-13-45') 會進位做 2027-02-14，唔會拋
      // FormatException——呢個 test 證明 _parseStrictDate 有攔到。
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('xuanli://day/2026-13-45'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });

    test('超出範圍嘅日子（例如 2 月 30 號）→ null，唔會返個進位咗嘅錯日期', () async {
      // DateTime.parse('2026-02-30') 會進位做 2026-03-02，唔會拋
      // FormatException——呢個 test 證明 _parseStrictDate 有攔到。
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('xuanli://day/2026-02-30'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });
  });

  group('DeepLinkRouter.getInitialDayLink — 冇 platform channel implementation（呢部 Mac 嘅真實情況）', () {
    test('getInitialLink() 拋 MissingPluginException 都唔會 throw，靜靜返 null', () async {
      // 冇特登 set AppLinksPlatform.instance——即係用返呢個測試環境
      // resolve 出嚟嘅真實/預設 platform interface，同 CalendarSyncService／
      // WidgetDataBridge 對應 test 一致：呢個 repo 開發用嘅 Mac 冇
      // simulator/device 註冊 native implementation，call
      // getInitialLink() 會拋 MissingPluginException。
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });
  });
}
