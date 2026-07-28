import 'package:flutter/material.dart';

import '../../engine/almanac.dart';
import '../../engine/annual_outlook.dart';
import '../../engine/day_reading_engine.dart';
import '../../engine/scoring.dart';
import '../../models/profile.dart';
import '../../services/calendar_sync.dart';
import '../../theme/xuanli_theme.dart';
import 'calendar_widgets.dart';

/// Tab C・月曆（spec §9.4）。[today] 冇畀就用今日（同 [TodayScreen]／
/// [ActivityScreen] 一樣嘅 UI-only「初始顯示邊個月/邊日」模式）。
class CalendarScreen extends StatefulWidget {
  final Profile profile;
  final DateTime? today;
  final DateTime? initialSelectedDate;

  const CalendarScreen({
    super.key,
    required this.profile,
    this.today,
    this.initialSelectedDate,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _weekdayHeaders = ['日', '一', '二', '三', '四', '五', '六'];
  static final _minMonth = DateTime(1900, 1);
  static final _maxMonth = DateTime(2100, 12);

  final _calendarSync = CalendarSyncService();

  /// [_loadMonthEvents] 專用嘅計數器，防止「撳快幾下（例如連續切換月
  /// 份）、後嗰個 request 先返嚟、之前嗰個先返嚟」out-of-order 情況
  /// 覆蓋咗新嘅結果。每次開始一個新 load 就加一；個 load 完成、準備
  /// setState 之前，再檢查吓個計數器係咪仲係自己出發嗰陣嘅數值——唔
  /// 係就代表中途有更新嘅月曆 load 出發咗，呢個已經過時，靜靜咁
  /// return 唔好 setState。同 [_dayLoadGeneration] 分開兩個獨立計數器
  /// （而唔係共用一個）：兩個 load method 寫嘅係完全唔相關嘅 state
  /// （呢個寫 [_daysWithEventsInDisplayedMonth]，另一個寫
  /// [_selectedDayEvents]），撳日只應該令舊嘅「撳日」request 過時，
  /// 唔應該連帶累到一個完全唔相關、仲 in-flight 嘅月曆 load 都被當
  /// 做過時（曾經用共用計數器試過，會令撳日之後、月曆 response 先返
  /// 到嗰種情況，個月嘅 event dots 靜靜咁唔顯示——見 code review）。
  int _monthLoadGeneration = 0;

  /// [_loadSelectedDayEvents] 專用嘅計數器，同 [_monthLoadGeneration]
  /// 分開嘅原因見嗰邊嘅註解——呢個淨係防止「連撳幾個唔同日」out-of-
  /// order 情況（撳日 5 未等到就撳日 10，日 5 個 response 遲過日 10
  /// 先返到，唔應該用日 5 個結果去蓋走已經顯示緊嘅日 10 資料），唔會
  /// 理會月曆 load 嗰邊出唔出發新 request。
  int _dayLoadGeneration = 0;

  late DateTime _displayedMonth;
  int? _selectedDay;
  bool _calendarAvailable = false;
  Set<int> _daysWithEventsInDisplayedMonth = {};
  List<CalendarSyncEvent> _selectedDayEvents = [];

  DateTime get _today {
    final t = widget.today;
    if (t != null) return t;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSelectedDate ?? _today;
    _displayedMonth = DateTime(initial.year, initial.month);
    _selectedDay = initial.day;
    _initCalendarSync();
  }

  /// spec §9.9：「首次入 Tab C 先問權限」。呢個先係整個畫面入面
  /// 唯一一次真係彈權限對話框嘅地方——之後 [_loadMonthEvents]／
  /// [_loadSelectedDayEvents] 淨係讀，唔會再問。
  Future<void> _initCalendarSync() async {
    final granted = await _calendarSync.requestPermission();
    if (!mounted) return;
    setState(() => _calendarAvailable = granted);
    if (!granted) return;
    await _loadMonthEvents();
    await _loadSelectedDayEvents();
  }

  Future<void> _loadMonthEvents() async {
    final generation = ++_monthLoadGeneration;
    final monthStart = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final monthEnd = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    final events = await _calendarSync.eventsInRange(start: monthStart, end: monthEnd);
    if (!mounted) return;
    if (generation != _monthLoadGeneration) return; // 過時 response，已經有新月曆 load 出發咗
    setState(() {
      _daysWithEventsInDisplayedMonth = events.map((e) => e.start.day).toSet();
    });
  }

  Future<void> _loadSelectedDayEvents() async {
    final generation = ++_dayLoadGeneration;
    final day = _selectedDay;
    if (day == null) {
      setState(() => _selectedDayEvents = []);
      return;
    }
    final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
    final events = await _calendarSync.eventsOnDay(date);
    if (!mounted) return;
    if (generation != _dayLoadGeneration) return; // 過時 response，已經有新日 load 出發咗
    setState(() => _selectedDayEvents = events);
  }

  bool get _showsToday =>
      _displayedMonth.year == _today.year && _displayedMonth.month == _today.month;

  void _changeMonth(int delta) {
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    if (next.isBefore(_minMonth) || next.isAfter(_maxMonth)) return;
    setState(() {
      _displayedMonth = next;
      _selectedDay = null;
      _daysWithEventsInDisplayedMonth = {};
      _selectedDayEvents = [];
    });
    if (_calendarAvailable) _loadMonthEvents();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingBlanks = DateTime(year, month, 1).weekday % 7;

    final userYearZhi = widget.profile.pillars[0].substring(1);
    final cells = [
      for (var d = 1; d <= daysInMonth; d++)
        _cellFor(
          DateTime(year, month, d),
          userYearZhi: userYearZhi,
          isToday: _showsToday && d == _today.day,
        ),
    ];

    final yearGanZhi = computeAnnualOutlook(
      date: _displayedMonth,
      userYearZhi: userYearZhi,
    ).yearGanZhi;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _changeMonth(-1),
                  child: Text('‹', style: TextStyle(fontSize: 20, color: colors.ink60)),
                ),
                Column(
                  children: [
                    Text(
                      '$year年$month月',
                      style: TextStyle(
                        fontFamily: XuanLiFonts.serif,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: 2,
                        color: colors.ink,
                      ),
                    ),
                    Text(
                      '$yearGanZhi年',
                      style: TextStyle(fontSize: 11, color: colors.ink60, letterSpacing: 1),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _changeMonth(1),
                  child: Text('›', style: TextStyle(fontSize: 20, color: colors.ink60)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final w in _weekdayHeaders)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: w == '日' ? colors.red : colors.ink60,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            CalendarGrid(
              leadingBlanks: leadingBlanks,
              days: cells,
              selectedDay: _selectedDay,
              onSelectDay: (d) {
                setState(() => _selectedDay = d);
                if (_calendarAvailable) _loadSelectedDayEvents();
              },
            ),
            if (_selectedDay != null) _buildDayCard(colors, DateTime(year, month, _selectedDay!)),
          ],
        ),
      ),
    );
  }

