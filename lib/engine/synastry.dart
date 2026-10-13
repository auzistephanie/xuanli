import '../models/profile.dart';
import 'wuxing_tables.dart';

/// 兩人合盤（純 Dart、deterministic、零網絡、對稱：`(a,b)` 同 `(b,a)` 結果一樣）。
///
/// 分數**只由八字計**（日主五行、日支、喜用神互補）；MBTI 只影響文案，
/// 同 spec §6.3「命理分同 MBTI 契合度互相獨立」一致，亦因為 MBTI 配對冇可靠
/// 嘅量化基礎，唔應該入分數。
///
/// 安全線：文案一律講「點樣相處更順」，分數範圍 61–99，任何配對都唔會出現
/// 「唔夾」「唔配」呢類字眼。
enum StemRelation { same, generates, controls }

enum BranchRelation { combine, clash, same, none }

class SynastryResult {
  /// 合盤指數 61–99。
  final int score;
  final String scoreTitle;

  /// 四字關係名，由兩人日主五行配對決定（15 種）。
  final String name;
  final StemRelation stemRelation;
  final BranchRelation branchRelation;

  /// 喜用神互補：0 = 冇、1 = 單向、2 = 雙向。
  final int complement;
  final String elementA;
  final String elementB;
  final String description;
  final int mbtiShared;
  final String mbtiLabel;
  final String mbtiNote;

  /// 三條相處之道：日主、日支、MBTI 各一條。
  final List<String> tips;

  const SynastryResult({
    required this.score,
    required this.scoreTitle,
    required this.name,
    required this.stemRelation,
    required this.branchRelation,
    required this.complement,
    required this.elementA,
    required this.elementB,
    required this.description,
    required this.mbtiShared,
    required this.mbtiLabel,
    required this.mbtiNote,
    required this.tips,
  });

  /// 「水生木」「木土相剋」呢類一句講晒日主關係，畀 UI 顯示。
  String get stemRelationLabel {
    switch (stemRelation) {
      case StemRelation.same:
        return elementA == elementB ? '$elementA$elementB比和' : '比和';
      case StemRelation.generates:
        final giver = elementGeneratedBy(elementA) == elementB ? elementA : elementB;
        final receiver = giver == elementA ? elementB : elementA;
        return '$giver生$receiver・相生';
      case StemRelation.controls:
        final winner = elementControlledBy(elementA) == elementB ? elementA : elementB;
        final other = winner == elementA ? elementB : elementA;
        return '$winner剋$other・相剋';
    }
  }

  String get branchLabel {
    switch (branchRelation) {
      case BranchRelation.combine:
        return '日支相合';
      case BranchRelation.clash:
        return '日支相沖・有火花';
      case BranchRelation.same:
        return '日支同支';
      case BranchRelation.none:
        return '日支平穩';
    }
  }

  String get complementLabel {
    switch (complement) {
      case 2:
        return '五行互補';
      case 1:
        return '一邊補到';
      default:
        return '五行各自獨立';
    }
  }
}

const _elementOrder = ['木', '火', '土', '金', '水'];

const _combinePairs = {
  '子': '丑', '丑': '子', '寅': '亥', '亥': '寅', '卯': '戌', '戌': '卯',
  '辰': '酉', '酉': '辰', '巳': '申', '申': '巳', '午': '未', '未': '午',
};

/// 兩人日主五行配對（按 木火土金水 排序）→ 四字關係名。
const _pairNames = {
  '木木': '同林共蔭',
  '火火': '雙燈並明',
  '土土': '厚土同載',
  '金金': '雙劍合璧',
  '水水': '兩水同流',
  '木火': '木火通明',
  '火土': '火暖厚土',
  '土金': '土中藏金',
  '金水': '金水相涵',
  '木水': '水潤木榮',
  '木土': '木疏厚土',
  '土水': '土築水堤',
  '火水': '水火既濟',
  '火金': '火煉真金',
  '木金': '金削成器',
};

