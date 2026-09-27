import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/core/rfid_service.dart';
import 'package:possible_recovery/models/catalog_product.dart';
import 'package:possible_recovery/ui/widgets/confirm_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RfidService barcode deduplication tests', () {
    late RfidService rfidService;

    setUp(() {
      rfidService = RfidService();
      rfidService.resetBarcodeDedupe();
    });

    tearDown(() {
      rfidService.dispose();
    });

    test('deduplicates identical barcode received within 1500ms', () async {
      final emitted = <String>[];
      final sub = rfidService.onBarcodeRead.listen(emitted.add);

      await rfidService.handleNativeCallForTest(
        const MethodCall('barcode', 'AF-012917'),
      );
      expect(emitted, ['AF-012917']);

      // Second call immediately with same barcode should be ignored
      await rfidService.handleNativeCallForTest(
        const MethodCall('barcode', 'AF-012917'),
      );
      expect(emitted, ['AF-012917']);

      // Different barcode should be accepted immediately
      await rfidService.handleNativeCallForTest(
        const MethodCall('barcode', 'AF-012918'),
      );
      expect(emitted, ['AF-012917', 'AF-012918']);

      await sub.cancel();
    });

    test('accepts identical barcode after 1500ms delay', () async {
      final emitted = <String>[];
      final sub = rfidService.onBarcodeRead.listen(emitted.add);

      await rfidService.handleNativeCallForTest(
        const MethodCall('barcode', 'AF-012917'),
      );
      expect(emitted, ['AF-012917']);

      // Wait 1600ms
      await Future.delayed(const Duration(milliseconds: 1600));

      await rfidService.handleNativeCallForTest(
        const MethodCall('barcode', 'AF-012917'),
      );
      expect(emitted, ['AF-012917', 'AF-012917']);

      await sub.cancel();
    });

    test('ignores duplicate between onBarcodeRead and barcode methods', () async {
      final emitted = <String>[];
      final sub = rfidService.onBarcodeRead.listen(emitted.add);

      await rfidService.handleNativeCallForTest(
        const MethodCall('barcode', 'AF-012917'),
      );
      // Even if legacy method onBarcodeRead is invoked with same code right after
      await rfidService.handleNativeCallForTest(
        const MethodCall('onBarcodeRead', 'AF-012917'),
      );

      expect(emitted, ['AF-012917']);
      await sub.cancel();
    });
  });

  group('ConfirmSheet in-place update and no duplicate routes', () {
    testWidgets('ConfirmSheet updates SKU dynamically via notifier without stacking',
        (tester) async {
      final notifier = ValueNotifier<ConfirmSheetData>(
        ConfirmSheetData(
          epc: '309373E167B0610BDCE43394',
          sku: 'AF-012917',
          product: CatalogProduct(
            sku: 'AF-012917',
            description: 'Pelota Oficial Conmebol',
          ),
        ),
      );

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
                      dataNotifier: notifier,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              );
            },
          ),
        ),
      );

      // Tap button to open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet is open with initial SKU
      expect(find.text('ASIGNAR ETIQUETA A'), findsOneWidget);
      expect(find.text('AF-012917'), findsOneWidget);
      expect(find.text('Pelota Oficial Conmebol'), findsOneWidget);
      expect(find.byType(ConfirmSheet), findsOneWidget);

      // Now update notifier to a new SKU (simulating second QR read while sheet open)
      notifier.value = ConfirmSheetData(
        epc: '309373E167B0610BDCE43394',
        sku: 'AF-012918',
        product: CatalogProduct(
          sku: 'AF-012918',
          description: 'Camiseta de Juego',
        ),
      );
      await tester.pump();

      // Exactly ONE sheet exists, updated with new SKU in place
      expect(find.text('ASIGNAR ETIQUETA A'), findsOneWidget);
      expect(find.text('AF-012918'), findsOneWidget);
      expect(find.text('Camiseta de Juego'), findsOneWidget);
      expect(find.text('AF-012917'), findsNothing);
      expect(find.byType(ConfirmSheet), findsOneWidget);

      // Tap "Cambiar SKU" to cancel
      await tester.tap(find.text('Cambiar SKU'));
      await tester.pumpAndSettle();

      // Sheet should be dismissed and result should be false
      expect(find.byType(ConfirmSheet), findsNothing);
      expect(result, isFalse);

      notifier.dispose();
    });
  });
}
