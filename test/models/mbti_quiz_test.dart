import 'package:test/test.dart';
import 'package:xuanli/models/mbti_quiz.dart';

void main() {
  group('mbtiQuizQuestions', () {
    test('啱啱 8 題，每軸（EI/SN/TF/JP）啱啱 2 題', () {
      expect(mbtiQuizQuestions.length, 8);
      for (final axis in ['EI', 'SN', 'TF', 'JP']) {
        expect(
          mbtiQuizQuestions.where((q) => q.axis == axis).length,
          2,
          reason: '$axis 軸應該有 2 題',
        );
      }
    });

    test('每題嘅 optionALetter/optionBLetter 都屬於自己嗰軸嘅兩個字母', () {
      const axisLetters = {
        'EI': {'E', 'I'},
        'SN': {'S', 'N'},
        'TF': {'T', 'F'},
        'JP': {'J', 'P'},
      };
      for (final q in mbtiQuizQuestions) {
        final letters = axisLetters[q.axis]!;
        expect(letters.contains(q.optionALetter), isTrue);
        expect(letters.contains(q.optionBLetter), isTrue);
        expect(q.optionALetter, isNot(q.optionBLetter));
      }
    });
  });

  group('computeMbtiFromAnswers', () {
    test('8 題全部一致答案 -> 對應 4 字母型', () {
      final result = computeMbtiFromAnswers(['I', 'I', 'S', 'S', 'F', 'F', 'J', 'J']);
      expect(result, 'ISFJ');
    });

    test('某軸 2 題打和（1-1）-> 用嗰軸第一題答案做決定性一票', () {
      // EI 第一題答 I，第二題答 E（打和）；其餘三軸兩題一致。
      final result = computeMbtiFromAnswers(['I', 'E', 'N', 'N', 'T', 'T', 'P', 'P']);
      expect(result, 'INTP');
    });

    test('answers 長度唔啱 8 -> throw ArgumentError', () {
      expect(() => computeMbtiFromAnswers(['I', 'E']), throwsArgumentError);
    });
  });
}
