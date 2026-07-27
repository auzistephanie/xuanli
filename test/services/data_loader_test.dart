import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/activity.dart';
import 'package:xuanli/models/combo.dart';
import 'package:xuanli/services/data_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadEngineData() 由真 asset 讀 JSON，令 loadActivities/loadCombos 用得', () async {
    await loadEngineData();

    expect(loadActivities().length, 14);
    expect(loadCombos().length, 160);
  });
}
