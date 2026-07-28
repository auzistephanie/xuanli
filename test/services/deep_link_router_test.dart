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
  tearDown(() {
    AppLinksPlatform.instance = AppLinksPlatform.instance;
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
  });
}
