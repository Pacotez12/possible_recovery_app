import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/app_error.dart';
import '../../core/sku_parser.dart';
import '../../utils/feedback_helper.dart';
import '../theme/tokens.dart';
import '../widgets/error_banner.dart';

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;

  bool _isProcessing = false;
  bool _isTorchOn = false;
  double _zoomScale = 0.33; // Arranca en 2x (~0.33)
  String? _invalidNotice;
  Timer? _noticeTimer;
  Timer? _autoFocusTimer;

  // Tap-to-focus animation
  Offset? _focusPoint;
  late final AnimationController _focusAnimController;
  late final Animation<double> _focusScaleAnim;
  late final Animation<double> _focusOpacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      cameraResolution: const Size(1920, 1080),
      autoZoom: true,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 300,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
      ],
    );

    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _focusScaleAnim = Tween<double>(begin: 1.3, end: 1.0).animate(
      CurvedAnimation(parent: _focusAnimController, curve: Curves.easeOut),
    );

    _focusOpacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _focusAnimController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _controller.setZoomScale(0.33);
      } catch (e) {
        debugPrint('Error configurando zoom inicial: $e');
      }
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.trim().isEmpty) continue;

      final parsed = parseSku(rawValue);
      if (parsed != null) {
        _isProcessing = true;
        FeedbackHelper.onTagDetected();
        Navigator.of(context).pop(parsed);
        return;
      } else {
        // Show invalid notice and keep scanning
        _showInvalidBarcodeNotice(rawValue.trim());
      }
    }
  }

  void _showInvalidBarcodeNotice(String raw) {
    _noticeTimer?.cancel();
    FeedbackHelper.onError();
    setState(() {
      _invalidNotice = 'Ese código no es un SKU de activo (AF-000000)';
    });
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _invalidNotice = null;
        });
      }
    });
  }

  Future<void> _handleTapToFocus(TapDownDetails details, BoxConstraints constraints) async {
    final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
    final previewSize = _controller.value.size;
    Offset normalized;

    if (previewSize.isEmpty) {
      normalized = Offset(
        (details.localPosition.dx / widgetSize.width).clamp(0.0, 1.0),
        (details.localPosition.dy / widgetSize.height).clamp(0.0, 1.0),
      );
    } else {
      final fitted = applyBoxFit(BoxFit.cover, previewSize, widgetSize);
      final dxOffset = (widgetSize.width - fitted.destination.width) / 2.0;
      final dyOffset = (widgetSize.height - fitted.destination.height) / 2.0;

      final previewX = (details.localPosition.dx - dxOffset) / fitted.destination.width;
      final previewY = (details.localPosition.dy - dyOffset) / fitted.destination.height;
      normalized = Offset(
        previewX.clamp(0.0, 1.0),
        previewY.clamp(0.0, 1.0),
      );
    }

    setState(() {
      _focusPoint = details.localPosition;
    });
    _focusAnimController.forward(from: 0.0);

    try {
      await _controller.setFocusPoint(normalized);
    } catch (e) {
      debugPrint('Error en tap to focus: $e');
    }

    // Volver a autoenfoque continuo a los 3s
    _autoFocusTimer?.cancel();
    _autoFocusTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      try {
        await _controller.setFocusPoint(const Offset(0.5, 0.5));
      } catch (e) {
        debugPrint('Error restableciendo enfoque continuo: $e');
      }
    });
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (e) {
      debugPrint('Error toggleTorch: $e');
    }
  }

  Future<void> _onZoomChanged(double value) async {
    setState(() {
      _zoomScale = value;
    });
    try {
      await _controller.setZoomScale(value);
    } catch (e) {
      debugPrint('Error setZoomScale: $e');
    }
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _autoFocusTimer?.cancel();
    _focusAnimController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const scanAreaSize = 250.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear QR / Código de Barras'),
        actions: [
          IconButton(
            tooltip: _isTorchOn ? 'Apagar linterna' : 'Encender linterna',
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? AppColors.brand : Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
          IconButton(
            tooltip: 'Cambiar cámara',
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera Preview with Tap-to-focus
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _handleTapToFocus(details, constraints),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.xl),
                        child: ErrorBanner(
                          error: const AppError(
                            kind: AppErrorKind.permission,
                            title: 'Permiso de cámara',
                            message:
                                'Necesitamos permiso de cámara para escanear el QR',
                            canRetry: false,
                          ),
                          actionLabel: 'Abrir ajustes',
                          onAction: () async {
                            try {
                              const channel = MethodChannel(
                                  'com.segel.possible_recovery/rfid');
                              await channel.invokeMethod('openAppSettings');
                            } catch (_) {}
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Scanner Darkened Overlay with Cutout
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.6),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        backgroundBlendMode: BlendMode.dstOut,
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: scanAreaSize,
                        height: scanAreaSize,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Guide Frame with Corner Brackets
              Center(
                child: SizedBox(
                  width: scanAreaSize,
                  height: scanAreaSize,
                  child: CustomPaint(
                    painter: _GuideFramePainter(color: AppColors.brand),
                  ),
                ),
              ),

              // Animated Focus Reticle
              if (_focusPoint != null)
                AnimatedBuilder(
                  animation: _focusAnimController,
                  builder: (context, child) {
                    final opacity = _focusOpacityAnim.value;
                    if (opacity <= 0) return const SizedBox.shrink();
                    return Positioned(
                      left: _focusPoint!.dx - 28,
                      top: _focusPoint!.dy - 28,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: _focusScaleAnim.value,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.brand, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Top Status / Instructions
              Positioned(
                top: 24,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    'Apunte al código QR o Code128 de la etiqueta\nToque la pantalla para enfocar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // Invalid Code Notice Banner
              if (_invalidNotice != null)
                Positioned(
                  top: 96,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade400),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _invalidNotice!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Controls: Guidance, Zoom Chips (1x, 2x, 3x) and Torch
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Acercá a 8–10 cm del QR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTorchChip(),
                          _buildZoomChip('1x', 0.0),
                          _buildZoomChip('2x', 0.33),
                          _buildZoomChip('3x', 0.66),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTorchChip() {
    return InkWell(
      onTap: _toggleTorch,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isTorchOn ? AppColors.brand : Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isTorchOn ? AppColors.brand : Colors.white24,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              size: 16,
              color: _isTorchOn ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              'Luz',
              style: TextStyle(
                color: _isTorchOn ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomChip(String label, double scale) {
    final isSelected = (_zoomScale - scale).abs() < 0.05;
    return InkWell(
      onTap: () => _onZoomChanged(scale),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.brand : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _GuideFramePainter extends CustomPainter {
  final Color color;
  static const double strokeWidth = 3.5;
  static const double cornerLength = 28.0;

  _GuideFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Top Left
    canvas.drawLine(const Offset(0, 0), Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, cornerLength), paint);

    // Top Right
    canvas.drawLine(Offset(w, 0), Offset(w - cornerLength, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, cornerLength), paint);

    // Bottom Left
    canvas.drawLine(Offset(0, h), Offset(cornerLength, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - cornerLength), paint);

    // Bottom Right
    canvas.drawLine(Offset(w, h), Offset(w - cornerLength, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _GuideFramePainter oldDelegate) =>
      color != oldDelegate.color;
}
