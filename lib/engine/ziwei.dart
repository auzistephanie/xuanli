/// **MVP 簡化版**：唔係正統紫微斗數排盤（冇做五虎遁月／定命宮／安十四主星訣）。
/// 全模式（有時辰）同降級模式（冇時辰）共用呢個「日支 → 簡化主星」對照表——
/// 呢個係同 Stephanie 傾過嘅範圍決定（見 docs/superpowers/plans/2026-07-23-xuanli-phase1-engine.md）。
/// 真正紫微命宮計算留返 spec §2 決定 11 講嘅「紫微深度文案」v2 先做。
const Map<String, String> _dayZhiToZiweiStar = {
  '子': '貪狼', '丑': '天府', '寅': '紫微', '卯': '天機',
  '辰': '天相', '巳': '天梁', '午': '太陽', '未': '巨門',
  '申': '七殺', '酉': '天同', '戌': '廉貞', '亥': '太陰',
};

/// [dayZhi] = 日柱地支（例如「亥」）。十二地支窮盡覆蓋，唔會有 null case。
String ziweiStarForDayZhi(String dayZhi) => _dayZhiToZiweiStar[dayZhi]!;
