import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/core/barcode_deduper.dart';

void main() {
  group('BarcodeDeduper unit tests', () {
    late DateTime currentTime;
    late BarcodeDeduper deduper;

    setUp(() {
      currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      deduper = BarcodeDeduper(
        window: const Duration(milliseconds: 1500),
        clock: () => currentTime,
      );
    });

    test('mismo código dentro de 1,5 s desde la entrega -> ignorado', () {
      // Primera lectura: entregada a t = 0
      expect(deduper.shouldDeliver('AF-012918'), isTrue);
      expect(deduper.lastDeliveredBarcode, 'AF-012918');

      // Mismo código a los 500 ms -> ignorado
      currentTime = currentTime.add(const Duration(milliseconds: 500));
      expect(deduper.shouldDeliver('AF-012918'), isFalse);

      // Mismo código a los 1400 ms desde la entrega -> ignorado
      currentTime = currentTime.add(const Duration(milliseconds: 900));
      expect(deduper.shouldDeliver('AF-012918'), isFalse);
    });

    test('descartes repetidos no extienden la ventana', () {
      // Entrega inicial en t = 0
      expect(deduper.shouldDeliver('AF-012918'), isTrue);
      final initialDeliveryTime = deduper.lastDeliveredAt;

      // Múltiples descartes sucesivos dentro de la ventana de 1.5s
      currentTime = currentTime.add(const Duration(milliseconds: 300));
      expect(deduper.shouldDeliver('AF-012918'), isFalse);
      expect(deduper.lastDeliveredAt, initialDeliveryTime);

      currentTime = currentTime.add(const Duration(milliseconds: 300)); // t = 600ms
      expect(deduper.shouldDeliver('AF-012918'), isFalse);
      expect(deduper.lastDeliveredAt, initialDeliveryTime);

      currentTime = currentTime.add(const Duration(milliseconds: 400)); // t = 1000ms
      expect(deduper.shouldDeliver('AF-012918'), isFalse);
      expect(deduper.lastDeliveredAt, initialDeliveryTime);

      currentTime = currentTime.add(const Duration(milliseconds: 450)); // t = 1450ms
      expect(deduper.shouldDeliver('AF-012918'), isFalse);
      expect(deduper.lastDeliveredAt, initialDeliveryTime);

      // t = 1550ms: han pasado 1550ms desde la entrega inicial (aunque solo 100ms desde el último descarte)
      currentTime = currentTime.add(const Duration(milliseconds: 100));
      expect(deduper.shouldDeliver('AF-012918'), isTrue);
      expect(deduper.lastDeliveredAt, currentTime);
    });

    test('código distinto -> pasa', () {
      // Entrega inicial en t = 0
      expect(deduper.shouldDeliver('AF-012918'), isTrue);

      // Código distinto a los 100 ms -> pasa inmediatamente
      currentTime = currentTime.add(const Duration(milliseconds: 100));
      expect(deduper.shouldDeliver('AF-012919'), isTrue);
      expect(deduper.lastDeliveredBarcode, 'AF-012919');

      // Vuelve a cambiar a AF-012918 a los 100 ms -> pasa inmediatamente
      currentTime = currentTime.add(const Duration(milliseconds: 100));
      expect(deduper.shouldDeliver('AF-012918'), isTrue);
      expect(deduper.lastDeliveredBarcode, 'AF-012918');
    });

    test('mismo código pasada la ventana -> pasa', () {
      // Entrega inicial en t = 0
      expect(deduper.shouldDeliver('AF-012918'), isTrue);

      // Mismo código después de 1500 ms (t = 1501 ms) -> pasa
      currentTime = currentTime.add(const Duration(milliseconds: 1501));
      expect(deduper.shouldDeliver('AF-012918'), isTrue);
    });

    test('reset permite entregar el mismo código inmediatamente', () {
      expect(deduper.shouldDeliver('AF-012918'), isTrue);
      expect(deduper.shouldDeliver('AF-012918'), isFalse);

      deduper.reset();
      expect(deduper.lastDeliveredBarcode, isNull);
      expect(deduper.shouldDeliver('AF-012918'), isTrue);
    });

    test('códigos vacíos son rechazados sin afectar estado', () {
      expect(deduper.shouldDeliver(''), isFalse);
      expect(deduper.shouldDeliver('   '), isFalse);
      expect(deduper.lastDeliveredBarcode, isNull);
    });
  });
}
