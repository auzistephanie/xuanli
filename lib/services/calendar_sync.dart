import 'package:device_calendar/device_calendar.dart';

/// 一個日曆事件嘅精簡顯示資料（時間+標題）。Tab B「當日行程」／Tab C
/// 日卡共用呢個型別；原始 [Event]（device_calendar 嘅型別）唔直接
/// 外露畀 UI，減少 screen 層對 device_calendar package 嘅耦合。
class CalendarSyncEvent {
  final String title;
  final DateTime start;

  const CalendarSyncEvent({required this.title, required this.start});

  /// 格式化做 "HH:mm 標題"，Tab B「當日行程」dialog／Tab C 日卡列表
  /// 共用（同 [eventsOnDay] 一樣嘅 DRY 原則——顯示格式亦只應該有一份）。
  String get displayLine {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(start.hour)}:${two(start.minute)} $title';
  }
}

/// 包裝 device_calendar 嘅權限/讀/寫（spec §9.9）。設計原則：就算冇
/// 權限、冇日曆、或者部機根本冇 platform channel implementation（呢個
/// repo 開發用嘅 Mac 冇 simulator/device，`flutter test` 環境本身就係
/// 呢個情況），都唔會 throw——一律靜靜返 false/[]，等 UI 決定點顯示
/// （Tab C 拒絕權限＝整個行程功能靜默隱藏，唔嘈）。
class CalendarSyncService {
  final DeviceCalendarPlugin _plugin;

  CalendarSyncService({DeviceCalendarPlugin? plugin})
      : _plugin = plugin ?? DeviceCalendarPlugin();

  /// 淨係查詢現有權限狀態，唔會彈系統權限對話框——畀 Tab C 每次
  /// 讀月曆/揀日都用嘅「靜默檢查」，唔應該重複問用戶。
  Future<bool> hasPermission() async {
    final result = await _plugin.hasPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  /// 主動問用戶攞權限（已經有就唔會再彈）。呢個先應該喺明確嘅用戶
  /// 動作／畫面首次進入嗰陣觸發（Tab C 首次入、Tab B 撳加入日曆），
  /// 唔好周圍隨便 call。
  Future<bool> requestPermission() async {
    if (await hasPermission()) return true;
    final result = await _plugin.requestPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  Future<String?> _defaultWritableCalendarId() async {
    final result = await _plugin.retrieveCalendars();
    if (!result.isSuccess || result.data == null) return null;

    final writable = result.data!.where((c) => c.isReadOnly != true).toList();
    if (writable.isEmpty) return null;

    for (final calendar in writable) {
      if (calendar.isDefault == true) return calendar.id;
    }
    return writable.first.id;
  }

  /// 建一個全日 event（spec §9.9 寫：Tab B 加入日曆）。冇權限會先問
  /// 一次；用戶拒絕，或者部機根本冇任何可寫日曆，就返 false，等
  /// 呼叫方（畫面）顯示合適提示。
  ///
  /// [date] 淨係用嚟起 [TZDateTime] 嘅年月日欄位；[Event.allDay]=true
  /// 嗰陣 device_calendar 自己（`assertParameters`）會攞呢啲年月日
  /// 欄位、用 host 機器嘅系統 local time 重新起一個 UTC instant 先
  /// 傳去 platform channel——即係話：淨係嗰個 y/m/d 數值本身有意義，
  /// 用邊個 [Location] 起呢個 [TZDateTime]（呢度用 [UTC] 純粹貪方便）
  /// 對最終傳出去嘅 epoch 完全冇影響（`TZDateTime.from(other, loc)`
  /// 係 instant-preserving，`loc` 淨係影響之後讀 `.year`/`.month`/
  /// `.day` getter 用邊個 offset 顯示，唔會改變已經算好嘅 UTC
  /// instant）。呢個 UTC instant 代表緊「呢部裝住 app 嘅機噚下自己個
  /// local time 嘅午夜」——即係話喺真機（app 同睇返個 calendar 都係
  /// 同一部機、同一個 timezone）度睇，個 event 一定啱啱好落喺用戶
  /// 想要嗰一日，唔使額外處理。（起呢個 plan 嗰陣一開始以為要額外
  /// 起個 fixed-offset `Location`先啱，落手做嗰陣先發現係諗錯咗
  /// `TZDateTime.from` 嘅語義——已經用返呢個簡單版本。）
  ///
  /// 補充：以上講嘅「host-local 重新起 instant」淨係 non-Android 個
  /// code path 先係咁；Android 度 device_calendar 行緊另一條更直接嘅
  /// path——`TZDateTime.utc(event.start!.year, .month, .day, 0, 0, 0)`，
  /// 直接攞 input 已經有嗰組 y/m/d 做 passthrough，完全冇 host-local
  /// 重新解讀呢一步。結論（同一部機睇一定係啱嗰日）兩邊平台都成立，
  /// 但係經兩條唔同機制達成，唔好誤會呢段註解係講緊 platform-agnostic
  /// 嘅單一邏輯。
  Future<bool> addAllDayEvent({
    required DateTime date,
    required String title,
    required String description,
  }) async {
    if (!await requestPermission()) return false;

    final calendarId = await _defaultWritableCalendarId();
    if (calendarId == null) return false;

    final day = TZDateTime(UTC, date.year, date.month, date.day);
    final event = Event(
      calendarId,
      title: title,
      description: description,
      start: day,
      end: day,
      allDay: true,
    );

    final result = await _plugin.createOrUpdateEvent(event);
    return result != null && result.isSuccess;
  }

  /// 讀返 `[start, end)` 範圍入面、用戶全部日曆合埋一齊嘅 events，
  /// 跨 calendar 合併＋按開始時間排序。冇權限就靜靜返 []（唔會嘗試
  /// 彈權限對話框——權限請求由畫面自己喺首次進入嗰陣觸發一次，呢個
  /// method 只讀唔問）。
  Future<List<CalendarSyncEvent>> eventsInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!await hasPermission()) return [];

    final calendarsResult = await _plugin.retrieveCalendars();
    if (!calendarsResult.isSuccess || calendarsResult.data == null) return [];

    final events = <CalendarSyncEvent>[];
    for (final calendar in calendarsResult.data!) {
      if (calendar.id == null) continue;
      final eventsResult = await _plugin.retrieveEvents(
        calendar.id,
        RetrieveEventsParams(startDate: start, endDate: end),
      );
      if (!eventsResult.isSuccess || eventsResult.data == null) continue;

      for (final event in eventsResult.data!) {
        if (event.start == null || event.title == null) continue;
        events.add(CalendarSyncEvent(title: event.title!, start: event.start!));
      }
    }

    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  /// [eventsInRange] 嘅單日方便版本——Tab B「當日行程」／Tab C 日卡
  /// 共用（DRY：兩邊都係「畀我呢一日嘅 events」，唔應該各自寫一份）。
  Future<List<CalendarSyncEvent>> eventsOnDay(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    return eventsInRange(
      start: dayStart,
      end: dayStart.add(const Duration(days: 1)),
    );
  }
}
