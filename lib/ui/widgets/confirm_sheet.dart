import 'package:flutter/material.dart';
import '../../models/catalog_product.dart';
import '../theme/tokens.dart';
import 'epc_text.dart';
import 'pressable_scale.dart';

class ConfirmSheetData {
  final String epc;
  final String sku;
  final CatalogProduct? product;
  final bool isReverify;
  final bool isConflictWarning;
  final String? conflictPreviousSku;
  final bool isReassign;
  final String? reassignOriginalSku;
  final String? reassignOriginalDesc;

  const ConfirmSheetData({
    required this.epc,
    required this.sku,
    this.product,
    this.isReverify = false,
    this.isConflictWarning = false,
    this.conflictPreviousSku,
    this.isReassign = false,
    this.reassignOriginalSku,
    this.reassignOriginalDesc,
  });
}

class ConfirmSheet extends StatelessWidget {
  final String epc;
  final String sku;
  final CatalogProduct? product;
  final bool isReverify;
  final bool isConflictWarning;
  final String? conflictPreviousSku;
  final bool isReassign;
  final String? reassignOriginalSku;
  final String? reassignOriginalDesc;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmSheet({
    super.key,
    required this.epc,
    required this.sku,
    this.product,
    this.isReverify = false,
    this.isConflictWarning = false,
    this.conflictPreviousSku,
    this.isReassign = false,
    this.reassignOriginalSku,
    this.reassignOriginalDesc,
    required this.onConfirm,
    required this.onCancel,
  });

  static Future<bool?> show(
    BuildContext context, {
    ValueNotifier<ConfirmSheetData>? dataNotifier,
    String? epc,
    String? sku,
    CatalogProduct? product,
    bool isReverify = false,
    bool isConflictWarning = false,
    String? conflictPreviousSku,
    bool isReassign = false,
    String? reassignOriginalSku,
    String? reassignOriginalDesc,
  }) {
    final notifier = dataNotifier ??
        ValueNotifier<ConfirmSheetData>(
          ConfirmSheetData(
            epc: epc ?? '',
            sku: sku ?? '',
            product: product,
            isReverify: isReverify,
            isConflictWarning: isConflictWarning,
            conflictPreviousSku: conflictPreviousSku,
            isReassign: isReassign,
            reassignOriginalSku: reassignOriginalSku,
            reassignOriginalDesc: reassignOriginalDesc,
          ),
        );
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      sheetAnimationStyle: const AnimationStyle(
        duration: AppMotion.slow,
        reverseDuration: AppMotion.slow,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: ValueListenableBuilder<ConfirmSheetData>(
          valueListenable: notifier,
          builder: (context, data, _) {
            return ConfirmSheet(
              epc: data.epc,
              sku: data.sku,
              product: data.product,
              isReverify: data.isReverify,
              isConflictWarning: data.isConflictWarning,
              conflictPreviousSku: data.conflictPreviousSku,
              isReassign: data.isReassign,
              reassignOriginalSku: data.reassignOriginalSku,
              reassignOriginalDesc: data.reassignOriginalDesc,
              onConfirm: () => Navigator.of(ctx).pop(true),
              onCancel: () => Navigator.of(ctx).pop(false),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNotInCatalog = product == null;

    final primaryLabel = isNotInCatalog
        ? 'Enviar igual'
        : (isReverify ? 'Confirmar Verificación' : 'Asignar');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.xs,
        AppSpace.lg,
        AppSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isReassign) ...[
            Row(
              children: [
                const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.conflict,
                  size: 24,
                ),
                const SizedBox(width: AppSpace.xs),
                Text(
                  'MOVER LA ETIQUETA',
                  style: AppTypography.label.copyWith(
                    color: AppColors.conflict,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'De ${reassignOriginalSku ?? conflictPreviousSku ?? "anterior"}${reassignOriginalDesc != null && reassignOriginalDesc!.isNotEmpty ? " · $reassignOriginalDesc" : ""}',
                    style: const TextStyle(
                      fontSize: 15,
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  const Icon(
                    Icons.arrow_downward_rounded,
                    size: 18,
                    color: AppColors.conflict,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'A $sku${product?.description != null && product!.description!.isNotEmpty ? " · ${product!.description}" : ""}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: AppColors.conflict.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.conflict.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 18, color: AppColors.conflict),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'Esta acción queda registrada con tu usuario.',
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        color: AppColors.conflict,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'ASIGNAR ETIQUETA A',
              style: AppTypography.label,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              sku,
              style: AppTypography.display,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              product?.description ?? 'Producto no registrado en catálogo local',
              style: AppTypography.title.copyWith(
                color: product != null ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 18,
              ),
            ),
            if (product?.location != null && product!.location!.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    product!.location!,
                    style: AppTypography.body.copyWith(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: AppSpace.md),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Text(
                'EPC: ',
                style: AppTypography.label.copyWith(fontSize: 12),
              ),
              Expanded(
                child: EpcText(
                  epc,
                  style: AppTypography.epc.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (!isReassign && isNotInCatalog) ...[
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: AppColors.pending.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.pending.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.pending,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'Este SKU no está en el catálogo local descargado. Se enviará al servidor para validación.',
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        color: AppColors.pending,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isReassign && isConflictWarning) ...[
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: AppColors.conflict.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.conflict.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.conflict,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'Atención: La etiqueta ya está asociada a $conflictPreviousSku. Si hay conflicto el servidor rechazará la asignación.',
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        color: AppColors.conflict,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.xl),
          PressableScale(
            onPressed: onConfirm,
            child: Container(
              height: AppSize.primaryButton,
              decoration: BoxDecoration(
                color: isReassign ? AppColors.conflict : AppColors.brand,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Text(
                isReassign ? 'Sí, reasignar' : primaryLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          PressableScale(
            onPressed: onCancel,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              child: Text(
                isReassign ? 'Cancelar' : 'Cambiar SKU',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
