import 'package:flutter/material.dart';

/// 玄曆設計 tokens（spec §12 + design/design-preview.html 嘅 :root CSS 變量）。
/// 淺色/深色各一份 const 實例，掛喺 [ThemeData.extensions] 度，畫面用
/// `Theme.of(context).extension<XuanLiColors>()!` 攞（`!` 安全，因為
/// [XuanLiTheme.light]/[XuanLiTheme.dark] 一定會掛呢個 extension）。
@immutable
class XuanLiColors extends ThemeExtension<XuanLiColors> {
  final Color paper;
  final Color paper2;
  final Color cardSurface;
  final Color ink;
  final Color ink60;
  final Color ink30;
  final Color ink12;
  final Color red;
  final Color gold;
  final Color jade;

  const XuanLiColors({
    required this.paper,
    required this.paper2,
    required this.cardSurface,
    required this.ink,
    required this.ink60,
    required this.ink30,
    required this.ink12,
    required this.red,
    required this.gold,
    required this.jade,
  });

  static const light = XuanLiColors(
    paper: Color(0xFFF6EFE2),
    paper2: Color(0xFFEFE5D0),
    cardSurface: Color(0xFFFFFDF7), // design html `.card` background
    ink: Color(0xFF1C2440),
    ink60: Color(0x991C2440),
    ink30: Color(0x401C2440),
    ink12: Color(0x1F1C2440),
    red: Color(0xFFB23A3A),
    gold: Color(0xFFC9A24B),
    jade: Color(0xFF3F7D6E),
  );

  static const dark = XuanLiColors(
    paper: Color(0xFF131829), // design html --d-bg
    paper2: Color(0xFF1C2440), // design html --d-card
    cardSurface: Color(0xFF1C2440),
    ink: Color(0xFFE9DFC9), // design html --d-paper (text colour in dark mode)
    ink60: Color(0x99E9DFC9),
    ink30: Color(0x40E9DFC9),
    ink12: Color(0x1FE9DFC9),
    red: Color(0xFFE08484), // design html dark-mode 忌 colour
    gold: Color(0xFFC9A24B),
    jade: Color(0xFF7FC0AB), // design html dark-mode 宜 colour
  );

  @override
  XuanLiColors copyWith({
    Color? paper,
    Color? paper2,
    Color? cardSurface,
    Color? ink,
    Color? ink60,
    Color? ink30,
    Color? ink12,
    Color? red,
    Color? gold,
    Color? jade,
  }) {
    return XuanLiColors(
      paper: paper ?? this.paper,
      paper2: paper2 ?? this.paper2,
      cardSurface: cardSurface ?? this.cardSurface,
      ink: ink ?? this.ink,
      ink60: ink60 ?? this.ink60,
      ink30: ink30 ?? this.ink30,
      ink12: ink12 ?? this.ink12,
      red: red ?? this.red,
      gold: gold ?? this.gold,
      jade: jade ?? this.jade,
    );
  }

  @override
  XuanLiColors lerp(ThemeExtension<XuanLiColors>? other, double t) {
    if (other is! XuanLiColors) return this;
    return XuanLiColors(
      paper: Color.lerp(paper, other.paper, t)!,
      paper2: Color.lerp(paper2, other.paper2, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink60: Color.lerp(ink60, other.ink60, t)!,
      ink30: Color.lerp(ink30, other.ink30, t)!,
      ink12: Color.lerp(ink12, other.ink12, t)!,
      red: Color.lerp(red, other.red, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      jade: Color.lerp(jade, other.jade, t)!,
    );
  }
}

/// 圓角 tokens（spec §12：卡 16 / 格 9 / widget 28）。
class XuanLiRadii {
  static const card = 16.0;
  static const cell = 9.0;
  static const widget = 28.0;
}

/// 字體 family 名（要同 pubspec.yaml 嘅 `fonts:` 段 family 名一致）。
class XuanLiFonts {
  /// 標題／數字／干支（design html `.serif` class）。
  static const serif = 'NotoSerifTC';

  /// 正文（design html body 預設字體）。
  static const sans = 'NotoSansTC';
}

class XuanLiTheme {
  static ThemeData light() => _build(XuanLiColors.light, Brightness.light);
  static ThemeData dark() => _build(XuanLiColors.dark, Brightness.dark);

  static ThemeData _build(XuanLiColors colors, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.ink,
      brightness: brightness,
      primary: colors.ink,
      secondary: colors.gold,
      error: colors.red,
      surface: colors.paper,
    );

    final base = ThemeData(brightness: brightness);
    final textTheme = base.textTheme
        .apply(
          fontFamily: XuanLiFonts.sans,
          bodyColor: colors.ink,
          displayColor: colors.ink,
        )
        .copyWith(
          headlineMedium: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
          headlineSmall: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
          titleLarge: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.paper,
      fontFamily: XuanLiFonts.sans,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: colors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(XuanLiRadii.card),
        ),
        elevation: 0,
      ),
      extensions: [colors],
    );
  }
}
