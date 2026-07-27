import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  group('XuanLiTheme', () {
    test('light() 用淺色 paper 做背景，掛咗 XuanLiColors extension', () {
      final theme = XuanLiTheme.light();
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, XuanLiColors.light.paper);
      expect(theme.extension<XuanLiColors>(), XuanLiColors.light);
    });

    test('dark() 用深色 bg 做背景，掛咗深色 XuanLiColors extension', () {
      final theme = XuanLiTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, XuanLiColors.dark.paper);
      expect(theme.extension<XuanLiColors>(), XuanLiColors.dark);
    });

    test('XuanLiRadii tokens 同 spec §12 一致（卡16/格9/widget28）', () {
      expect(XuanLiRadii.card, 16.0);
      expect(XuanLiRadii.cell, 9.0);
      expect(XuanLiRadii.widget, 28.0);
    });
  });
}
