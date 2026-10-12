import 'package:flutter/material.dart';

import '../../engine/daily_stick.dart';
import '../../engine/day_reading_engine.dart';
import '../../models/day_reading.dart';
import '../../models/profile.dart';
import '../../services/storage_service.dart';
import '../../theme/xuanli_theme.dart';
import '../../widgets/brand.dart';
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
    final reading = buildDayReading(profile: widget.profile, date: _selectedDate);
    final weekStart = widget.initialDate ?? _today();
    final isToday = _selectedDate == weekStart;
    final week = [
      for (var i = 0; i < 7; i++)
        buildDayReading(profile: widget.profile, date: weekStart.add(Duration(days: i))),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(colors, reading),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                border: Border.all(color: colors.ink12),
                borderRadius: BorderRadius.circular(XuanLiRadii.card),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ScoreRing(
                    score: reading.fortuneScore,
                    ringColor: colors.gold,
                    label: '命理分・${reading.band}',
                  ),
                  Container(width: 1, height: 76, color: colors.ink12),
                  ScoreRing(
                    score: reading.mbtiScore,
                    ringColor: colors.jade,
                    label: '狀態契合・${widget.profile.mbti}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                YjColumn(dotLabel: '宜', title: '今日宜', items: reading.yi, isYi: true),
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
            if (isToday)
              DailyStickCard(
                stick: drawDailyStick(profile: widget.profile, reading: reading),
                date: weekStart,
                alreadyDrawn: _stickDrawnToday,
                onDrawn: () => _onStickDrawn(weekStart),
              ),
            const SizedBox(height: 14),
            Text(
              '未來七日',
              style: TextStyle(fontSize: 11, letterSpacing: 2, color: colors.ink60),
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
    );
  }

  Widget _buildHeader(XuanLiColors colors, DayReading reading) {
    final weekdayChar = _weekdayNames[_selectedDate.weekday - 1];
    return Row(
      children: [
        const BrandSeal(size: 34),
        Expanded(
          child: Column(
            children: [
              Text(
                '${_selectedDate.month}月${_selectedDate.day}日 星期$weekdayChar',
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: 3,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${reading.lunarLabel}・${reading.ganzhiDay}日・${reading.chong}',
                style: TextStyle(fontSize: 11, color: colors.ink60, letterSpacing: 1),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('設定 — 2g 起')),
          ),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.ink30)),
            child: Icon(Icons.menu, size: 17, color: colors.ink60),
          ),
        ),
      ],
    );
  }
}
