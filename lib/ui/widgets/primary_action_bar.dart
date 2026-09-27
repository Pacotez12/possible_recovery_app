import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'pressable_scale.dart';

class PrimaryActionBar extends StatefulWidget {
  final bool isReading;
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;

  const PrimaryActionBar({
    super.key,
    required this.isReading,
    required this.onPressed,
    this.label = 'Leer etiqueta',
    this.icon = Icons.sensors,
  });

  @override
  State<PrimaryActionBar> createState() => _PrimaryActionBarState();
}

class _PrimaryActionBarState extends State<PrimaryActionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    if (widget.isReading) {
      _progressController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant PrimaryActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReading && !oldWidget.isReading) {
      _progressController.forward(from: 0.0);
    } else if (!widget.isReading && oldWidget.isReading) {
      _progressController.reset();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.sm,
        ),
        child: PressableScale(
          onPressed: widget.isReading ? null : widget.onPressed,
          enabled: !widget.isReading,
          child: Container(
            height: AppSize.primaryButton,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.isReading
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: constraints.maxWidth *
                                    _progressController.value,
                                child: Container(
                                  color: AppColors.brandPressed,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.sensors,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: AppSpace.sm),
                                  Text(
                                    'Leyendo…',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 24),
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
