import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/stick_cylinder.dart';

void main() {
  testWidgets('任何 angle／pop 都 render 到，冇 exception', (tester) async {
    for (final pop in [0.0, 0.5, 1.0]) {
      await tester.pumpWidget(MaterialApp(home: Center(child: StickCylinder(angle: 0.2, pop: pop, spin: pop))));
      expect(tester.takeException(), isNull);
    }
    expect(find.bySemanticsLabel('籤筒'), findsOneWidget);
  });
}
