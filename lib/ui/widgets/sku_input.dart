import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'pressable_scale.dart';

class SkuInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onScanPressed;
  final VoidCallback? onCameraPressed;
  final bool isCameraFallback;
  final bool isScanning;
  final bool autofocus;

  const SkuInput({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onScanPressed,
    this.onCameraPressed,
    this.isCameraFallback = false,
    this.isScanning = false,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final text = controller.text.trim();
              final hidePrefix = text.toUpperCase().startsWith('AF') ||
                  text.toLowerCase().startsWith('http');

              return TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  prefixText: hidePrefix ? null : 'AF-',
                  prefixStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                  hintText: hidePrefix ? 'AF-012918' : '012918',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.lg,
                    vertical: AppSpace.md,
                  ),
                ),
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              );
            },
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        PressableScale(
          onPressed: isScanning
              ? null
              : (isCameraFallback ? onCameraPressed : onScanPressed),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            height: 56,
            padding: EdgeInsets.symmetric(
              horizontal: isScanning ? AppSpace.md : AppSpace.sm,
            ),
            constraints: const BoxConstraints(minWidth: 56),
            decoration: BoxDecoration(
              color: isScanning
                  ? AppColors.brand.withValues(alpha: 0.12)
                  : AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: isScanning ? 0.6 : 0.3),
                width: isScanning ? 1.5 : 1,
              ),
            ),
            child: isScanning
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand,
                        ),
                      ),
                      SizedBox(width: AppSpace.xs),
                      Text(
                        'Escaneando…',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  )
                : Tooltip(
                    message: isCameraFallback ? 'Usar cámara' : 'Escanear',
                    child: SizedBox(
                      width: 40,
                      child: Icon(
                        isCameraFallback
                            ? Icons.camera_alt_rounded
                            : Icons.qr_code_scanner_rounded,
                        color: AppColors.brand,
                        size: 26,
                      ),
                    ),
                  ),
          ),
        ),
        if (!isCameraFallback && onCameraPressed != null && !isScanning) ...[
          const SizedBox(width: AppSpace.xs),
          PressableScale(
            onPressed: onCameraPressed,
            child: Container(
              width: 48,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.border,
                  width: 1,
                ),
              ),
              child: const Tooltip(
                message: 'Usar cámara',
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
