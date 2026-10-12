import 'dart:convert';

import '../models/day_reading.dart';
import '../models/profile.dart';

/// 每日一籤（純 Dart、deterministic、零網絡）。
///
/// 籤級跟今日「命理分」走，令籤同今日宜忌唔會互相矛盾；籤號同籤詩由
/// （日期＋用戶四柱＋MBTI）嘅穩定 hash 揀，所以**同一個人同一日永遠抽到同一支**
/// （重開 app、重抽都一樣），唔同人／唔同日子就唔同。冇用 `Random`、冇用 `DateTime.now()`。
///
/// 安全線：冇「凶」「下下籤」；最低一級叫「守靜籤」，只講宜靜不宜動；
/// 籤詩唔提醫療、投資、生死。
enum StickLevel { supreme, good, middle, small, quiet }

class DailyStick {
  /// 1–60。
  final int number;
  final StickLevel level;

  /// 四句七言籤詩。
  final List<String> verse;

  /// 解曰：籤意＋今日干支同合適嘅宜。
  final String interpretation;

  const DailyStick({
    required this.number,
    required this.level,
    required this.verse,
    required this.interpretation,
  });

  String get numberLabel => stickNumberLabel(number);
  String get levelName => stickLevelName(level);
}

DailyStick drawDailyStick({required Profile profile, required DayReading reading}) {
  final level = _levelFor(reading.fortuneScore);
  final d = reading.date;
  final seed = _fnv1a(
    '${d.year}-${d.month}-${d.day}|${profile.pillars.join()}|${profile.mbti}',
  );
  final verses = stickVerses[level]!;
  return DailyStick(
    number: seed % 60 + 1,
    level: level,
    verse: verses[(seed >> 8) % verses.length],
    interpretation: _interpretation(level, reading),
  );
}

StickLevel _levelFor(int score) {
  if (score >= 85) return StickLevel.supreme;
  if (score >= 70) return StickLevel.good;
  if (score >= 55) return StickLevel.middle;
  if (score >= 40) return StickLevel.small;
  return StickLevel.quiet;
}

String stickLevelName(StickLevel level) {
  switch (level) {
    case StickLevel.supreme:
      return '上上籤';
    case StickLevel.good:
      return '上吉籤';
    case StickLevel.middle:
      return '中吉籤';
    case StickLevel.small:
      return '小吉籤';
    case StickLevel.quiet:
      return '守靜籤';
  }
}

const _digits = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

/// 1–60 → 「第三十七籤」。
String stickNumberLabel(int n) {
  assert(n >= 1 && n <= 99);
  final tens = n ~/ 10;
  final ones = n % 10;
  final String zh;
  if (tens == 0) {
    zh = _digits[ones];
  } else {
    zh = '${tens == 1 ? '' : _digits[tens]}十${_digits[ones]}';
  }
  return '第$zh籤';
}

// FNV-1a 32-bit：簡單、穩定、跨平台一致（Dart 整數喺 web 係 double，所以每步 mask 住 32 位）。
int _fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(s)) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

const _levelLines = {
  StickLevel.supreme: '萬事順遂之象，想做嘅事主動啲，會有回響。',
  StickLevel.good: '順風順水之象，跟住計劃行就有收成。',
  StickLevel.middle: '平穩向好之象，做好本分，福氣慢慢到。',
  StickLevel.small: '先慢後順之象，小事細心，大事唔使急。',
  StickLevel.quiet: '宜靜不宜動之象，今日養好精神，大計留返聽日。',
};

// 通勝「宜」入面唔適合放喺籤文入面講嘅項目。
const _skipYi = {'餘事勿取', '諸事不宜', '安葬', '破屋', '壞垣', '入殮', '成服', '除服', '移柩', '啟鑽'};

String _interpretation(StickLevel level, DayReading reading) {
  final usable = reading.yi.where((y) => !_skipYi.contains(y.label)).toList();
  YjItem? pick;
  for (final y in usable) {
    if (y.matchesUser) {
      pick = y;
      break;
    }
  }
  pick ??= usable.isEmpty ? null : usable.first;
  final today = pick == null
      ? '今日${reading.ganzhiDay}日，宜靜守。'
      : '今日${reading.ganzhiDay}日，宜${pick.label}。';
  return '${_levelLines[level]!}$today';
}

/// 籤詩庫：每級 4 首七言絕句（原創）。
const stickVerses = <StickLevel, List<List<String>>>{
  StickLevel.supreme: [
    ['春風入戶燕歸來', '萬里雲開見曉台', '心事不須頻問卜', '良辰已向手中栽'],
    ['東風送暖柳條新', '舊事輕風散作塵', '今日開懷宜遠望', '前程自有貴人親'],
    ['明月當空照碧天', '清光所至事皆圓', '莫將遲疑耽良會', '一步向前勝十年'],
    ['紅日初升萬象蘇', '山河錦繡展新圖', '心誠自有天相助', '事到臨頭自不孤'],
  ],
  StickLevel.good: [
    ['溪流遇石轉彎行', '細水長流事亦成', '莫道今朝無大喜', '默默耕耘待月明'],
    ['柳暗花明又一村', '行行重行向前門', '有人相助無須怯', '一點誠心勝萬言'],
    ['雲開霧散見青山', '路上行人漸漸閒', '所求雖緩終須至', '何妨徐步看花間'],
    ['鴻雁南飛信有期', '好音將至莫遲疑', '靜心守候三分近', '此去逢人皆是師'],
  ],
  StickLevel.middle: [
    ['一葉扁舟水上行', '風平浪靜自分明', '莫貪高處爭先渡', '穩穩前行亦到程'],
    ['秋來葉落見根深', '守拙存誠即是金', '不羨他人花滿路', '自家門前亦有春'],
    ['暮鼓晨鐘各有時', '莫將得失苦相思', '今朝但把本分盡', '明日花開自可知'],
    ['小橋流水人家近', '炊煙裊裊暖心頭', '平凡日子平凡福', '一盞清茶解百憂'],
  ],
  StickLevel.small: [
    ['薄霧輕籠半遮山', '且待陽光出雲間', '事有緩急宜細察', '莫因小事亂心安'],
    ['細雨潤物不聞聲', '慢慢滋長自分明', '今日少言多做事', '水到渠成事有成'],
    ['孤燈夜讀自安然', '一點微光亦可傳', '莫嫌今日風頭小', '靜守時機待後天'],
    ['秋水無痕映晚霞', '靜觀雲影漸西斜', '今朝不必爭先後', '留得心清勝繁華'],
  ],
  StickLevel.quiet: [
    ['山深林靜鳥歸巢', '一日清閒勝萬朝', '莫向風前爭意氣', '且將心事付松濤'],
    ['閉門讀字養心田', '一盞清茶度此天', '大事不妨明日論', '今朝先把倦身眠'],
    ['潮退灘空月更明', '靜觀沙岸不爭行', '待得來朝風向轉', '再揚帆影過前程'],
    ['寒梅未放暗香藏', '且守初心莫急忙', '雪後春來花自發', '靜時蓄力待春芳'],
  ],
};
