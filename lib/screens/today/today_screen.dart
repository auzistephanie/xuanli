import 'package:flutter/material.dart';

import '../../engine/daily_stick.dart';
import '../../engine/day_reading_engine.dart';
import '../../engine/lucky_colors.dart';
import '../../models/day_reading.dart';
import '../../models/profile.dart';
import '../../services/storage_service.dart';
import '../../theme/brand.dart';
import '../../theme/xuanli_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/orrery.dart';
import '../../widgets/starfield.dart';
import 'daily_stick_card.dart';
import 'today_widgets.dart';

/// Tab A・今日宜忌（spec §9.2）。[initialDate] 冇畀就用今日
/// （UI-only 決定「一開始顯示邊日」，唔係 scoring input 嗰種
/// `DateTime.now()`——一旦定咗 `_selectedDate`，之後全部計算都純
/// 靠嗰個日期，deterministic）。
class TodayScreen extends StatefulWidget {
  final Profile profile;
  final DateTime? initialDate;

  const TodayScreen({super.key, required this.profile, this.initialDate});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late DateTime _selectedDate = widget.initialDate ?? _today();

  final _storage = StorageService();
  bool _stickDrawnToday = false;

  @override
  void initState() {
    super.initState();
    _loadStickDrawn();
  }

  Future<void> _loadStickDrawn() async {
    try {
      final saved = await _storage.loadStickDrawnDate();
      final today = StorageService.stickDateKey(widget.initialDate ?? _today());
      if (mounted && saved == today) setState(() => _stickDrawnToday = true);
    } catch (_) {
      // 讀唔到就當今日未抽（platform channel 罕見故障唔應該令今日頁出事）。
    }
  }

  Future<void> _onStickDrawn(DateTime today) async {
    _stickDrawnToday = true;
    try {
      await _storage.saveStickDrawnDate(today);
    } catch (_) {
      // 存唔到最多係重開 app 要再搖一次，支籤本身 deterministic，唔會變。
    }
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final reading = buildDayReading(
      profile: widget.profile,
      date: _selectedDate,
    );
    final weekStart = widget.initialDate ?? _today();
    final isToday = _selectedDate == weekStart;
    final week = [
      for (var i = 0; i < 7; i++)
        buildDayReading(
          profile: widget.profile,
          date: weekStart.add(Duration(days: i)),
        ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        if (isDark) const Positioned.fill(child: Starfield()),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(colors, reading),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Orrery(
                        size: 240,
                        core: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${reading.fortuneScore}',
                              style: const TextStyle(
                                fontFamily: XuanLiFonts.serif,
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                color: KairoPalette.goldBright,
                                shadows: [
                                  Shadow(
                                    color: Color(0x99C9A24B),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '命理分・${reading.band}',
                              style: const TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.5,
                                color: KairoPalette.paper,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Column(
                          children: [
                            ScoreRing(
                              score: reading.mbtiScore,
                              ringColor: colors.jade,
                              label: '契合',
                              size: 70,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '狀態契合・${widget.profile.mbti}',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: colors.ink60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    YjColumn(
                      dotLabel: '宜',
                      title: '今日宜',
                      items: reading.yi,
                      isYi: true,
                    ),
                    const SizedBox(width: 12),
                    YjColumn(
                      dotLabel: '忌',
                      title: '今日忌',
                      items: reading.ji,
                      isYi: false,
                      extraNote: reading.avoidHour,
                    ),
                  ],
                ),
                AdviceCard(advice: reading.advice),
                const SizedBox(height: 12),
                _buildLuckyColors(colors),
                if (isToday)
                  DailyStickCard(
                    stick: drawDailyStick(
                      profile: widget.profile,
                      reading: reading,
                    ),
                    date: weekStart,
                    alreadyDrawn: _stickDrawnToday,
                    onDrawn: () => _onStickDrawn(weekStart),
                  ),
                const SizedBox(height: 14),
                Text(
                  '未來七日',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: colors.ink60,
                  ),
                ),
                const SizedBox(height: 8),
                Week7Strip(
                  readings: week,
                  selectedDate: _selectedDate,
                  onSelect: (d) => setState(() => _selectedDate = d),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLuckyColors(XuanLiColors colors) {
    final suggestions = luckyColorsForProfile(widget.profile);
    return Text(
      suggestions.isEmpty
          ? '五行配色參考：未有可用喜用神資料'
          : '五行配色參考：${suggestions.join('、')}（按個人喜用神；非每日運勢預測）',
      style: TextStyle(fontSize: 12, color: colors.ink60),
    );
  }

  Widget _buildHeader(XuanLiColors colors, DayReading reading) {
    final weekdayChar = _weekdayNames[_selectedDate.weekday - 1];
    return Row(
      children: [
        const BrandSeal(size: 30),
        const SizedBox(width: 8),
        const Wordmark(fontSize: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_selectedDate.month}月${_selectedDate.day}日 星期$weekdayChar',
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${reading.lunarLabel}・${reading.ganzhiDay}日・${reading.chong}',
                style: TextStyle(fontSize: 10.5, color: colors.ink60),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
