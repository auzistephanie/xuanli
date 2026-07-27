/// MBTI 8 題快測（spec §9.1：「我知我嘅類型」16 宮格 或 8 題快測，
/// 每軸 2 題，A/B 選項，即場計型）。題目內容係 onboarding 專用文案，
/// 唔涉及 engine 演算法，所以淨係一個 plain Dart const list，唔使
/// 走 JSON asset 嗰套（同 combos.json/activities.json 嗰啲畀 engine
/// 消費嘅數據唔同——呢個淨係 UI 用）。
///
/// ⚠️ 呢 8 題文案係第一稿（Stephanie 已確認由 Claude 幫手擬），
/// 未算最終定稿，之後可以再執靚佢，唔屬於「已寫好唔准改」嗰類內容。
class MbtiQuizQuestion {
  final String axis; // "EI" | "SN" | "TF" | "JP"
  final String prompt;
  final String optionALabel;
  final String optionALetter;
  final String optionBLabel;
  final String optionBLetter;

  const MbtiQuizQuestion({
    required this.axis,
    required this.prompt,
    required this.optionALabel,
    required this.optionALetter,
    required this.optionBLabel,
    required this.optionBLetter,
  });
}

const List<MbtiQuizQuestion> mbtiQuizQuestions = [
  MbtiQuizQuestion(
    axis: 'EI',
    prompt: '放假嗰日，你會更想——',
    optionALabel: '自己一個慢慢嘆，叉返電',
    optionALetter: 'I',
    optionBLabel: '約朋友出去，愈熱鬧愈精神',
    optionBLetter: 'E',
  ),
  MbtiQuizQuestion(
    axis: 'EI',
    prompt: '去到一個派對，你通常——',
    optionALabel: '識返幾個熟人就企喺度傾偈',
    optionALetter: 'I',
    optionBLabel: '周圍搭訕，識到邊個得邊個',
    optionBLetter: 'E',
  ),
  MbtiQuizQuestion(
    axis: 'SN',
    prompt: '睇一份計劃書，你會先留意——',
    optionALabel: '實際嘅步驟同數字',
    optionALetter: 'S',
    optionBLabel: '背後嘅大方向同可能性',
    optionBLetter: 'N',
  ),
  MbtiQuizQuestion(
    axis: 'SN',
    prompt: '講件事畀朋友聽，你會——',
    optionALabel: '由頭到尾交代晒細節',
    optionALetter: 'S',
    optionBLabel: '跳去重點，留返啲畀佢哋自己諗',
    optionBLetter: 'N',
  ),
  MbtiQuizQuestion(
    axis: 'TF',
    prompt: '朋友同你呻返份工唔開心，你會——',
    optionALabel: '同佢分析下件事點解會咁',
    optionALetter: 'T',
    optionBLabel: '先陪佢感受吓，聽佢講',
    optionBLetter: 'F',
  ),
  MbtiQuizQuestion(
    axis: 'TF',
    prompt: '決定緊要嘢嗰陣，你比較信——',
    optionALabel: '邏輯同利弊分析',
    optionALetter: 'T',
    optionBLabel: '自己嘅感覺同對人嘅影響',
    optionBLetter: 'F',
  ),
  MbtiQuizQuestion(
    axis: 'JP',
    prompt: '出門旅行，你會——',
    optionALabel: '行程排到實一實，心裡先踏實',
    optionALetter: 'J',
    optionBLabel: '淨係訂機票酒店，其餘到時算',
    optionBLetter: 'P',
  ),
  MbtiQuizQuestion(
    axis: 'JP',
    prompt: '死線前一日，你通常——',
    optionALabel: '早就搞掂晒，淨係等交',
    optionALetter: 'J',
    optionBLabel: '先開始衝刺，愈迫愈有火',
    optionBLetter: 'P',
  ),
];

/// 16 個 MBTI 類型（「我知我嘅類型」16 宮格用）。
const List<String> allMbtiTypes = [
  'INTJ', 'INTP', 'ENTJ', 'ENTP', 'INFJ', 'INFP', 'ENFJ', 'ENFP',
  'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP',
];

/// [answers] 要啱啱 8 個元素，每個對應 [mbtiQuizQuestions] 同一 index
/// 題目揀咗嘅字母。
String computeMbtiFromAnswers(List<String> answers) {
  if (answers.length != mbtiQuizQuestions.length) {
    throw ArgumentError(
      'answers must have exactly ${mbtiQuizQuestions.length} elements, '
      'got ${answers.length}',
    );
  }

  const axisOrder = ['EI', 'SN', 'TF', 'JP'];
  final result = StringBuffer();

  for (final axis in axisOrder) {
    final axisIndices = [
      for (var i = 0; i < mbtiQuizQuestions.length; i++)
        if (mbtiQuizQuestions[i].axis == axis) i,
    ];
    // 2 題投票，打和（1-1）用第一題做決定性一票。淨係 2 票嘅情況下，
    // 「打和用第一題」呢條規則本身已經蓋晒「兩題一致」嗰種情況
    // （一致嗰陣第一題答案就係嗰票結果），所以淨係讀第一題答案已經
    // 足夠——唔係漏咗第二題唔計，而係規則本身令佢喺計分嗰下冧埋。
    // 第二題喺 UI 層面仍然係用戶要答嘅 8 題之一，唔係擺設。
    result.write(answers[axisIndices[0]]);
  }

  return result.toString();
}
