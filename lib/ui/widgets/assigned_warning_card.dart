import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'epc_text.dart';
import 'pressable_scale.dart';

class AssignedWarningCard extends StatelessWidget {
  final String epc;
  final String sku;
  final String? description;
  final String? location;
  final String? assignedBy;
  final String? assignedAt;
  final VoidCallback onCorrect;
  final VoidCallback onReassign;

  const AssignedWarningCard({
    super.key,
    required this.epc,
    required this.sku,
    this.description,
    this.location,
    this.assignedBy,
    this.assignedAt,
    required this.onCorrect,
    required this.onReassign,
  });

  String _formatMeta() {
    final user = (assignedBy != null && assignedBy!.trim().isNotEmpty)
        ? assignedBy!.trim()
        : null;
    final date = (assignedAt != null && assignedAt!.trim().isNotEmpty)
        ? assignedAt!.trim()
        : null;

    if (user != null && date != null) {
      return 'Asignada por $user el $date';
    } else if (user != null) {
      return 'Asignada por $user';
    } else if (date != null) {
      return 'Asignada el $date';
    }
    return 'Asignada';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning, width: 2),
      ),
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 32,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  'Esta etiqueta ya está asignada',
                  style: AppTypography.title.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            sku,
            style: AppTypography.display.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              description!.trim(),
              style: AppTypography.title.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (location != null && location!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpace.xs),
                Text(
                  location!.trim(),
                  style: AppTypography.body.copyWith(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.xs),
          Text(
            _formatMeta(),
            style: AppTypography.body.copyWith(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EPC  ',
                  style: AppTypography.label.copyWith(fontSize: 12),
                ),
                Expanded(
                  child: EpcText(
                    epc,
                    style: AppTypography.epc.copyWith(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          PressableScale(
            onPressed: onCorrect,
            child: Container(
              height: AppSize.primaryButton,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Es correcta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          PressableScale(
            onPressed: onReassign,
            child: Container(
              height: AppSize.touch,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.warning, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Volver a asignar',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
