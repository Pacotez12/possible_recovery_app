import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/models/catalog_product.dart';
import 'package:possible_recovery/ui/widgets/assigned_warning_card.dart';
import 'package:possible_recovery/ui/widgets/confirm_sheet.dart';
import 'package:possible_recovery/ui/widgets/result_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssignedWarningCard widget tests', () {
    testWidgets('renders amber warning card with full EPC, metadata and handles callbacks',
        (tester) async {
      bool correctCalled = false;
      bool reassignCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssignedWarningCard(
                epc: '30C2F1FEA18BC110CE23B02400000000',
                sku: 'AF-012917',
                description: 'Pelota Oficial Conmebol',
                location: 'Depósito Central',
                assignedBy: 'Admin',
                assignedAt: '2026-09-27 10:00',
                onCorrect: () => correctCalled = true,
                onReassign: () => reassignCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Esta etiqueta ya está asignada'), findsOneWidget);
      expect(find.text('AF-012917'), findsOneWidget);
      expect(find.text('Pelota Oficial Conmebol'), findsOneWidget);
      expect(find.text('Depósito Central'), findsOneWidget);
      expect(find.text('Asignada por Admin el 2026-09-27 10:00'), findsOneWidget);

      // Verify full 32-char EPC is present
      expect(
        find.text(
          '30C2\u2009F1FE\u2009A18B\u2009C110\nCE23\u2009B024\u20090000\u20090000',
        ),
        findsOneWidget,
      );

      // Tap 'Es correcta'
      await tester.tap(find.text('Es correcta'));
      await tester.pumpAndSettle();
      expect(correctCalled, isTrue);

      // Tap 'Volver a asignar'
      await tester.tap(find.text('Volver a asignar'));
      await tester.pumpAndSettle();
      expect(reassignCalled, isTrue);
    });

    testWidgets('renders Asignada el <fecha> without por when assignedBy is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssignedWarningCard(
                epc: '30C2F1FEA18BC110CE23B02400000000',
                sku: 'AF-012917',
                description: 'Pelota Oficial Conmebol',
                assignedBy: null,
                assignedAt: '2026-09-27 10:00',
                onCorrect: () {},
                onReassign: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Esta etiqueta ya está asignada'), findsOneWidget);
      expect(find.text('Asignada el 2026-09-27 10:00'), findsOneWidget);
      expect(find.textContaining('por'), findsNothing);
    });
  });

  group('ConfirmSheet reassign mode tests', () {
    testWidgets('renders red destructive confirmation with previous and target SKU',
        (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await ConfirmSheet.show(
                      context,
                      epc: '30C2F1FEA18BC110CE23B02400000000',
                      sku: 'AF-012918',
                      product: CatalogProduct(
                        sku: 'AF-012918',
                        description: 'Laptop Dell Latitude',
                      ),
                      isReassign: true,
                      reassignOriginalSku: 'AF-012917',
                      reassignOriginalDesc: 'Pelota Oficial Conmebol',
                    );
                  },
                  child: const Text('Open Reassign Sheet'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Reassign Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('MOVER LA ETIQUETA'), findsOneWidget);
      expect(find.text('De AF-012917 · Pelota Oficial Conmebol'), findsOneWidget);
      expect(find.text('A AF-012918 · Laptop Dell Latitude'), findsOneWidget);
      expect(
        find.text('Esta acción queda registrada con tu usuario.'),
        findsOneWidget,
      );
      expect(find.text('Sí, reasignar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      await tester.tap(find.text('Sí, reasignar'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('cancelling reassign sheet returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await ConfirmSheet.show(
                      context,
                      epc: '30C2F1FEA18BC110CE23B02400000000',
                      sku: 'AF-012918',
                      isReassign: true,
                      reassignOriginalSku: 'AF-012917',
                    );
                  },
                  child: const Text('Open Reassign Sheet'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Reassign Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('ResultCard reassign & conflict tests', () {
    testWidgets('renders reassigned result card with violet styling and auto-return',
        (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultCard(
              resultType: 'reassigned',
              sku: 'AF-012918',
              conflictSku: 'AF-012917',
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Etiqueta reasignada'), findsOneWidget);
      expect(find.text('De AF-012917 a AF-012918'), findsOneWidget);

      // Fast-forward past autoReturn delay (1500ms)
      await tester.pump(const Duration(milliseconds: 1600));
      expect(dismissed, isTrue);
    });

    testWidgets('renders conflict result card with reassign action button',
        (tester) async {
      bool reassignClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultCard(
              resultType: 'conflict',
              sku: 'AF-012918',
              conflictSku: 'AF-012917',
              conflictDescription: 'Pelota Oficial Conmebol',
              onDismiss: () {},
              onReassign: () => reassignClicked = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conflicto'), findsOneWidget);
      expect(find.text('Esta etiqueta pertenece a AF-012917 · Pelota Oficial Conmebol'), findsOneWidget);
      expect(find.text('Reasignar a AF-012918'), findsOneWidget);

      await tester.tap(find.text('Reasignar a AF-012918'));
      await tester.pumpAndSettle();

      expect(reassignClicked, isTrue);
    });
  });
}
