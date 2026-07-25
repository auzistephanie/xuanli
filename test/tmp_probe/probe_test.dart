import 'package:test/test.dart';
import 'package:xuanli/engine/almanac.dart';

void main() {
  test('probe wu placeholder', () {
    var d = DateTime(2024, 1, 1);
    final end = DateTime(2028, 12, 31);
    var count = 0;
    final samples = <String>[];
    while (!d.isAfter(end)) {
      final day = AlmanacDay.forDate(d);
      if (day.yi.length == 1 && (day.yi[0] == '無' || day.yi[0] == '无')) {
        count++;
        if (samples.length < 5) {
          samples.add('$d yi=${day.yi} isYiVague=${day.isYiVague}');
        }
      }
      d = d.add(const Duration(days: 1));
    }
    print('total matches: $count');
    for (final s in samples) {
      print(s);
    }
  });
}