const _pairTexts = {
  '木木': '兩棵樹並排生長，根系纏埋一齊，風來一齊擋。你哋價值觀相近、步伐相似，一個起頭另一個就跟得上；要留意兩個都鍾意自己話事，大事不妨輪住揀。',
  '火火': '兩盞燈擺埋一齊，房間即刻光晒。你哋熱情、反應快，一個講笑另一個即刻接得上；唔好兩個同時燒得太旺，累咗就約好一齊歇下。',
  '土土': '兩片大地連埋一齊，穩陣得嚟好有承載力。你哋做事踏實、講信用，好似多咗個可靠嘅後盾；記得偶爾一齊試吓新嘢，唔好淨係守住舊習慣。',
  '金金': '兩把劍並排，鋒芒各有各，合作起上嚟效率驚人。你哋都有原則、講準繩，易互相欣賞；意見唔同嗰陣記住「對事唔對人」，就唔會越講越硬。',
  '水水': '兩條溪匯成一股，順流而下好自然。你哋心思細、易感應到對方情緒，唔講都明；不過要小心一齊諗太多，有時直接講出口，會好過各自猜。',
  '木火': '木生火，好似柴添火勢——一個提供養分，一個發光發亮。你哋合作起上嚟，點子同行動力自然接得上；付出多嗰位記得偶爾講出自己需要，被照亮嗰位記得講聲多謝。',
  '火土': '火生土，好似日頭曬暖大地。一個帶來熱度同動力，一個提供穩陣同承載；相處起上嚟互相安心，記得穩陣嗰位都需要被主動關心。',
  '土金': '土生金，好似礦脈藏喺泥土入面。一個默默支持，另一個因而發揮得更好；你哋適合長線一齊經營一件事，慢慢睇到成果。',
  '金水': '金生水，好似山泉由岩石之間流出。一個提供條理同方向，一個帶來靈活同智慧；溝通順暢、傾得深，偶爾都記得講下感受，唔好太理性。',
  '木水': '水生木，好似雨水滋潤樹苗。一個懂得滋養，一個懂得成長；相處之間互相成就，受滋養嗰位記得主動回饋，關係會更平衡。',
  '木土': '木剋土，樹根鬆開板結嘅泥土，其實係令大地更肥沃。一個推動改變，一個守住根基；起初步伐唔同，磨合好之後反而互補得好。',
  '土水': '土剋水，堤壩令河水有方向、唔再氾濫。一個提供界線同秩序，一個帶來流動同想法；講清楚底線，雙方都會更自在。',
  '火水': '水剋火，一冷一熱互相調節，古人叫「既濟」，意思係各自補足先成事。你哋性格對比明顯，但正正因為咁，先可以平衡對方嘅極端。',
  '火金': '火剋金，金要經過火煉先成器。一個要求高、激發潛力，一個肯受錘煉、愈煉愈強；用鼓勵代替批評，效果會好好多。',
  '木金': '金剋木，好似工匠修剪樹木，令佢成材。一個有要求有標準，一個有生命力；講明期望、尊重步伐，就可以一齊做出好作品。',
};

const _complementTexts = {
  2: '你需要嘅五行，對方身上有；對方需要嘅，你又有。呢種互補，係合盤入面最難得嘅一項。',
  1: '其中一方需要嘅五行，可以由對方補到。日常相處之中，總有一個位置係令另一個人安心嘅。',
  0: '你哋喺五行上各自獨立，唔會特別互補，亦唔會互相消耗；合拍程度靠日常相處同溝通培養。',
};

const _stemTips = {
  StemRelation.generates: '相生之中，一個付出多啲、一個受益多啲——記得輪流做付出嗰個，感謝要講出口。',
  StemRelation.same: '日主同五行，太似嘅人易各自為政；有事早啲講明邊個主導，就唔會撞車。',
  StemRelation.controls: '有張力先有成長：一個負責拆招、一個負責落地，分工講清楚，就唔會互相消耗。',
};

const _branchTips = {
  BranchRelation.combine: '日支相合，你哋有種自然嘅默契——多啲同行、少啲解釋，已經好夠。',
  BranchRelation.clash: '日支相沖，意見碰撞多啲，但亦代表有火花；大事之前先坐低傾，唔好喺氣頭上決定。',
  BranchRelation.same: '日支同支，生活節奏同習慣相近；留意兩個人嘅小毛病都好似，互相提醒一下。',
  BranchRelation.none: '日支唔特別合或沖，係最平穩嘅配置；相處靠日常用心，慢慢堆出默契。',
};

const _mbtiLabels = {
  4: '同頻共鳴',
  3: '相近相知',
  2: '同中有異',
  1: '互補搭檔',
  0: '鏡像對照',
};

const _mbtiNotes = {
  4: '你哋係同一型：好少要解釋自己，一個眼神就明。留意盲點都一樣，大決定記得聽多個第三者意見。',
  3: '只差一個字母：價值觀同做事方式好接近，仲有少少新鮮感可以互相學習。',
  2: '有一半相似、一半唔同：話題夠、唔會悶，亦有唔同角度可以補位。',
  1: '只得一個字母相同：你哋睇世界嘅方式差好遠，但正好補返對方嘅盲區——前提係互相好奇，唔好急住改變對方。',
  0: '四個字母全部相反：好似照鏡咁，見到另一個極端嘅自己。起初可能唔明對方點諗，一旦開始理解，會學到好多嘢。',
};

