import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 用家睇到嘅字串唔可以再有「玄曆」。comment 唔計；日曆去重識別碼係刻意保留。
void main() {
  test('lib/ 嘅 Dart 字串冇「玄曆」（除咗日曆識別碼）', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (code.contains('玄曆') && !code.contains('玄曆識別碼')) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('印章唔再用單字「玄」', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].split('//').first.contains("'玄'")) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
