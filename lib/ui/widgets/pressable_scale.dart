import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool enabled;
  final double targetScale;

  const PressableScale({
    super.key,
    required this.child,
    this.onPressed,
    this.enabled = true,
    this.targetScale = 0.97,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
      reverseDuration: AppMotion.fast,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.targetScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppMotion.easeOut,
      ),
    );

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppMotion.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.enabled && widget.onPressed != null) {
      _controller.forward();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (widget.enabled && widget.onPressed != null) {
      _controller.reverse();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (widget.enabled && widget.onPressed != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    Widget result = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (disableAnimations) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          );
        }
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: widget.child,
    );

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (widget.enabled && widget.onPressed != null)
            ? widget.onPressed
            : null,
        child: result,
      ),
    );
  }
}
