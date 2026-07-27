/// 天干 → 五行
const Map<String, String> ganWuxing = {
  '甲': '木', '乙': '木',
  '丙': '火', '丁': '火',
  '戊': '土', '己': '土',
  '庚': '金', '辛': '金',
  '壬': '水', '癸': '水',
};

/// 地支 → 本氣五行
const Map<String, String> zhiWuxing = {
  '子': '水', '丑': '土', '寅': '木', '卯': '木',
  '辰': '土', '巳': '火', '午': '火', '未': '土',
  '申': '金', '酉': '金', '戌': '土', '亥': '水',
};

/// 地支六沖（子午/丑未/寅申/卯酉/辰戌/巳亥）
const Map<String, String> zhiClash = {
  '子': '午', '午': '子',
  '丑': '未', '未': '丑',
  '寅': '申', '申': '寅',
  '卯': '酉', '酉': '卯',
  '辰': '戌', '戌': '辰',
  '巳': '亥', '亥': '巳',
};

const Map<String, String> _generates = {
  '木': '火', '火': '土', '土': '金', '金': '水', '水': '木',
};
const Map<String, String> _controls = {
  '木': '土', '土': '水', '水': '火', '火': '金', '金': '木',
};

/// 邊行生咗 [element]（印星）
String elementThatGenerates(String element) {
  return _generates.entries.firstWhere((e) => e.value == element).key;
}

/// 邊行剋咗 [element]（官殺）
String elementThatControls(String element) {
  return _controls.entries.firstWhere((e) => e.value == element).key;
}

/// [element] 生邊行（食傷）
String elementGeneratedBy(String element) => _generates[element]!;

/// [element] 剋邊行（財）
String elementControlledBy(String element) => _controls[element]!;

/// 簡體 → 繁體對照表（`lunar` package 回傳簡體，UI 一律要繁體）。
/// **規則**：淨係列出「簡體同繁體字形唔同」嘅字／詞；已經同繁體一樣嘅字唔使入表，
/// [traditionalize] 對表入面搵唔到嘅原樣返回。跟住 Phase 2 對住 design-preview.html
/// 肉眼查 UI 若發現漏字，喺呢個表加多條 entry 就得。
///
/// ⚠️ **一簡對多繁嘅字（例如「发」= 髮/發）唔准淨係加做單字 entry**——會靜靜哋
/// 譯錯（例如「開發」誤譯做「開髮」），而且睇落仲係繁體字，肉眼 QA 好難發現。
/// 呢類字**只准**用完整詞語做 whole-string entry（例如 `'理发': '理髮'`），
/// 唔喺呢個表見到就即刻原字放行（睇落仲有簡體字，肉眼一睇就中）。
const Map<String, String> _simplifiedToTraditional = {
  '理发': '理髮',
  '马': '馬', '龙': '龍', '风': '風', '鸡': '雞',
  '开': '開', '闭': '閉', '满': '滿', '执': '執',
  '马会': '馬會',
  '馀事勿取': '餘事勿取', '余事勿取': '餘事勿取',
  '诸事不宜': '諸事不宜',
  '纳财': '納財', '纳采': '納采', '纳畜': '納畜',
  '动土': '動土', '订盟': '訂盟',
  '开市': '開市', '开渠': '開渠', '开光': '開光',
  '坏垣': '壞垣', '栽种': '栽種',
  '求医': '求醫',
  '会亲友': '會親友',
  // 沖煞方位（`getDaySha()` 回傳簡體方位字）
  '东': '東',
  // 宜/忌活動詞入面出現嘅其他簡體單字（spec §11 golden fixtures 7 日範圍內實測）
  '挂': '掛', '丧': '喪', '坟': '墳', '产': '產', '斋': '齋',
  '门': '門', '学': '學', '仓': '倉', '货': '貨', '财': '財',
  '养': '養', '启': '啟', '钻': '鑽', '谢': '謝', '进': '進',
  '寿': '壽', '结': '結', '网': '網', '殓': '殮',
  // 2026-07-25 review：spec 7 日 fixture 之外重新掃過 2025-2027 成三年
  // `lunar` package 原始 getDayYi/getDayJi/getDaySha/getZhiXing/
  // getDayChongShengXiao 輸出，揾到嘅簡體單字（逐個對照教育部《異體字
  // 字典》/《國語辭典》確認正確繁體形，唔淨止靠 OpenCC 對表——因為部分
  // OpenCC「簡轉繁」目標字喺教育部字典入面其實係異體字，原字先至係正字，
  // 見下面「刻意唔轉」清單）。
  '无': '無', '机': '機', '桥': '橋', '渔': '漁', '猎': '獵', '猪': '豬',
  '盖': '蓋', '竖': '豎', '经': '經', '绘': '繪', '络': '絡', '艺': '藝',
  '蚁': '蟻', '补': '補', '讼': '訟', '词': '詞', '车': '車', '针': '針',
  '问': '問', '饰': '飾', '习': '習', '厕': '廁', '墙': '牆', '帐': '帳',
  '庙': '廟', '归': '歸', '扫': '掃', '断': '斷', '纳': '納',
  // ⚠️ 刻意唔加入單字表：呢幾個字教育部《國語辭典》定義佢哋本身就係正字
  // （唔係簡體），OpenCC 提議嘅「繁體」目標字（竈/牀/僱）喺教育部字典
  // 反而列為異體字——加咗轉換先至錯。原樣放行：灶（作灶）、床（安床）、
  // 雇（雇佣入面淨轉「佣」，見下）。
  //
  // ⚠️ 一簡對多繁（同「发」/理发同類，唔准做單字 entry）：
  '雇佣': '雇傭', // 佣(commission,傭金) vs 傭(hire) 唔同義；雇本身已係正字唔轉
  '平治道涂': '平治道塗', // 涂(道路/姓)＝正字，塗(塗抹)先係呢句原意
  '归宁': '歸寧', // 宁(zhù,門與屏風之間)＝正字，寧(平安)先係呢句原意
  '筑堤': '築堤', // 筑(古樂器/貴陽簡稱)＝正字，築(建造)先係呢句原意
};

/// 將 [lunar] package 回傳嘅簡體詞轉繁體。搵唔到就原樣返回
/// （表示個詞本身簡繁同形，例如「祭祀」「祈福」）。
String traditionalize(String simplified) {
  if (_simplifiedToTraditional.containsKey(simplified)) {
    return _simplifiedToTraditional[simplified]!;
  }
  // 逐字替換（處理啲有簡體單字夾喺繁體詞入面嘅情況，例如「理发」入面嘅「发」）
  final buffer = StringBuffer();
  for (final ch in simplified.split('')) {
    buffer.write(_simplifiedToTraditional[ch] ?? ch);
  }
  return buffer.toString();
}
