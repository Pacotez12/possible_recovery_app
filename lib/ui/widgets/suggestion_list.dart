import 'package:flutter/material.dart';
import '../../core/sku_parser.dart';
import '../../models/catalog_product.dart';
import '../theme/tokens.dart';
import 'pressable_scale.dart';

class SuggestionList extends StatelessWidget {
  final List<CatalogProduct> suggestions;
  final String currentInput;
  final ValueChanged<CatalogProduct> onSelect;

  const SuggestionList({
    super.key,
    required this.suggestions,
    required this.currentInput,
    required this.onSelect,
  });

  bool _isExactMatch(CatalogProduct product) {
    final parsed = parseSku(currentInput);
    if (parsed != null && parsed == product.sku) return true;
    final cleanInput = currentInput.trim().toUpperCase().replaceAll('AF-', '');
    final cleanProduct = product.sku.replaceAll('AF-', '');
    if (cleanInput.isNotEmpty && cleanProduct == cleanInput) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final maxVisibleRows = suggestions.length > 4 ? 4 : suggestions.length;
    final height = maxVisibleRows * 64.0;

    return Container(
      height: height,
      margin: const EdgeInsets.only(top: AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            color: AppColors.border,
          ),
          itemBuilder: (context, index) {
            final product = suggestions[index];
            final exact = _isExactMatch(product);

            return PressableScale(
              onPressed: () => onSelect(product),
              child: Container(
                height: 64,
                color: exact ? AppColors.brandSoft : AppColors.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.xs,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          product.sku,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (exact) ...[
                          const SizedBox(width: AppSpace.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Coincidencia exacta',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (product.location != null && product.location!.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 120),
                                child: Text(
                                  product.location!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.description ?? 'Sin descripción',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
