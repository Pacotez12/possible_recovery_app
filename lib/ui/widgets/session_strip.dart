import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class SessionStrip extends StatelessWidget {
  final int created;
  final int verified;
  final int conflict;
  final int pending;
  final VoidCallback? onTap;

  const SessionStrip({
    super.key,
    required this.created,
    required this.verified,
    required this.conflict,
    required this.pending,
    this.onTap,
  });

  Widget _buildStat(int count, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Text(
          '$count $label',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat(created, 'Asignadas', AppColors.created),
              const SizedBox(width: AppSpace.md),
              _buildStat(verified, 'Verificadas', AppColors.verified),
              const SizedBox(width: AppSpace.md),
              _buildStat(conflict, 'Conflictos', AppColors.conflict),
              const SizedBox(width: AppSpace.md),
              _buildStat(
                pending,
                pending == 1 ? 'Pendiente' : 'Pendientes',
                AppColors.pending,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