  CalendarCellData _cellFor(DateTime date, {required String userYearZhi, required bool isToday}) {
    final day = AlmanacDay.forDate(date);
    final band = computeFortuneScore(
      day: day,
      favorable: widget.profile.favorable,
      unfavorable: widget.profile.unfavorable,
      userYearZhi: userYearZhi,
    ).band;
    return CalendarCellData(
      day: date.day,
      lunarLabel: day.lunarLabel,
      band: band,
      isToday: isToday,
      hasEvents: _daysWithEventsInDisplayedMonth.contains(date.day),
    );
  }

  Widget _buildDayCard(XuanLiColors colors, DateTime date) {
    final reading = buildDayReading(profile: widget.profile, date: date);
    final weekdayChar = _weekdayHeaders[date.weekday % 7];
    final dateLabel = '${date.month}月${date.day}日（$weekdayChar）${reading.ganzhiDay}日';
    final subtitleLine = '${reading.lunarLabel}・${reading.zhiXing}日・${reading.chong}';

    return DayCard(
      dateLabel: dateLabel,
      band: reading.band,
      score: reading.fortuneScore,
      subtitleLine: subtitleLine,
      yiLine: reading.yi.map((e) => e.label).join('・'),
      jiLine: reading.ji.map((e) => e.label).join('・'),
      calendarAvailable: _calendarAvailable,
      eventLines: [
        for (final e in _selectedDayEvents.take(5)) e.displayLine,
      ],
    );
  }
}
