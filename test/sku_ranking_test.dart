import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/core/sku_ranking.dart';
import 'package:possible_recovery/models/catalog_product.dart';

void main() {
  group('SkuRanking', () {
    test('exact number match ranks first (e.g. 12918 -> AF-012918 before AF-129180)', () {
      final candidates = [
        CatalogProduct(sku: 'AF-912918', description: 'Contiene 12918'),
        CatalogProduct(sku: 'AF-129180', description: 'Prefijo 12918'),
        CatalogProduct(sku: 'AF-012918', description: 'Coincidencia exacta'),
      ];

      final results = SkuRanking.rankAndFilter(candidates, '12918');

      expect(results.first.sku, 'AF-012918');
      expect(results[1].sku, 'AF-129180');
      expect(results[2].sku, 'AF-912918');
    });

    test('prefix match ranks higher than contains match', () {
      final candidates = [
        CatalogProduct(sku: 'AF-009999', description: 'Un monitor gamer'),
        CatalogProduct(sku: 'AF-001234', description: 'Monitor Dell 24 pulgadas'),
        CatalogProduct(sku: 'AF-005678', description: 'Teclado para monitor'),
      ];

      // Query 'monitor'
      final results = SkuRanking.rankAndFilter(candidates, 'monitor');

      // 'Monitor Dell' starts with 'monitor' (prefix) -> should be first
      expect(results.first.sku, 'AF-001234');
      // 'Un monitor' and 'Teclado para monitor' contain 'monitor' -> should follow
      expect(results.length, 3);
    });

    test('description matching is accent-insensitive and case-insensitive', () {
      final candidates = [
        CatalogProduct(sku: 'AF-000100', description: 'Balón Oficial de Fútbol'),
        CatalogProduct(sku: 'AF-000200', description: 'Cámara Fotográfica'),
      ];

      final results = SkuRanking.rankAndFilter(candidates, 'balon');
      expect(results.length, 1);
      expect(results.first.sku, 'AF-000100');

      final results2 = SkuRanking.rankAndFilter(candidates, 'FUTBOL');
      expect(results2.length, 1);
      expect(results2.first.sku, 'AF-000100');

      final results3 = SkuRanking.rankAndFilter(candidates, 'camara');
      expect(results3.length, 1);
      expect(results3.first.sku, 'AF-000200');
    });

    test('respects maxResults limit of 8 items', () {
      final candidates = List.generate(
        15,
        (i) => CatalogProduct(
          sku: 'AF-${(100000 + i).toString()}',
          description: 'Elemento de prueba $i',
        ),
      );

      final results = SkuRanking.rankAndFilter(candidates, 'prueba');
      expect(results.length, 8);
    });

    test('empty query returns empty list', () {
      final candidates = [
        CatalogProduct(sku: 'AF-012918', description: 'Item'),
      ];

      expect(SkuRanking.rankAndFilter(candidates, ''), isEmpty);
      expect(SkuRanking.rankAndFilter(candidates, '   '), isEmpty);
    });
  });
}
