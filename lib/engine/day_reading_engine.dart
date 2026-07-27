import 'almanac.dart';
import 'copywriter.dart';
import 'scoring.dart';
import '../models/day_reading.dart';
import '../models/profile.dart';

/// 純函數：f(Profile, DateTime) -> DayReading。呢個係 spec §5 講嘅引擎總入口，
/// 淨係拼接返之前嘅 almanac/scoring/copywriter，唔加新邏輯。
DayReading buildDayReading({required Profile profile, required DateTime date}) {
  final day = AlmanacDay.forDate(date);
  final userYearZhi = profile.pillars[0].substring(1);

  final fortune = computeFortuneScore(
    day: day,
    favorable: profile.favorable,
    unfavorable: profile.unfavorable,
    userYearZhi: userYearZhi,
  );

  final mbtiScore = computeMbtiScore(
    day: day,
    mbti: profile.mbti,
    hasClash: fortune.clashWarning != null,
  );

  final userDayZhi = profile.pillars[2].substring(1);
  final avoidHour = computeAvoidHour(userDayZhi);

  final advice = buildAdvice(
    day: day,
    favorable: profile.favorable,
    unfavorable: profile.unfavorable,
    mbti: profile.mbti,
    ziweiStar: profile.ziweiStar,
    avoidHour: avoidHour,
  );

  return DayReading(
    date: date,
    ganzhiDay: day.ganzhiDay,
    lunarLabel: day.lunarLabel,
    zhiXing: day.zhiXing,
    chong: day.chong,
    fortuneScore: fortune.score,
    mbtiScore: mbtiScore,
    band: fortune.band,
    yi: day.personalizedYi(favorable: profile.favorable),
    ji: day.personalizedJi(favorable: profile.favorable),
    advice: advice,
    clashWarning: fortune.clashWarning,
    avoidHour: avoidHour,
  );
}
