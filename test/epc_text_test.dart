import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/ui/widgets/epc_text.dart';
import 'package:possible_recovery/ui/widgets/tag_card.dart';

void main() {
  group('EpcText formatting and widget tests', () {
    test('formatEpc groups 24-char EPC in 6 blocks of 4 separated by thin space', () {
      const raw = '309373E167B0610BDCE43394';
      final formatted = EpcText.formatEpc(raw);

      expect(formatted, '3093\u200973E1\u200967B0\u2009610B\u2009DCE4\u20093394');
      expect(formatted.contains('\n'), isFalse);
    });

    test('formatEpc groups 32-char EPC into 2 lines of 4 blocks separated by newline', () {
      const raw = '309373E167B0610BDCE43394A1B2C3D4';
      final formatted = EpcText.formatEpc(raw);

      const expectedLine1 = '3093\u200973E1\u200967B0\u2009610B';
      const expectedLine2 = 'DCE4\u20093394\u2009A1B2\u2009C3D4';
      expect(formatted, '$expectedLine1\n$expectedLine2');
    });

    testWidgets('EpcText widget renders 24-char formatted string', (tester) async {
      const raw = '309373E167B0610BDCE43394';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EpcText(raw),
          ),
        ),
      );

      expect(
        find.text('3093\u200973E1\u200967B0\u2009610B\u2009DCE4\u20093394'),
        findsOneWidget,
      );
    });

    testWidgets('EpcText widget renders 32-char formatted string on 2 lines', (tester) async {
      const raw = '309373E167B0610BDCE43394A1B2C3D4';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EpcText(raw),
          ),
        ),
      );

      const expected = '3093\u200973E1\u200967B0\u2009610B\nDCE4\u20093394\u2009A1B2\u2009C3D4';
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('TagCard normal mode renders 24-char EPC completely', (tester) async {
      const epc24 = 'E28011910000000012345678';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TagCard(
              epc: epc24,
              isAssigned: false,
              isCollapsed: false,
            ),
          ),
        ),
      );

      final expectedFormatted = EpcText.formatEpc(epc24);
      expect(find.text(expectedFormatted), findsOneWidget);
      expect(find.textContaining('…'), findsNothing);
    });

    testWidgets('TagCard compact mode renders 24-char EPC completely', (tester) async {
      const epc24 = 'E28011910000000012345678';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TagCard(
              epc: epc24,
              isAssigned: false,
              isCollapsed: true,
            ),
          ),
        ),
      );

      final expectedFormatted = EpcText.formatEpc(epc24);
      expect(find.text(expectedFormatted), findsOneWidget);
      expect(find.textContaining('…'), findsNothing);
    });

    testWidgets('TagCard normal mode renders 32-char EPC completely', (tester) async {
      const epc32 = 'E2801191000000001234567890ABCDEF';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TagCard(
              epc: epc32,
              isAssigned: false,
              isCollapsed: false,
            ),
          ),
        ),
      );

      final expectedFormatted = EpcText.formatEpc(epc32);
      expect(find.text(expectedFormatted), findsOneWidget);
      expect(find.textContaining('…'), findsNothing);
    });

    testWidgets('TagCard compact mode renders 32-char EPC completely', (tester) async {
      const epc32 = 'E2801191000000001234567890ABCDEF';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TagCard(
              epc: epc32,
              isAssigned: false,
              isCollapsed: true,
            ),
          ),
        ),
      );

      final expectedFormatted = EpcText.formatEpc(epc32);
      expect(find.text(expectedFormatted), findsOneWidget);
      expect(find.textContaining('…'), findsNothing);
    });
  });
}
