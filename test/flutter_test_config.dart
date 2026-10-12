// test/flutter_test_config.dart
import 'dart:async';

import 'package:xuanli/theme/motion.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Motion.ambientEnabled = false;
  await testMain();
}
