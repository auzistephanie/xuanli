import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/services/shake_detector.dart';

void main() {
  test('單次大力 → 唔算搖', () {
    final d = ShakeDetector();
    expect(d.add(magnitude: 20, at: const Duration(milliseconds: 0)), isFalse);
  });

  test('1 秒內兩次超過門檻（中間有回落）→ 搖', () {
    final d = ShakeDetector();
    d.add(magnitude: 15, at: const Duration(milliseconds: 0));
    d.add(magnitude: 3, at: const Duration(milliseconds: 200));
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 400)), isTrue);
  });

  test('一下持續嘅震（連續幾個 sample 都超標）只算一次', () {
    final d = ShakeDetector();
    d.add(magnitude: 15, at: Duration.zero);
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 16)), isFalse);
  });

  test('超標、回落、再超標（window 內）→ 搖', () {
    final d = ShakeDetector();
    d.add(magnitude: 15, at: Duration.zero);
    d.add(magnitude: 3, at: const Duration(milliseconds: 16));
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 32)), isTrue);
  });

  test('相隔太耐 → 唔算', () {
    final d = ShakeDetector();
    d.add(magnitude: 15, at: const Duration(milliseconds: 0));
    d.add(magnitude: 3, at: const Duration(milliseconds: 700));
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 1500)), isFalse);
  });

  test('觸發後冷卻 2 秒', () {
    final d = ShakeDetector();
    d.add(magnitude: 15, at: Duration.zero);
    d.add(magnitude: 3, at: const Duration(milliseconds: 150));
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 300)), isTrue);
    d.add(magnitude: 3, at: const Duration(milliseconds: 450));
    d.add(magnitude: 15, at: const Duration(milliseconds: 600));
    d.add(magnitude: 3, at: const Duration(milliseconds: 750));
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 900)), isFalse);
  });

  test('細力唔計', () {
    final d = ShakeDetector();
    d.add(magnitude: 5, at: Duration.zero);
    expect(d.add(magnitude: 5, at: const Duration(milliseconds: 200)), isFalse);
  });
}