const _mbtiTips = {
  4: '同型人最易守住同一個盲點——有大決定，搵第三個人傾多句。',
  3: '差異雖然細，但最易被忽略；有分歧時問下「我哋差喺邊一點」，通常好快搵到答案。',
  2: '相似嘅部分令你哋有默契，唔同嘅部分就留畀對方發揮，分工唔使太硬。',
  1: '唔明對方嗰陣，先問「你係點諗㗎？」，再講自己睇法——好奇心比說服更有用。',
  0: '唔使急住令對方變返似自己；將對方嘅做法當成「另一套有效方法」，試吓先。',
};

SynastryResult computeSynastry(Profile a, Profile b) {
  final elementA = ganWuxing[_dayGan(a)]!;
  final elementB = ganWuxing[_dayGan(b)]!;
  final stem = _stemRelation(elementA, elementB);
  final branch = _branchRelation(_dayZhi(a), _dayZhi(b));
  final complement = _complementOf(a, b) + _complementOf(b, a);
  final shared = _sharedLetters(a.mbti, b.mbti);

  final score = _score(stem, branch, complement);
  final pairKey = _pairKey(elementA, elementB);

  return SynastryResult(
    score: score,
    scoreTitle: _scoreTitle(score),
    name: _pairNames[pairKey]!,
    stemRelation: stem,
    branchRelation: branch,
    complement: complement,
    elementA: elementA,
    elementB: elementB,
    description: '${_pairTexts[pairKey]!}${_complementTexts[complement]!}',
    mbtiShared: shared,
    mbtiLabel: _mbtiLabels[shared]!,
    mbtiNote: _mbtiNotes[shared]!,
    tips: [_stemTips[stem]!, _branchTips[branch]!, _mbtiTips[shared]!],
  );
}

// 日柱 = pillars[2]；`dayMaster` 係「乙木」呢類顯示字串，唔直接用佢查表。
String _dayGan(Profile p) => p.pillars[2].substring(0, 1);
String _dayZhi(Profile p) => p.pillars[2].substring(1);

StemRelation _stemRelation(String a, String b) {
  if (a == b) return StemRelation.same;
  if (elementGeneratedBy(a) == b || elementGeneratedBy(b) == a) {
    return StemRelation.generates;
  }
  return StemRelation.controls;
}

BranchRelation _branchRelation(String a, String b) {
  if (a == b) return BranchRelation.same;
  if (_combinePairs[a] == b) return BranchRelation.combine;
  if (zhiClash[a] == b) return BranchRelation.clash;
  return BranchRelation.none;
}

/// [from] 嘅喜用神入面，有冇一行係 [to] 嘅旺五行（佔比 ≥ 25%）。
int _complementOf(Profile from, Profile to) {
  final strong = {
    for (final e in _elementOrder)
      if ((to.wuxing[e] ?? 0) >= 25) e,
  };
  return from.favorable.any(strong.contains) ? 1 : 0;
}

int _sharedLetters(String a, String b) {
  var n = 0;
  for (var i = 0; i < 4; i++) {
    if (a[i] == b[i]) n++;
  }
  return n;
}

String _pairKey(String a, String b) {
  final i = _elementOrder.indexOf(a);
  final j = _elementOrder.indexOf(b);
  var key = i <= j ? '$a$b' : '$b$a';
  // 木水 係 水生木（保持 key 順序同 _pairNames 一致），金木 → 木金。
  if (key == '水木') key = '木水';
  if (key == '水火') key = '火水';
  if (key == '金火') key = '火金';
  return key;
}

int _score(StemRelation stem, BranchRelation branch, int complement) {
  const stemPoints = {
    StemRelation.generates: 20,
    StemRelation.same: 14,
    StemRelation.controls: 8,
  };
  const branchPoints = {
    BranchRelation.combine: 14,
    BranchRelation.same: 8,
    BranchRelation.none: 6,
    BranchRelation.clash: 4,
  };
  const complementPoints = {0: 3, 1: 12, 2: 20};
  final total = 46 + stemPoints[stem]! + branchPoints[branch]! + complementPoints[complement]!;
  return total > 99 ? 99 : total;
}

String _scoreTitle(int score) {
  if (score >= 90) return '天作之合';
  if (score >= 80) return '相得益彰';
  if (score >= 70) return '默契漸深';
  return '各有精彩';
}
