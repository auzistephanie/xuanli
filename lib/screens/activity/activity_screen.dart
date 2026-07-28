import 'package:flutter/material.dart';

import '../../engine/activity.dart';
import '../../engine/almanac.dart';
import '../../engine/copywriter.dart';
import '../../engine/scoring.dart';
import '../../models/profile.dart';
import '../../services/calendar_sync.dart';
import '../../theme/xuanli_theme.dart';
import '../onboarding/onboarding_widgets.dart' show OnboardingSegmentedToggle;
import 'activity_widgets.dart';

/// Tab B・我想做…（反向擇日，spec §9.3）。[today] 冇畀就用今日
/// （同 [TodayScreen] 一樣嘅 UI-only「初始顯示邊日」模式，唔係
/// scoring input 嗰種 `DateTime.now()`）。
class ActivityScreen extends StatefulWidget {
  final Profile profile;
  final DateTime? today;

  const ActivityScreen({super.key, required this.profile, this.today});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _RangeOption {
  final String label;
  final int days;
  const _RangeOption(this.label, this.days);
}

const _rangeOptions = [
  _RangeOption('未來一週', 7),
  _RangeOption('未來一個月', 30),
  _RangeOption('三個月', 90),
];

class _ActivityScreenState extends State<ActivityScreen> {
  final _calendarSync = CalendarSyncService();

  late String _selectedActivity = loadActivities().first.name;
  int _rangeIndex = 1; // 未來一個月

  static const _weekdayChars = ['一', '二', '三', '四', '五', '六', '日'];

  DateTime get _today {
    final t = widget.today;
    if (t != null) return t;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int _fortuneScoreOf(DateTime date) {
    final userYearZhi = widget.profile.pillars[0].substring(1);
    return computeFortuneScore(
      day: AlmanacDay.forDate(date),
      favorable: widget.profile.favorable,
      unfavorable: widget.profile.unfavorable,
      userYearZhi: userYearZhi,
    ).score;
  }

  Future<void> _addToCalendar({
    required Activity activity,
    required DateTime date,
    required String reason,
  }) async {
    final added = await _calendarSync.addAllDayEvent(
      date: date,
      title: '${activity.name}（玄曆吉日）',
      description: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added ? '已加入你嘅日曆 ✓' : '需要日曆權限先可以加入 — 請去手機設定開返'),
    ));
  }

  Future<void> _showDaySchedule(DateTime date, String dateLabel) async {
    final events = await _calendarSync.eventsOnDay(date);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$dateLabel 嘅行程'),
        content: events.isEmpty
            ? const Text('呢日冇搵到行程（或者未開日曆權限）')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in events)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${e.start.hour.toString().padLeft(2, '0')}:'
                          '${e.start.minute.toString().padLeft(2, '0')} ${e.title}',
                        ),
                      ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道喇'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final rangeDays = _rangeOptions[_rangeIndex].days;
    final dates = [
      for (var i = 0; i < rangeDays; i++) _today.add(Duration(days: i)),
    ];
    final activity =
        loadActivities().firstWhere((a) => a.name == _selectedActivity);
    final results = rankActivities(
      activityName: _selectedActivity,
      dates: dates,
      favorable: widget.profile.favorable,
      fortuneScoreOf: _fortuneScoreOf,
    );
    final avoided = _findFirstAvoidedDay(activity: activity, dates: dates);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: colors.red, borderRadius: BorderRadius.circular(7)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('玄',
                          style: TextStyle(
                              color: colors.paper,
                              fontFamily: XuanLiFonts.serif,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              height: 1.1)),
                      Text('曆',
                          style: TextStyle(
                              color: colors.paper,
                              fontFamily: XuanLiFonts.serif,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              height: 1.1)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '我想做⋯',
                  style: TextStyle(
                    fontFamily: XuanLiFonts.serif,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: 3,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final a in loadActivities())
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ActivityChip(
                        label: a.name,
                        selected: a.name == _selectedActivity,
                        onTap: () => setState(() => _selectedActivity = a.name),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OnboardingSegmentedToggle(
              options: [for (final r in _rangeOptions) r.label],
              selectedIndex: _rangeIndex,
              onChanged: (i) => setState(() => _rangeIndex = i),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < results.length; i++)
              _buildResultCard(colors, activity, results[i],
                  showCalendarActions: i == 0),
            if (avoided != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${avoided.$1.month}月${avoided.$1.day}日（${avoided.$2}）通勝忌'
                  '${activity.avoidKeywords.first}，已為你避開 ✓',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: colors.ink30),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
    XuanLiColors colors,
    Activity activity,
    ActivityDayResult result, {
    required bool showCalendarActions,
  }) {
    final day = AlmanacDay.forDate(result.date);
    final weekdayChar = _weekdayChars[result.date.weekday - 1];
    final dateLabel =
        '${result.date.month}月${result.date.day}日（$weekdayChar）${day.ganzhiDay}日';
    final subtitleLine = '${day.lunarLabel}・${day.zhiXing}日・${day.chong}';
    final reason = buildActivityReason(
      activity: activity,
      day: day,
      favorable: widget.profile.favorable,
    );

    return ResultCard(
      dateLabel: dateLabel,
      stars: result.stars,
      subtitleLine: subtitleLine,
      reason: reason,
      showCalendarActions: showCalendarActions,
      onAddToCalendar: showCalendarActions
          ? () => _addToCalendar(activity: activity, date: result.date, reason: reason)
          : null,
      onViewSchedule: showCalendarActions
          ? () => _showDaySchedule(result.date, dateLabel)
          : null,
    );
  }

  /// 搵範圍入面第一個因為忌關鍵字命中而俾淘汰嘅日子（spec §7 安全線：
  /// 淘汰邏輯本身已經喺 [scoreActivityForDay] 度，呢度淨係用返公開
  /// 嘅 engine function 掃一次搵嚟做「已為你避開」信任文案，冇重複
  /// 邏輯）。搵唔到就 null（例如「睇醫生」冇 avoidKeywords，永遠搵唔到）。
  /// 淨係喺頭 [_avoidedDayScanWindow] 日度搵例子，唔會掃成個
  /// 已揀範圍（三個月＝90日）——「已為你避開 XX」呢句淨係想畀用戶
  /// 一個具體例子建立信心，唔使窮盡成個範圍先搵到；一個貼近今日
  /// 嘅例子對用戶仲更相關。呢個上限本身亦順便解決咗一個真實嘅
  /// performance 問題：`rankActivities()` 本身已經行過一次
  /// `AlmanacDay.forDate`/`scoreActivityForDay`，冇上限嘅版本會
  /// 喺三個月範圍度成 90 日行多一次，量度過喺 rebuild 度會逼近甚至
  /// 超過一個 frame budget。
  static const _avoidedDayScanWindow = 14;

  (DateTime, String)? _findFirstAvoidedDay({
    required Activity activity,
    required List<DateTime> dates,
  }) {
    if (activity.avoidKeywords.isEmpty) return null;
    for (final date in dates.take(_avoidedDayScanWindow)) {
      final day = AlmanacDay.forDate(date);
      final score = scoreActivityForDay(
        activity: activity,
        day: day,
        favorable: widget.profile.favorable,
        fortuneScore: _fortuneScoreOf(date),
      );
      if (score == null) return (date, day.ganzhiDay);
    }
    return null;
  }
}
