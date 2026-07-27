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

    test('XuanLiColors.light 每個色都對正 design html 嘅 hex 值', () {
      expect(XuanLiColors.light.paper, const Color(0xFFF6EFE2));
      expect(XuanLiColors.light.paper2, const Color(0xFFEFE5D0));
      expect(XuanLiColors.light.cardSurface, const Color(0xFFFFFDF7));
      expect(XuanLiColors.light.ink, const Color(0xFF1C2440));
      expect(XuanLiColors.light.ink60, const Color(0x991C2440));
      expect(XuanLiColors.light.ink30, const Color(0x401C2440));
      expect(XuanLiColors.light.ink12, const Color(0x1F1C2440));
      expect(XuanLiColors.light.red, const Color(0xFFB23A3A));
      expect(XuanLiColors.light.gold, const Color(0xFFC9A24B));
      expect(XuanLiColors.light.jade, const Color(0xFF3F7D6E));
    });

    test('XuanLiColors.dark 每個色都對正 design html 嘅 hex 值', () {
      expect(XuanLiColors.dark.paper, const Color(0xFF131829));
      expect(XuanLiColors.dark.paper2, const Color(0xFF1C2440));
      expect(XuanLiColors.dark.cardSurface, const Color(0xFF1C2440));
      expect(XuanLiColors.dark.ink, const Color(0xFFE9DFC9));
      expect(XuanLiColors.dark.ink60, const Color(0x99E9DFC9));
      expect(XuanLiColors.dark.ink30, const Color(0x40E9DFC9));
      expect(XuanLiColors.dark.ink12, const Color(0x1FE9DFC9));
      expect(XuanLiColors.dark.red, const Color(0xFFE08484));
      expect(XuanLiColors.dark.gold, const Color(0xFFC9A24B));
      expect(XuanLiColors.dark.jade, const Color(0xFF7FC0AB));
    });
  });
}
