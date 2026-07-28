import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../engine/day_reading_engine.dart';
import '../models/profile.dart';

/// 一日份、畀原生 widget render 用嘅精簡資料（spec §9.6：命理分/band/
/// 日期農曆/宜3忌2/避時），淨係包 [DayReading] 入面 widget 真係會顯示
/// 嘅欄位——advice/mbtiScore/clashWarning 呢啲 widget 冇顯示，唔會
/// 序列化，keep 個 JSON 細（widget 儲存空間有限）。
class WidgetDayPayload {
  final DateTime date;
  final String ganzhiDay;
  final String lunarLabel;
  final int fortuneScore;
  final String band;
  final List<String> yi;
  final List<String> ji;
  final String? avoidHour;

  const WidgetDayPayload({
    required this.date,
    required this.ganzhiDay,
    required this.lunarLabel,
    required this.fortuneScore,
    required this.band,
    required this.yi,
    required this.ji,
    required this.avoidHour,
  });

  /// 日期用 "yyyy-MM-dd"——同 spec §9.6 deep link 格式一致
  /// （`xuanli://day/2026-07-11`），原生 widget 撳落去可以直接攞嚟拼 URI。
  Map<String, dynamic> toJson() => {
        'date':
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'ganzhiDay': ganzhiDay,
        'lunarLabel': lunarLabel,
        'fortuneScore': fortuneScore,
        'band': band,
        'yi': yi,
        'ji': ji,
        'avoidHour': avoidHour,
      };
}

/// 橋接 engine 同原生 home-screen widget（spec §9.6）。用 [HomeWidget]
/// package 寫入未來 7 日 [WidgetDayPayload] JSON。設計原則同
/// `CalendarSyncService`（Phase 2h）一致：淨係 best-effort background
/// refresh，就算 platform channel 冇註冊 implementation（呢個 plan
/// 未起native widget extension，本身就係而家嘅現實）都唔會 throw，
/// 唔應該因為呢個背景刷新失敗而累到成個 app 開唔到。
class WidgetDataBridge {
  static const _dataKey = 'xuanli_week_readings';

  // TODO(phase3b, 需要 Xcode/Android Studio 先起到 native widget):
  // 呢兩個名淨係 placeholder，要等真係起咗 iOS WidgetKit extension／
  // Android AppWidgetProvider 之後，改做嗰邊實際嘅 class/kind 名。
  static const _iOSWidgetName = 'XuanLiWidget';
  static const _androidWidgetName = 'XuanLiWidgetProvider';

  Future<void> refreshNext7Days(Profile profile, {DateTime? today}) async {
    try {
      final start = today ?? DateTime.now();
      final startDate = DateTime(start.year, start.month, start.day);
      final payloads = [
        for (var i = 0; i < 7; i++) _payloadFor(profile, startDate.add(Duration(days: i))),
      ];
      final jsonStr = json.encode(payloads.map((p) => p.toJson()).toList());

      await HomeWidget.saveWidgetData<String>(_dataKey, jsonStr);
      await HomeWidget.updateWidget(
        iOSName: _iOSWidgetName,
        androidName: _androidWidgetName,
      );
    } catch (_) {
      // Best-effort：native widget extension 未起（或者用戶部機冇 pin
      // 個 widget），呢個背景刷新失敗唔應該影響 app 其餘功能。
    }
  }

  WidgetDayPayload _payloadFor(Profile profile, DateTime date) {
    final reading = buildDayReading(profile: profile, date: date);
    return WidgetDayPayload(
      date: reading.date,
      ganzhiDay: reading.ganzhiDay,
      lunarLabel: reading.lunarLabel,
      fortuneScore: reading.fortuneScore,
      band: reading.band,
      yi: reading.yi.take(3).map((e) => e.label).toList(),
      ji: reading.ji.take(2).map((e) => e.label).toList(),
      avoidHour: reading.avoidHour,
    );
  }
}
