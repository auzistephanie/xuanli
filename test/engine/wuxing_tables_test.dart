import 'package:test/test.dart';
import 'package:xuanli/engine/wuxing_tables.dart';

void main() {
  group('WuxingTables', () {
    test('天干五行', () {
      expect(ganWuxing['甲'], '木');
      expect(ganWuxing['乙'], '木');
      expect(ganWuxing['丙'], '火');
      expect(ganWuxing['丁'], '火');
      expect(ganWuxing['戊'], '土');
      expect(ganWuxing['己'], '土');
      expect(ganWuxing['庚'], '金');
      expect(ganWuxing['辛'], '金');
      expect(ganWuxing['壬'], '水');
      expect(ganWuxing['癸'], '水');
    });

    test('地支本氣五行', () {
      expect(zhiWuxing['子'], '水');
      expect(zhiWuxing['丑'], '土');
      expect(zhiWuxing['寅'], '木');
      expect(zhiWuxing['卯'], '木');
      expect(zhiWuxing['辰'], '土');
      expect(zhiWuxing['巳'], '火');
      expect(zhiWuxing['午'], '火');
      expect(zhiWuxing['未'], '土');
      expect(zhiWuxing['申'], '金');
      expect(zhiWuxing['酉'], '金');
      expect(zhiWuxing['戌'], '土');
      expect(zhiWuxing['亥'], '水');
    });

    test('地支六沖', () {
      expect(zhiClash['子'], '午');
      expect(zhiClash['午'], '子');
      expect(zhiClash['丑'], '未');
      expect(zhiClash['未'], '丑');
      expect(zhiClash['寅'], '申');
      expect(zhiClash['申'], '寅');
      expect(zhiClash['卯'], '酉');
      expect(zhiClash['酉'], '卯');
      expect(zhiClash['辰'], '戌');
      expect(zhiClash['戌'], '辰');
      expect(zhiClash['巳'], '亥');
      expect(zhiClash['亥'], '巳');
    });

    test('相生：邊行生日主', () {
      expect(elementThatGenerates('木'), '水'); // 水生木
      expect(elementThatGenerates('火'), '木'); // 木生火
      expect(elementThatGenerates('土'), '火'); // 火生土
      expect(elementThatGenerates('金'), '土'); // 土生金
      expect(elementThatGenerates('水'), '金'); // 金生水
    });

    test('相剋：邊行剋日主', () {
      expect(elementThatControls('木'), '金'); // 金剋木
      expect(elementThatControls('火'), '水'); // 水剋火
      expect(elementThatControls('土'), '木'); // 木剋土
      expect(elementThatControls('金'), '火'); // 火剋金
      expect(elementThatControls('水'), '土'); // 土剋水
    });

    test('日主生邊行（食傷）', () {
      expect(elementGeneratedBy('木'), '火'); // 木生火
      expect(elementGeneratedBy('水'), '木'); // 水生木
    });

    test('日主剋邊行（財）', () {
      expect(elementControlledBy('木'), '土'); // 木剋土
      expect(elementControlledBy('水'), '火'); // 水剋火
    });

    test('簡繁對照表覆蓋 spec §7/§11 出現嘅字', () {
      expect(traditionalize('理发'), '理髮');
      expect(traditionalize('马'), '馬');
      expect(traditionalize('龙'), '龍');
      expect(traditionalize('开'), '開');
      expect(traditionalize('闭'), '閉');
      expect(traditionalize('满'), '滿');
      expect(traditionalize('执'), '執');
      expect(traditionalize('馀事勿取'), '餘事勿取');
      expect(traditionalize('诸事不宜'), '諸事不宜');
      expect(traditionalize('纳财'), '納財');
      expect(traditionalize('动土'), '動土');
      expect(traditionalize('纳采'), '納采');
      expect(traditionalize('订盟'), '訂盟');
      expect(traditionalize('开市'), '開市');
      expect(traditionalize('开渠'), '開渠');
      expect(traditionalize('坏垣'), '壞垣');
      expect(traditionalize('纳畜'), '納畜');
      expect(traditionalize('求医', ), '求醫');
      expect(traditionalize('栽种'), '栽種');
      // 已經係繁體嘅字要原樣返回（唔喺對照表出現）
      expect(traditionalize('祭祀'), '祭祀');
    });
  });
}
