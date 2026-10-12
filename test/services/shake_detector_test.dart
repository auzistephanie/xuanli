import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/services/shake_detector.dart';

void main() {
  test('單次大力 → 唔算搖', () {
    final d = ShakeDetector();
    expect(d.add(magnitude: 20, at: const Duration(milliseconds: 0)), isFalse);
  });

  test('1 秒內兩次超過門檻 → 搖', () {
    final d = ShakeDetector();
    d.add(magnitude: 15, at: const Duration(milliseconds: 0));
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 400)), isTrue);
  });

  test('相隔太耐 → 唔算', () {
    final d = ShakeDetector();
    d.add(magnitude: 15, at: const Duration(milliseconds: 0));
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 1500)), isFalse);
  });

  test('觸發後冷卻 2 秒', () {
    final d = ShakeDetector();
    d.add(magnitude: 15, at: Duration.zero);
    d.add(magnitude: 15, at: const Duration(milliseconds: 300));
    d.add(magnitude: 15, at: const Duration(milliseconds: 600));
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 900)), isFalse);
  });

  test('細力唔計', () {
    final d = ShakeDetector();
    d.add(magnitude: 5, at: Duration.zero);
    expect(d.add(magnitude: 5, at: const Duration(milliseconds: 200)), isFalse);
  });
}
