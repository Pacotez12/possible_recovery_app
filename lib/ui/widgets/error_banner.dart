import 'package:flutter/material.dart';
import '../../core/app_error.dart';
import '../theme/tokens.dart';
import 'pressable_scale.dart';

class ErrorBanner extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onDismiss;

  const ErrorBanner({
    super.key,
    required this.error,
    this.onRetry,
    this.onAction,
    this.actionLabel,
    this.onDismiss,
  });

  Color get _color {
    switch (error.kind) {
      case AppErrorKind.warning:
      case AppErrorKind.network:
        return AppColors.pending;
      case AppErrorKind.auth:
      case AppErrorKind.notFound:
      case AppErrorKind.rateLimit:
      case AppErrorKind.server:
      case AppErrorKind.format:
      case AppErrorKind.validation:
      case AppErrorKind.hardware:
      case AppErrorKind.permission:
      case AppErrorKind.unknown:
        return AppColors.conflict;
    }
  }

  IconData get _icon {
    switch (error.kind) {
      case AppErrorKind.network:
        return Icons.wifi_off_rounded;
      case AppErrorKind.hardware:
        return Icons.sensors_off_rounded;
      case AppErrorKind.permission:
        return Icons.videocam_off_rounded;
      case AppErrorKind.warning:
        return Icons.warning_amber_rounded;
      case AppErrorKind.auth:
        return Icons.lock_outline_rounded;
      case AppErrorKind.rateLimit:
        return Icons.timer_outlined;
      default:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, color: color, size: 22),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      error.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      error.message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: onDismiss,
                ),
            ],
          ),
          if ((error.canRetry && onRetry != null) ||
              (actionLabel != null && onAction != null)) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (actionLabel != null && onAction != null)
                  PressableScale(
                    onPressed: onAction,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        actionLabel!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (error.canRetry && onRetry != null) ...[
                  if (actionLabel != null) const SizedBox(width: AppSpace.sm),
                  PressableScale(
                    onPressed: onRetry,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Reintentar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
