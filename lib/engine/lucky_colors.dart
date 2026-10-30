import '../models/profile.dart';
import 'wuxing_tables.dart';

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

 
/// Date-aware colour references: prioritize favorable elements present in the
/// day's heavenly stem and earthly branch. Fall back to the user's favorable
/// order if neither matches. This is a deterministic cultural convention.
List<String> luckyColorsForDay({
  required Profile profile,
  required String ganzhiDay,
}) {
  if (ganzhiDay.runes.length != 2) {
    throw ArgumentError.value(ganzhiDay, 'ganzhiDay', 'Expected two characters');
  }
  final characters = ganzhiDay.split('');
  final stem = ganWuxing[characters[0]];
  final branch = zhiWuxing[characters[1]];
  if (stem == null || branch == null) {
    throw ArgumentError.value(ganzhiDay, 'ganzhiDay', 'Unknown stem or branch');
  }
  final favored = profile.favorable.toSet();
  final order = <String>[
    if (favored.contains(stem)) stem,
    if (favored.contains(branch) && branch != stem) branch,
    ...profile.favorable.where((element) => element != stem && element != branch),
  ];
  final colors = <String>[];
  for (final element in order) {
    for (final color in elementColors[element] ?? const <String>[]) {
      if (!colors.contains(color)) colors.add(color);
    }
  }
  return List.unmodifiable(colors);
}
