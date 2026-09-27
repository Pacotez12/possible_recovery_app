import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/ui/theme/tokens.dart';
import 'package:possible_recovery/ui/widgets/status_pill.dart';

void main() {
  group('StatusPill tests', () {
    test('StatusPill colors match design tokens exactly', () {
      const nueva = StatusPill(type: StatusPillType.nueva);
      expect(nueva.textColor, AppColors.tagNew);
      expect(nueva.backgroundColor, AppColors.brandSoft);
      expect(nueva.defaultLabel, 'Nueva');

      const asignada = StatusPill(type: StatusPillType.asignada);
      expect(asignada.textColor, AppColors.verified);
      expect(asignada.backgroundColor, const Color(0xFFEFF6FF));
      expect(asignada.defaultLabel, 'Asignada');

      const creada = StatusPill(type: StatusPillType.creada);
      expect(creada.textColor, AppColors.created);
      expect(creada.backgroundColor, const Color(0xFFF0FDF4));

      const conflicto = StatusPill(type: StatusPillType.conflicto);
      expect(conflicto.textColor, AppColors.conflict);
      expect(conflicto.backgroundColor, const Color(0xFFFEF2F2));
      expect(conflicto.defaultLabel, 'Conflicto');

      const pendiente = StatusPill(type: StatusPillType.pendiente);
      expect(pendiente.textColor, AppColors.pending);
      expect(pendiente.backgroundColor, const Color(0xFFFFFBEB));
      expect(pendiente.defaultLabel, 'Pendiente');
    });

    testWidgets('StatusPill renders label and icon in widget tree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusPill(type: StatusPillType.nueva),
          ),
        ),
      );

      expect(find.text('Nueva'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusPill(type: StatusPillType.asignada),
          ),
        ),
      );

      expect(find.text('Asignada'), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    });
  });
}
