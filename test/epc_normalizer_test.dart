import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/core/epc_normalizer.dart';
import 'package:possible_recovery/data/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('normalizeEpc unit tests', () {
    test('24 hex sin cambios', () {
      const epc24 = '30BF8C240159B49A6BD46F2E';
      expect(normalizeEpc(epc24), '30BF8C240159B49A6BD46F2E');
      expect(normalizeEpc(epc24).length, 24);
    });

    test('32 con 8 ceros y prefijo 30 -> 24', () {
      const epc32WithZeros = '30BF8C240159B49A6BD46F2E00000000';
      expect(normalizeEpc(epc32WithZeros), '30BF8C240159B49A6BD46F2E');
      expect(normalizeEpc(epc32WithZeros).length, 24);
    });

    test('32 sin ceros finales -> se conserva', () {
      const epc32NoZeros = '30BF8C240159B49A6BD46F2E12345678';
      expect(normalizeEpc(epc32NoZeros), '30BF8C240159B49A6BD46F2E12345678');
      expect(normalizeEpc(epc32NoZeros).length, 32);

      const epc32OtherPrefix = '40BF8C240159B49A6BD46F2E00000000';
      expect(normalizeEpc(epc32OtherPrefix), '40BF8C240159B49A6BD46F2E00000000');
    });

    test('pcWords=6 recorta a 24', () {
      const epc32 = '30BF8C240159B49A6BD46F2E00000000';
      expect(normalizeEpc(epc32, pcWords: 6), '30BF8C240159B49A6BD46F2E');
      expect(normalizeEpc(epc32, pcWords: 6).length, 24);

      // Incluso si no empieza con 30 o no termina en 0s, pcWords manda
      const epcAny = 'A1B2C3D4E5F6A1B2C3D4E5F699999999';
      expect(normalizeEpc(epcAny, pcWords: 6), 'A1B2C3D4E5F6A1B2C3D4E5F6');
    });

    test('pcWords=8 con 32 hex NO recorta', () {
      const epc32 = '30BF8C240159B49A6BD46F2E00000000';
      expect(normalizeEpc(epc32, pcWords: 8), '30BF8C240159B49A6BD46F2E00000000');
      expect(normalizeEpc(epc32, pcWords: 8).length, 32);
    });

    test('minúsculas y espacios se limpian correctamente', () {
      const messyEpc = '  30bf 8c24 0159 b49a 6bd4 6f2e 0000 0000  \n';
      expect(normalizeEpc(messyEpc), '30BF8C240159B49A6BD46F2E');

      const messy24 = '  30bf8c240159b49a6bd46f2e  ';
      expect(normalizeEpc(messy24), '30BF8C240159B49A6BD46F2E');
    });

    test('parsePcWords calcula correctamente palabras desde PC hex', () {
      // 0x3000 -> 00110 00000000000 -> bits 15..11 = 6 words
      expect(parsePcWords('3000'), 6);
      expect(parsePcWords('30 00'), 6);

      // 0x4000 -> 01000 00000000000 -> bits 15..11 = 8 words
      expect(parsePcWords('4000'), 8);

      // PC inválido o 0 devuelve null
      expect(parsePcWords(null), isNull);
      expect(parsePcWords(''), isNull);
      expect(parsePcWords('0000'), isNull);
      expect(parsePcWords('ZZZZ'), isNull);
    });
  });

  group('LocalDb EPC migration tests', () {
    late LocalDb db;

    setUp(() {
      db = LocalDb(customPath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    test('migrateNormalizedEpcs normalizes 32-char EPC with trailing zeros to 24-char', () async {
      final rawDb = await db.database;

      // Insert directly raw 32-char EPC with trailing zeros as if saved by older version
      await rawDb.insert('queue', {
        'client_uuid': 'uuid-old-1',
        'epc': '30BF8C240159B49A6BD46F2E00000000',
        'sku': 'AF-012918',
        'created_at': DateTime.now().toIso8601String(),
        'status': 'sent',
      });

      // Insert an already 24-char EPC
      await rawDb.insert('queue', {
        'client_uuid': 'uuid-ok-2',
        'epc': '309373E167B0610BDCE43394',
        'sku': 'AF-012917',
        'created_at': DateTime.now().toIso8601String(),
        'status': 'sent',
      });

      // Insert a 32-char EPC without trailing zeros (should not change)
      await rawDb.insert('queue', {
        'client_uuid': 'uuid-keep-3',
        'epc': '30BF8C240159B49A6BD46F2E12345678',
        'sku': 'AF-012919',
        'created_at': DateTime.now().toIso8601String(),
        'status': 'sent',
      });

      // Run migration
      final updatedCount = await db.migrateNormalizedEpcs(rawDb);
      expect(updatedCount, 1);

      // Verify records in DB
      final rows = await rawDb.query('queue');
      expect(rows.length, 3);
      final byUuid = {for (final r in rows) r['client_uuid']: r['epc']};

      expect(byUuid['uuid-ok-2'], '309373E167B0610BDCE43394');
      expect(byUuid['uuid-old-1'], '30BF8C240159B49A6BD46F2E'); // Now 24 hex!
      expect(byUuid['uuid-keep-3'], '30BF8C240159B49A6BD46F2E12345678');
    });
  });
}
