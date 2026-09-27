import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/core/sku_parser.dart';

void main() {
  group('parseSku', () {
    test('extracts SKU from URL query parameter term', () {
      expect(
        parseSku('https://possible.conmebol.com/api/search?type=product&term=AF-012917'),
        'AF-012917',
      );
    });

    test('normalizes lowercase sku with hyphen', () {
      expect(parseSku('af-012918'), 'AF-012918');
    });

    test('auto-prefixes AF- and pads leading zeros for numbers', () {
      expect(parseSku('12918'), 'AF-012918');
      expect(parseSku('1'), 'AF-000001');
    });

    test('adds hyphen if format is AF followed by 6 digits', () {
      expect(parseSku('AF012918'), 'AF-012918');
      expect(parseSku('af012918'), 'AF-012918');
    });

    test('returns null for non-sku text', () {
      expect(parseSku('hola'), isNull);
    });

    test('returns null for empty string or whitespace', () {
      expect(parseSku(''), isNull);
      expect(parseSku('   '), isNull);
    });

    test('returns null for invalid numbers with more than 6 digits', () {
      expect(parseSku('1234567'), isNull);
    });
  });
}
