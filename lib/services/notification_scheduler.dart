import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../engine/copywriter.dart';
import '../engine/day_reading_engine.dart';
import '../models/profile.dart';
import '../models/settings.dart';

/// 排未來 7 日嘅每朝通知（spec §9.7）。設計原則同 `WidgetDataBridge`
/// （Phase 3a）一致：純 Dart 嘅文案計算行喺 try/catch 外面（一個真
/// bug 應該可以喺開發環境睇到，唔應該靜靜俾 platform-channel 嘅
/// try/catch 一齊吞埋）；淨係 platform 互動（timezone 偵測/init/
/// cancel/zonedSchedule）先 best-effort 咁被 catch。
class NotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin;

  // `FlutterLocalNotificationsPlugin()` 本身係一個 factory 包住嘅
  // singleton（唔似 device_calendar 嘅 DeviceCalendarPlugin，每次
  // `FlutterLocalNotificationsPlugin()` 都係攞返同一個 instance），
  // 所以呢度隨便 construct 都安全，同 CalendarSyncService/
  // WidgetDataBridge 一樣嘅 DI-for-testability pattern。
  NotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'xuanli_daily';
  static const _channelName = '每朝通知';
  static const _channelDescription = '每朝一句今日通勝提示（spec §9.7）';

  /// day-offset (0-6) 對應嘅固定 notification id——每次 refresh 都會
  /// 先 cancel 晒呢 7 個 id 先，等重複 refresh（每次開 app 都會做，
  /// spec §9.7）唔會累積重複通知，用戶拒絕/停用通知之後嗰次 refresh
  /// 亦都會正確清走舊排程。
  static int _idFor(int dayOffset) => 1000 + dayOffset;

  bool _timezoneReady = false;

  /// 攞裝置真實 IANA timezone 嚟 setLocalLocation，令 zonedSchedule
  /// 排嘅時間先啱用戶本身嘅牆鐘時間（唔似 Phase 2h 個全日 calendar
  /// event write——嗰度 plain UTC 已經啱，係因為 device_calendar 自己
  /// 內部有一步 host-local 重新解讀邏輯；呢度冇類似機制，錯咗
  /// timezone 就真係會響錯鐘）。偵測唔到就維持 package 預設
  /// （UTC）——呢個唔係「好過冇」嘅選擇：響錯鐘（例如香港用戶
  /// 07:30 嘅提示變咗 15:30 先響，其他 timezone 甚至可能更誇張）
  /// 客觀嚟講比完全冇響更差。維持 UTC 純粹係因為有更高優先嘅原則
  /// 要守——「platform-channel 失敗絕對唔可以累到成個 background
  /// refresh 爆晒」（同 Phase 3a 定嘅設計原則一致）——先揀呢個
  /// imperfect-but-running 嘅妥協，唔係話呢個 tradeoff 本身係好嘢。
  Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // 見上面段註解：維持 UTC 預設，唔好因為呢步失敗累到成個
      // refresh 爆晒。
    }
    _timezoneReady = true;
  }

  Future<void> _ensureInitialized() async {
    await _ensureTimezone();
    // TODO(phase3b, 上真機前一定要換): Android 通知小圖示淨係睇 alpha
    // channel，`ic_launcher` 呢個全彩、冇透明度嘅 app icon 唔啱用（好
    // 大機會顯示做一嚿白色方塊），真機測試前一定要換做一個淨色剪影嘅
    // 專用 notification icon asset。
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  /// [today] 得意 test 用嚟固定「而家」係邊一日——冇畀就用返
  /// `DateTime.now()`（同 `WidgetDataBridge.refreshNext7Days` 一致
  /// 嘅慣例）。
  Future<void> refreshNext7Days({
    required Profile profile,
    required AppSettings settings,
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);

    // 純 Dart 計算行喺 try/catch 外面：一個 buildDayReading/
    // buildNotificationText 嘅真 bug 應該可以喺開發/測試環境俾人
    // 發現，唔應該同下面 platform-channel 嘅 expected failure
    // 一齊被靜靜吞咗。
    final texts = [
      for (var i = 0; i < 7; i++)
        buildNotificationText(buildDayReading(profile: profile, date: startDate.add(Duration(days: i)))),
    ];

    try {
      await _ensureInitialized();

      for (var i = 0; i < 7; i++) {
        await _plugin.cancel(_idFor(i));
      }

      if (!settings.notificationsEnabled) return;

      final nowTz = tz.TZDateTime.now(tz.local);
      for (var i = 0; i < 7; i++) {
        final day = startDate.add(Duration(days: i));
        final scheduled = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          settings.notificationHour,
          settings.notificationMinute,
        );
        if (!scheduled.isAfter(nowTz)) continue;

        await _plugin.zonedSchedule(
          _idFor(i),
          '玄曆',
          texts[i],
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      // Best-effort：同 WidgetDataBridge 一致嘅哲學——用戶可能未批
      // 通知權限，或者部機 platform channel 未 ready，呢啲都唔應該
      // 累到成個 app 開唔到。
    }
  }
}
