import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum StatusPillType {
  nueva,
  asignada,
  creada,
  reasignada,
  conflicto,
  pendiente,
}

class StatusPill extends StatelessWidget {
  final StatusPillType type;
  final String? customLabel;
  final IconData? customIcon;
  final VoidCallback? onTap;

  const StatusPill({
    super.key,
    required this.type,
    this.customLabel,
    this.customIcon,
    this.onTap,
  });

  Color get textColor {
    switch (type) {
      case StatusPillType.nueva:
        return AppColors.tagNew;
      case StatusPillType.asignada:
        return AppColors.verified;
      case StatusPillType.creada:
        return AppColors.created;
      case StatusPillType.reasignada:
        return AppColors.reassigned;
      case StatusPillType.conflicto:
        return AppColors.conflict;
      case StatusPillType.pendiente:
        return AppColors.pending;
    }
  }

  Color get backgroundColor {
    switch (type) {
      case StatusPillType.nueva:
        return AppColors.brandSoft;
      case StatusPillType.asignada:
        return const Color(0xFFEFF6FF); // verified tint (blue 50)
      case StatusPillType.creada:
        return const Color(0xFFF0FDF4); // green 50
      case StatusPillType.reasignada:
        return const Color(0xFFF5F3FF); // violet 50
      case StatusPillType.conflicto:
        return const Color(0xFFFEF2F2); // red 50
      case StatusPillType.pendiente:
        return const Color(0xFFFFFBEB); // amber 50
    }
  }

  String get defaultLabel {
    switch (type) {
      case StatusPillType.nueva:
        return 'Nueva';
      case StatusPillType.asignada:
        return 'Asignada';
      case StatusPillType.creada:
        return 'Asignada';
      case StatusPillType.reasignada:
        return 'Reasignada';
      case StatusPillType.conflicto:
        return 'Conflicto';
      case StatusPillType.pendiente:
        return 'Pendiente';
    }
  }

  IconData get defaultIcon {
    switch (type) {
      case StatusPillType.nueva:
        return Icons.add_circle_outline;
      case StatusPillType.asignada:
      case StatusPillType.creada:
        return Icons.verified_outlined;
      case StatusPillType.reasignada:
        return Icons.swap_horiz_rounded;
      case StatusPillType.conflicto:
        return Icons.warning_amber_rounded;
      case StatusPillType.pendiente:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = textColor;
    final bg = backgroundColor;
    final label = customLabel ?? defaultLabel;
    final icon = customIcon ?? defaultIcon;

    final pillWidget = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSpace.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: pillWidget,
      );
    }
    return pillWidget;
  }
}
