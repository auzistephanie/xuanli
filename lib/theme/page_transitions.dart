import 'package:flutter/material.dart';

/// Kairo 過場：新頁淡入＋由 96% 放大到 100%，舊頁輕微淡出。
/// 「減少動態效果」開咗就直接顯示，冇過場動畫。
class KairoPageTransitionsBuilder extends PageTransitionsBuilder {
  const KairoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn);
    return FadeTransition(
      opacity: inCurve,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(inCurve),
        child: FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.6).animate(outCurve),
          child: child,
        ),
      ),
    );
  }
}

const kairoPageTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.android: KairoPageTransitionsBuilder(),
  TargetPlatform.iOS: KairoPageTransitionsBuilder(),
  TargetPlatform.macOS: KairoPageTransitionsBuilder(),
  TargetPlatform.linux: KairoPageTransitionsBuilder(),
  TargetPlatform.windows: KairoPageTransitionsBuilder(),
  TargetPlatform.fuchsia: KairoPageTransitionsBuilder(),
});
