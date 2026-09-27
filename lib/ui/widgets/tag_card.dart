import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'epc_text.dart';
import 'status_pill.dart';

class TagCard extends StatelessWidget {
  final String epc;
  final bool isAssigned;
  final String? assignedSku;
  final String? assignedDescription;
  final String? assignedBy;
  final String? assignedAt;
  final bool isCollapsed;
  final String? noticeMessage;

  const TagCard({
    super.key,
    required this.epc,
    this.isAssigned = false,
    this.assignedSku,
    this.assignedDescription,
    this.assignedBy,
    this.assignedAt,
    this.isCollapsed = false,
    this.noticeMessage,
  });

  String get _assignedDetailsText {
    final parts = <String>[];
    if (assignedSku != null && assignedSku!.isNotEmpty) {
      parts.add(assignedSku!);
    }
    if (assignedDescription != null && assignedDescription!.isNotEmpty) {
      parts.add(assignedDescription!);
    }
    var meta = '';
    if (assignedBy != null && assignedBy!.isNotEmpty) {
      meta = 'asignada por $assignedBy';
    }
    if (assignedAt != null && assignedAt!.isNotEmpty) {
      meta = meta.isNotEmpty ? '$meta el $assignedAt' : 'el $assignedAt';
    }
    if (meta.isNotEmpty) {
      parts.add(meta);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (noticeMessage != null && noticeMessage!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.pending.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.pending.withValues(alpha: 0.6), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.pending, size: 24),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                noticeMessage!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.pending,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (epc.isEmpty) return const SizedBox.shrink();

    final pillType = isAssigned ? StatusPillType.asignada : StatusPillType.nueva;

    if (isCollapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.nfc_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: EpcText(
                epc,
                style: AppTypography.epc.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            StatusPill(type: pillType),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EPC',
                      style: AppTypography.label.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    EpcText(
                      epc,
                      style: AppTypography.epc.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              StatusPill(type: pillType),
            ],
          ),
          if (isAssigned && _assignedDetailsText.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: AppSpace.md),
            Text(
              _assignedDetailsText,
              style: AppTypography.body.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
