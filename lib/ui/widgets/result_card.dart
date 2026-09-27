import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'epc_text.dart';
import 'pressable_scale.dart';

class ResultCard extends StatefulWidget {
  final String resultType; // created, verified, conflict, queued, rejected, error, reassigned
  final String sku;
  final String? description;
  final String? epc;
  final String? conflictSku;
  final String? conflictDescription;
  final String? errorMessage;
  final VoidCallback onDismiss;
  final VoidCallback? onReassign;

  const ResultCard({
    super.key,
    required this.resultType,
    required this.sku,
    this.description,
    this.epc,
    this.conflictSku,
    this.conflictDescription,
    this.errorMessage,
    required this.onDismiss,
    this.onReassign,
  });

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  AnimationController? _countdownController;

  bool get _autoReturn {
    return widget.resultType == 'created' ||
        widget.resultType == 'verified' ||
        widget.resultType == 'reassigned' ||
        widget.resultType == 'queued';
  }

  Color get _semanticColor {
    switch (widget.resultType) {
      case 'created':
        return AppColors.created;
      case 'verified':
        return AppColors.verified;
      case 'reassigned':
        return AppColors.reassigned;
      case 'queued':
        return AppColors.pending;
      case 'conflict':
      case 'rejected':
      case 'error':
      default:
        return AppColors.conflict;
    }
  }

  String get _title {
    switch (widget.resultType) {
      case 'created':
        return 'Etiqueta asignada';
      case 'verified':
        return 'Etiqueta verificada';
      case 'reassigned':
        return 'Etiqueta reasignada';
      case 'queued':
        return 'Guardada sin conexión';
      case 'conflict':
        return 'Conflicto';
      case 'rejected':
        return 'Asignación Rechazada';
      case 'error':
      default:
        return 'Error';
    }
  }

  IconData get _icon {
    switch (widget.resultType) {
      case 'created':
        return Icons.check_circle_rounded;
      case 'verified':
        return Icons.verified_rounded;
      case 'reassigned':
        return Icons.swap_horiz_rounded;
      case 'queued':
        return Icons.cloud_off_rounded;
      case 'conflict':
        return Icons.error_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'error':
      default:
        return Icons.warning_rounded;
    }
  }

  String get _detailText {
    switch (widget.resultType) {
      case 'reassigned':
        final prev = widget.conflictSku ?? 'anterior';
        return 'De $prev a ${widget.sku}';
      case 'conflict':
        final cSku = widget.conflictSku ?? 'otro SKU';
        final cDesc = widget.conflictDescription != null &&
                widget.conflictDescription!.isNotEmpty
            ? ' · ${widget.conflictDescription}'
            : '';
        return 'Esta etiqueta pertenece a $cSku$cDesc';
      case 'queued':
        return 'Guardada sin conexión, se enviará sola';
      case 'rejected':
        return widget.errorMessage ?? 'El servidor rechazó la operación.';
      case 'error':
        return widget.errorMessage ?? 'Ocurrió un error inesperado al procesar la etiqueta.';
      default:
        return widget.description ?? '';
    }
  }

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: AppMotion.base,
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: AppMotion.easeOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: AppMotion.easeOut,
      ),
    );

    _enterController.forward();

    if (_autoReturn) {
      _countdownController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );

      _countdownController!.forward().then((_) {
        if (mounted) {
          widget.onDismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    _countdownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final color = _semanticColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _autoReturn ? widget.onDismiss : null,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(color: color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _enterController,
                    builder: (context, child) {
                      if (disableAnimations) {
                        return Opacity(
                          opacity: _opacityAnimation.value,
                          child: child,
                        );
                      }
                      return Opacity(
                        opacity: _opacityAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Icon(
                      _icon,
                      size: 56,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: AppTypography.title.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    widget.sku,
                    textAlign: TextAlign.center,
                    style: AppTypography.display.copyWith(
                      fontSize: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_detailText.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      _detailText,
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  if (widget.epc != null && widget.epc!.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.md),
                    EpcText(
                      widget.epc!,
                      style: AppTypography.epc.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (!_autoReturn) ...[
                    const SizedBox(height: AppSpace.xl),
                    if (widget.resultType == 'conflict' && widget.onReassign != null) ...[
                      PressableScale(
                        onPressed: widget.onReassign,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.conflict,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Reasignar a ${widget.sku}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      PressableScale(
                        onPressed: widget.onDismiss,
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          child: Text(
                            'Entendido',
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      PressableScale(
                        onPressed: widget.onDismiss,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Entendido',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (_autoReturn && _countdownController != null)
              AnimatedBuilder(
                animation: _countdownController!,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: 1.0 - _countdownController!.value,
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  );
                },
              ),
          ],
        ),
          ],
        ),
      ),
    );
  }
}
