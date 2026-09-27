import '../models/catalog_product.dart';
import 'text_normalizer.dart';

class SkuRanking {
  static const int maxSuggestions = 8;

  static List<CatalogProduct> rankAndFilter(
    List<CatalogProduct> candidates,
    String query, {
    int maxResults = maxSuggestions,
  }) {
    final rawTrimmed = query.trim();
    if (rawTrimmed.isEmpty) return [];

    final queryNorm = normalizeText(rawTrimmed);
    final queryUpper = rawTrimmed.toUpperCase().replaceAll(' ', '');
    final queryDigits = rawTrimmed.replaceAll(RegExp(r'\D'), '');

    String? expectedExactSku;
    if (queryDigits.isNotEmpty && queryDigits.length <= 6) {
      expectedExactSku = 'AF-${queryDigits.padLeft(6, '0')}';
    }

    // Assign a score tuple (tier, secondaryScore, length) to each candidate
    final scored = <_ScoredProduct>[];

    for (final product in candidates) {
      final skuUpper = product.sku.toUpperCase().replaceAll(' ', '');
      final skuDigits = skuUpper.replaceAll(RegExp(r'\D'), '');
      final descNorm = normalizeText(product.description ?? '');

      int tier = 999;
      int subTier = 999;

      // 1. Exact Number Match
      final isExactSku = expectedExactSku != null && skuUpper == expectedExactSku;
      final isExactDigits = queryDigits.isNotEmpty && skuDigits == queryDigits;
      final isExactFull = skuUpper == queryUpper;

      if (isExactSku || isExactDigits || isExactFull) {
        tier = 1;
        subTier = (isExactSku || isExactFull) ? 0 : 1;
      }
      // 2. Prefix Match
      else if (skuUpper.startsWith(queryUpper) ||
          (queryDigits.isNotEmpty && skuDigits.startsWith(queryDigits))) {
        tier = 2;
        subTier = 1;
      } else if (descNorm.startsWith(queryNorm)) {
        tier = 2;
        subTier = 2;
      }
      // 3. Contains Match
      else if (skuUpper.contains(queryUpper) ||
          (queryDigits.isNotEmpty && skuDigits.contains(queryDigits))) {
        tier = 3;
        subTier = 1;
      } else if (descNorm.contains(queryNorm)) {
        tier = 3;
        subTier = 2;
      }

      if (tier <= 3) {
        scored.add(_ScoredProduct(
          product: product,
          tier: tier,
          subTier: subTier,
          descLength: descNorm.length,
        ));
      }
    }

    scored.sort((a, b) {
      if (a.tier != b.tier) return a.tier.compareTo(b.tier);
      if (a.subTier != b.subTier) return a.subTier.compareTo(b.subTier);
      if (a.descLength != b.descLength) return a.descLength.compareTo(b.descLength);
      return a.product.sku.compareTo(b.product.sku);
    });

    return scored.map((s) => s.product).take(maxResults).toList();
  }
}

class _ScoredProduct {
  final CatalogProduct product;
  final int tier;
  final int subTier;
  final int descLength;

  _ScoredProduct({
    required this.product,
    required this.tier,
    required this.subTier,
    required this.descLength,
  });
}
