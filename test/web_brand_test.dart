import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web title 同 manifest 顯示 Kairo', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('<title>Kairo 吉時</title>'));
    expect(html, contains('content="Kairo"'));
    expect(html.contains('玄曆'), isFalse);

    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['name'], 'Kairo 吉時');
    expect(manifest['short_name'], 'Kairo');
    expect(jsonEncode(manifest).contains('玄曆'), isFalse);
  });
}
