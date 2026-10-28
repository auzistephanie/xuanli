import '../models/profile.dart';

/// Traditional five-element colour associations for optional styling.
/// These are a cultural interpretation, not an objective prediction.
const elementColors = <String, List<String>>{
  '木': ['綠色', '青色'],
  '火': ['紅色', '橙色'],
  '土': ['黃色', '啡色'],
  '金': ['白色', '金色'],
  '水': ['黑色', '深藍色'],
};

/// Returns stable suggestions from the user's favorable elements.
/// Does not read or transmit private profile data.
List<String> luckyColorsForProfile(Profile profile) {
  final result = <String>[];
  for (final element in profile.favorable) {
    for (final color in elementColors[element] ?? const <String>[]) {
      if (!result.contains(color)) result.add(color);
    }
  }
  return List.unmodifiable(result);
}
