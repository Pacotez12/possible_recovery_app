import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_error.dart';
import '../../core/epc_normalizer.dart';
import '../../core/rfid_service.dart';
import '../../core/sku_parser.dart';
import '../../core/tag_picker.dart';
import '../../data/api_client.dart';
import '../../data/queue_service.dart';
import '../../data/sync_service.dart';
import '../../models/assign_result.dart';
import '../../models/catalog_product.dart';
import '../../models/lookup_result.dart';
import '../../utils/device_helper.dart';
import '../../utils/feedback_helper.dart';
import '../theme/tokens.dart';
import '../widgets/assigned_warning_card.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/error_banner.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/primary_action_bar.dart';
import '../widgets/result_card.dart';
import '../widgets/session_strip.dart';
import '../widgets/sku_input.dart';
import '../widgets/suggestion_list.dart';
import '../widgets/tag_card.dart';
import 'camera_scanner_screen.dart';
import 'login_screen.dart';
import 'queue_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';

enum ScanState {
  idle,
  reading,
  epcShown,
  tagAssigned,
  waitingSku,
  confirm,
  sending,
  result,
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  ScanState _state = ScanState.idle;

  late final RfidService _rfidService;
  StreamSubscription<void>? _triggerSub;
  StreamSubscription<String>? _barcodeSub;
  StreamSubscription<int>? _keySub;
  bool _scannerInitFailed = false;
  bool _isScanningBarcode = false;
  Timer? _barcodeTimeoutTimer;
  bool _isConfirmSheetOpen = false;
  ValueNotifier<ConfirmSheetData>? _confirmSheetNotifier;
  DateTime? _lastBackPressTime;

  final TextEditingController _skuController = TextEditingController();
  final FocusNode _skuFocusNode = FocusNode();

  String _currentEpc = '';
  LookupResult? _lookupResult;
  String _currentSku = '';
  CatalogProduct? _currentProduct;

  List<CatalogProduct> _suggestions = [];
  Timer? _debounceTimer;

  AssignResult? _lastAssignResult;
  String _lastResultType = ''; // created, verified, conflict, rejected, queued, error, reassigned
  String? _lastErrorMessage;
  AppError? _currentError;
  AppError? _rfidInitError;

  bool _isReassigning = false;
  String? _reassignOriginalSku;
  String? _reassignOriginalDesc;

  void _setScanState(ScanState newState) {
    _state = newState;
    final mode = switch (newState) {
      ScanState.idle => 'rfid',
      ScanState.waitingSku => 'barcode',
      _ => 'none',
    };
    _rfidService.setKeyMode(mode);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rfidService = RfidService();
    _initRfidReader();
    _setScanState(ScanState.idle);

    _skuFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _triggerSub = _rfidService.onTrigger.listen((_) {
      if (_state == ScanState.idle) {
        _startReading();
      }
    });

    _barcodeSub = _rfidService.onBarcodeRead.listen((barcode) {
      if (_state == ScanState.waitingSku) {
        _handleBarcodeRead(barcode);
      }
    });

    _keySub = _rfidService.onKeyEvent.listen((keyCode) {
      debugPrint('Tecla física recibida en ScanScreen: keyCode=$keyCode');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _barcodeTimeoutTimer?.cancel();
      _isScanningBarcode = false;
      if (_state == ScanState.waitingSku) {
        _rfidService.closeScanner();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_state == ScanState.waitingSku) {
        _open2dScanner();
      }
    }
  }

  Future<void> _open2dScanner() async {
    _rfidService.resetBarcodeDedupe();
    final ok = await _rfidService.openScanner();
    if (!mounted) return;
    setState(() {
      _scannerInitFailed = !ok;
      if (!ok) {
        _currentError = const AppError(
          kind: AppErrorKind.hardware,
          title: 'Lector de códigos',
          message: 'El lector de códigos no respondió; podés usar la cámara',
          canRetry: true,
        );
      }
    });
  }

  Future<void> _startBarcodeScan() async {
    if (_isScanningBarcode) return;
    _barcodeTimeoutTimer?.cancel();
    setState(() {
      _isScanningBarcode = true;
      _currentError = null;
    });

    final started = await _rfidService.startScan();
    if (!mounted) return;

    if (!started) {
      setState(() {
        _isScanningBarcode = false;
      });
      return;
    }

    _barcodeTimeoutTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_isScanningBarcode) return;
      _rfidService.stopScan();
      setState(() {
        _isScanningBarcode = false;
      });
    });
  }

  void _handleBarcodeRead(String raw) {
    _barcodeTimeoutTimer?.cancel();
    if (_isScanningBarcode) {
      setState(() {
        _isScanningBarcode = false;
      });
    }

    final lower = raw.trim().toLowerCase();
    if (lower == 'cancel' || lower == 'failuer' || lower == 'failure' || lower == 'timeout') {
      debugPrint('ScanScreen: ignorando estado no barcode del lector: $raw');
      return;
    }

    final parsed = parseSku(raw);
    if (parsed != null) {
      setState(() {
        _currentError = null;
        _scannerInitFailed = false;
      });
      _onSkuSubmitted(parsed);
    } else {
      FeedbackHelper.onError();
      setState(() {
        _currentError = const AppError(
          kind: AppErrorKind.validation,
          title: 'Código inválido',
          message: 'Ese código no es un SKU de activo (AF-000000)',
          canRetry: false,
        );
      });
    }
  }

  Future<void> _initRfidReader() async {
    final prefs = await SharedPreferences.getInstance();
    final power = prefs.getInt('rfid_power') ?? 10;
    final inited = await _rfidService.initReader();
    if (inited) {
      await _rfidService.setPower(power);
      if (mounted && _rfidInitError != null) {
        setState(() {
          _rfidInitError = null;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _rfidInitError = const AppError(
            kind: AppErrorKind.hardware,
            title: 'Lector RFID no disponible',
            message:
                'El lector RFID no respondió. Cerrá y abrí la app; si sigue, reiniciá el colector',
            canRetry: true,
          );
        });
      }
    }
  }

  Future<void> _startReading() async {
    if (_state == ScanState.reading || _state == ScanState.sending) return;

    _rfidService.resetBarcodeDedupe();
    _setScanState(ScanState.reading);
    setState(() {
      _currentError = null;
      _currentEpc = '';
      _lookupResult = null;
      _currentSku = '';
      _currentProduct = null;
      _skuController.clear();
      _suggestions = [];
    });

    final prefs = await SharedPreferences.getInstance();
    final marginDb = prefs.getDouble('rfid_margin_db') ?? 3.0;

    final reads = await _rfidService.readBurst(durationMs: 1000);
    final pick = pickTag(reads, marginDb: marginDb);

    if (!mounted) return;

    switch (pick) {
      case NoTag():
        _setScanState(ScanState.idle);
        setState(() {
          _currentError = const AppError(
            kind: AppErrorKind.warning,
            title: 'Sin etiqueta',
            message: 'No se detectó ninguna etiqueta. Acercá el colector',
            canRetry: true,
          );
        });
        break;

      case Ambiguous():
        _setScanState(ScanState.idle);
        setState(() {
          _currentError = const AppError(
            kind: AppErrorKind.warning,
            title: 'Lectura ambigua',
            message: 'Hay más de una etiqueta cerca, acercate más.',
            canRetry: true,
          );
        });
        FeedbackHelper.onError();
        break;

      case Picked(:final epc):
        final normEpc = normalizeEpc(epc);
        await FeedbackHelper.onTagDetected();
        _setScanState(ScanState.epcShown);
        setState(() {
          _currentEpc = normEpc;
        });
        await _performLookup(normEpc);
        break;
    }
  }

  Future<void> _performLookup(String epc) async {
    final normEpc = normalizeEpc(epc);
    final apiClient = context.read<ApiClient>();
    try {
      final res = await apiClient.lookup(normEpc);
      if (!mounted) return;
      if (res.isAssigned && res.sku != null && res.sku!.isNotEmpty) {
        FeedbackHelper.onWarning();
        _setScanState(ScanState.tagAssigned);
        setState(() {
          _lookupResult = res;
          _currentError = null;
        });
      } else {
        _setScanState(ScanState.waitingSku);
        setState(() {
          _lookupResult = res;
          _currentError = null;
        });
        _open2dScanner();
        _requestSkuFocus();
      }
    } on OfflineException {
      if (!mounted) return;
      _setScanState(ScanState.waitingSku);
      setState(() {
        _lookupResult = LookupResult(status: 'new');
        _currentError = const AppError(
          kind: AppErrorKind.network,
          title: 'Modo sin conexión',
          message: 'Verificando con catálogo local descargado.',
          canRetry: false,
        );
      });
      _open2dScanner();
      _requestSkuFocus();
    } on UnauthorizedException {
      if (!mounted) return;
      _handleUnauthorized();
    } catch (e) {
      if (!mounted) return;
      _setScanState(ScanState.waitingSku);
      setState(() {
        _lookupResult = LookupResult(status: 'new');
        _currentError = mapError(e);
      });
      _open2dScanner();
      _requestSkuFocus();
    }
  }

  void _onAssignedTagConfirmedCorrect() {
    final sku = _lookupResult?.sku;
    if (sku == null || sku.isEmpty) return;
    _currentSku = sku;
    _confirmAndAssign(
      skuOverride: sku,
      isVerified: true,
      reassign: false,
    );
  }

  void _startReassignFlow() {
    setState(() {
      _isReassigning = true;
      _reassignOriginalSku = _lookupResult?.sku;
      _reassignOriginalDesc = _lookupResult?.description;
      _skuController.clear();
      _suggestions = [];
    });
    _setScanState(ScanState.waitingSku);
    _open2dScanner();
    _requestSkuFocus();
  }

  void _requestSkuFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _skuFocusNode.requestFocus();
      }
    });
  }

  void _onSkuInputChanged(String text) {
    _debounceTimer?.cancel();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      if (_suggestions.isNotEmpty) {
        setState(() {
          _suggestions = [];
        });
      }
      return;
    }

    // Auto-detect wedged complete SKU from hardware InfoWedge
    if (RegExp(r'^AF-?\d{6}$', caseSensitive: false).hasMatch(trimmed) ||
        (trimmed.length >= 8 && parseSku(trimmed) != null)) {
      _onSkuSubmitted(trimmed);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 150), () async {
      final syncService = context.read<SyncService>();
      final results = await syncService.searchProducts(trimmed);
      if (mounted) {
        setState(() {
          _suggestions = results;
        });
      }
    });
  }

  Future<void> _onProductSelected(CatalogProduct product) async {
    _debounceTimer?.cancel();
    _skuFocusNode.unfocus();
    final sku = product.sku;
    _skuController.text = sku.replaceAll('AF-', '');
    _suggestions = [];
    _currentError = null;

    await _onSkuSubmitted(sku);
  }

  Future<void> _onSkuSubmitted(String rawInput) async {
    _debounceTimer?.cancel();
    setState(() {
      _suggestions = [];
    });

    final parsed = parseSku(rawInput);
    if (parsed == null) {
      FeedbackHelper.onError();
      setState(() {
        _currentError = const AppError(
          kind: AppErrorKind.validation,
          title: 'Formato inválido',
          message: 'Ese código no es un SKU de activo (AF-000000)',
          canRetry: false,
        );
      });
      return;
    }

    // If confirm sheet is already open with the EXACT same SKU, ignore
    if (_isConfirmSheetOpen && parsed == _currentSku) {
      debugPrint('ScanScreen: ignorando mismo SKU con hoja abierta ($parsed)');
      return;
    }

    final syncService = context.read<SyncService>();
    final product = await syncService.findProductBySku(parsed);

    _currentSku = parsed;
    _currentProduct = product;
    _currentError = null;

    final origSku = _reassignOriginalSku ?? _lookupResult?.sku;
    final origDesc = _reassignOriginalDesc ?? _lookupResult?.description;
    final isOriginalAssigned = _lookupResult?.isAssigned == true || _isReassigning;

    final isSameSku = isOriginalAssigned && origSku != null && origSku == parsed;
    final isDifferentSku = isOriginalAssigned && origSku != null && origSku != parsed;

    final isReassign = isDifferentSku;
    final isReverify = isSameSku;

    final sheetData = ConfirmSheetData(
      epc: _currentEpc,
      sku: _currentSku,
      product: _currentProduct,
      isReverify: isReverify,
      isConflictWarning: false,
      conflictPreviousSku: origSku,
      isReassign: isReassign,
      reassignOriginalSku: origSku,
      reassignOriginalDesc: origDesc,
    );

    // If confirm sheet is already open, replace its contents without opening another sheet
    if (_isConfirmSheetOpen && _confirmSheetNotifier != null) {
      debugPrint('ScanScreen: actualizando ConfirmSheet abierta con nuevo SKU ($parsed)');
      _confirmSheetNotifier!.value = sheetData;
      return;
    }

    await _showConfirmSheet(sheetData);
  }

  Future<void> _showConfirmSheet(ConfirmSheetData initialData) async {
    if (_isConfirmSheetOpen) return;
    _isConfirmSheetOpen = true;
    _setScanState(ScanState.confirm);
    _confirmSheetNotifier = ValueNotifier<ConfirmSheetData>(initialData);
    await _rfidService.stopScan();
    await _rfidService.closeScanner();
    if (!mounted) {
      _isConfirmSheetOpen = false;
      return;
    }

    final confirmed = await ConfirmSheet.show(
      context,
      dataNotifier: _confirmSheetNotifier!,
    );

    _isConfirmSheetOpen = false;
    _confirmSheetNotifier?.dispose();
    _confirmSheetNotifier = null;

    if (!mounted) return;

    if (confirmed == true) {
      final currentData = _confirmSheetNotifier?.value ?? initialData;
      await _confirmAndAssign(
        reassign: currentData.isReassign,
        previousSku: currentData.reassignOriginalSku,
        previousDesc: currentData.reassignOriginalDesc,
      );
    } else {
      // User tapped "Cancelar" / "Cambiar SKU" or dismissed sheet
      _currentSku = '';
      _currentProduct = null;
      _skuController.clear();
      _suggestions = [];
      _setScanState(ScanState.waitingSku);
      _open2dScanner();
      _requestSkuFocus();
    }
  }

  void _handleScanButtonPressed() {
    if (_scannerInitFailed) {
      _openCameraScanner();
    } else {
      _startBarcodeScan();
    }
  }

  Future<void> _openCameraScanner() async {
    _barcodeTimeoutTimer?.cancel();
    if (_isScanningBarcode) {
      _rfidService.stopScan();
      setState(() {
        _isScanningBarcode = false;
      });
    }
    await _rfidService.stopScan();
    await _rfidService.closeScanner();
    if (!mounted) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraScannerScreen()),
    );

    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      _onSkuSubmitted(result);
    } else if (_state == ScanState.waitingSku) {
      _open2dScanner();
    }
  }

  Future<void> _confirmAndAssign({
    String? skuOverride,
    bool? isVerified,
    bool? reassign,
    String? previousSku,
    String? previousDesc,
  }) async {
    _setScanState(ScanState.sending);
    setState(() {
      _currentError = null;
    });

    final targetSku = skuOverride ?? _currentSku;
    final targetEpc = normalizeEpc(_currentEpc);
    final origSku = previousSku ?? _reassignOriginalSku ?? _lookupResult?.sku;
    final origDesc = previousDesc ?? _reassignOriginalDesc ?? _lookupResult?.description;
    final reassignFlag = reassign ?? (_isReassigning && targetSku != _reassignOriginalSku);

    final apiClient = context.read<ApiClient>();
    final queueService = context.read<QueueService>();

    final clientUuid = const Uuid().v4();
    final deviceId = await DeviceHelper.getDeviceId();
    final desc = _currentProduct?.description ??
        (isVerified == true ? _lookupResult?.description : null);

    // 1. Insert ALWAYS before calling API
    await queueService.recordPending(
      epc: targetEpc,
      sku: targetSku,
      clientUuid: clientUuid,
      description: desc,
      deviceId: deviceId,
      reassign: reassignFlag,
      previousSku: origSku,
      previousDescription: origDesc,
    );

    try {
      final assignResult = await apiClient.assign(
        targetEpc,
        targetSku,
        clientUuid,
        deviceId,
        reassign: reassignFlag,
      );

      if (!mounted) return;

      // 2. Response from server -> mark sent with result and message
      final msg = assignResult.message ?? assignResult.description ?? assignResult.currentDescription;
      await queueService.markSent(
        clientUuid,
        result: assignResult.result,
        message: msg,
        description: desc ?? assignResult.description ?? assignResult.currentDescription,
        reassign: assignResult.isReassigned || reassignFlag,
        previousSku: assignResult.previousSku ?? origSku,
        previousDescription: assignResult.previousDescription ?? origDesc,
      );

      _setScanState(ScanState.result);
      setState(() {
        _lastAssignResult = assignResult;
        _lastResultType = assignResult.result;

        if (assignResult.isCreated) {
          FeedbackHelper.onCreated();
        } else if (assignResult.isVerified) {
          FeedbackHelper.onVerified();
        } else if (assignResult.isReassigned) {
          FeedbackHelper.onReassigned();
        } else if (assignResult.isConflict) {
          FeedbackHelper.onConflict();
        } else {
          FeedbackHelper.onError();
        }
      });
    } on OfflineException {
      if (!mounted) return;
      // Without network: already registered as pending
      _setScanState(ScanState.result);
      setState(() {
        _lastResultType = 'queued';
        FeedbackHelper.onQueued();
      });
    } on UnauthorizedException {
      if (!mounted) return;
      _handleUnauthorized();
    } catch (e) {
      if (!mounted) return;
      final appErr = mapError(e);
      await queueService.markFailed(clientUuid, message: appErr.message);
      _setScanState(ScanState.result);
      setState(() {
        _lastResultType = 'error';
        _lastErrorMessage = appErr.message;
        FeedbackHelper.onError();
      });
    }
  }

  void _handleConflictReassign() {
    final conflictPrevSku = _lastAssignResult?.currentSku ??
        _lastAssignResult?.previousSku ??
        _reassignOriginalSku ??
        _lookupResult?.sku;
    final conflictPrevDesc = _lastAssignResult?.currentDescription ??
        _lastAssignResult?.previousDescription ??
        _reassignOriginalDesc ??
        _lookupResult?.description;

    _showConfirmSheet(
      ConfirmSheetData(
        epc: _currentEpc,
        sku: _currentSku,
        product: _currentProduct,
        isReassign: true,
        reassignOriginalSku: conflictPrevSku,
        reassignOriginalDesc: conflictPrevDesc,
      ),
    );
  }

  void _resetToIdle() {
    _debounceTimer?.cancel();
    _barcodeTimeoutTimer?.cancel();
    _isScanningBarcode = false;
    _rfidService.resetBarcodeDedupe();
    _rfidService.stopScan();
    _rfidService.closeScanner();
    if (_isConfirmSheetOpen) {
      Navigator.of(context).pop(false);
    }
    _setScanState(ScanState.idle);
    setState(() {
      _currentEpc = '';
      _lookupResult = null;
      _currentSku = '';
      _currentProduct = null;
      _suggestions = [];
      _lastAssignResult = null;
      _lastResultType = '';
      _lastErrorMessage = null;
      _currentError = null;
      _scannerInitFailed = false;
      _isReassigning = false;
      _reassignOriginalSku = null;
      _reassignOriginalDesc = null;
      _skuController.clear();
    });
  }

  void _handleUnauthorized() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu sesión expiró. Iniciá sesión de nuevo'),
        backgroundColor: AppColors.conflict,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _barcodeTimeoutTimer?.cancel();
    _triggerSub?.cancel();
    _barcodeSub?.cancel();
    _keySub?.cancel();
    _confirmSheetNotifier?.dispose();
    _confirmSheetNotifier = null;
    _rfidService.closeScanner();
    _rfidService.freeReader();
    _rfidService.dispose();
    _skuController.dispose();
    _skuFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueService = context.watch<QueueService>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isConfirmSheetOpen) {
          Navigator.of(context).pop(false);
          return;
        }
        if (_state != ScanState.idle) {
          _resetToIdle();
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Presioná atrás de nuevo para salir'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Image.asset(
          'lib/assets/images/RECOVERY_DARK_TIGHT.png',
          height: 28,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            tooltip: 'Envíos',
            icon: Badge(
              isLabelVisible: queueService.todayCounts.pending > 0,
              label: Text('${queueService.todayCounts.pending}'),
              child: const Icon(Icons.outbox_rounded),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QueueScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Sincronización',
            icon: const Icon(Icons.sync),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SessionStrip(
              created: queueService.todayCounts.created,
              verified: queueService.todayCounts.verified,
              conflict: queueService.todayCounts.conflict,
              pending: queueService.todayCounts.pending,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QueueScreen()),
                );
              },
            ),
            if (queueService.backgroundConflictMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.sm,
                  AppSpace.lg,
                  0,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.conflict.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.conflict.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.conflict,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          queueService.backgroundConflictMessage!,
                          style: AppTypography.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          queueService.clearBackgroundConflict();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const QueueScreen(initialTab: 2),
                            ),
                          );
                        },
                        child: const Text(
                          'Ver',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.conflict,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: AppColors.textSecondary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => queueService.clearBackgroundConflict(),
                      ),
                    ],
                  ),
                ),
              ),
            if (_rfidInitError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.md,
                  AppSpace.lg,
                  0,
                ),
                child: ErrorBanner(
                  error: _rfidInitError!,
                  onRetry: _initRfidReader,
                  onDismiss: () => setState(() => _rfidInitError = null),
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.base,
                reverseDuration: AppMotion.fast,
                switchInCurve: AppMotion.easeOut,
                switchOutCurve: AppMotion.easeOut,
                transitionBuilder: (child, animation) {
                  final disableAnimations =
                      MediaQuery.disableAnimationsOf(context);
                  if (disableAnimations) {
                    return FadeTransition(opacity: animation, child: child);
                  }
                  final slideAnimation = Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(animation);

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: child,
                    ),
                  );
                },
                child: _buildStateContent(context),
              ),
            ),
            if (_state == ScanState.idle || _state == ScanState.reading)
              PrimaryActionBar(
                isReading: _state == ScanState.reading,
                label: _currentError != null ? 'Reintentar' : 'Leer etiqueta',
                icon: _currentError != null ? Icons.refresh : Icons.sensors,
                onPressed: _startReading,
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStateContent(BuildContext context) {
    switch (_state) {
      case ScanState.idle:
      case ScanState.reading:
        return _buildIdleView(context);

      case ScanState.epcShown:
        return _buildEpcShownView(context);

      case ScanState.tagAssigned:
        return _buildTagAssignedView(context);

      case ScanState.waitingSku:
      case ScanState.confirm:
        return _buildWaitingSkuView(context);

      case ScanState.sending:
        return _buildSendingView(context);

      case ScanState.result:
        return _buildResultView(context);
    }
  }

  Widget _buildTagAssignedView(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('tagAssigned'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: AssignedWarningCard(
            epc: _currentEpc,
            sku: _lookupResult?.sku ?? '',
            description: _lookupResult?.description,
            location: _lookupResult?.location,
            assignedBy: _lookupResult?.assignedBy,
            assignedAt: _lookupResult?.assignedAt,
            onCorrect: _onAssignedTagConfirmedCorrect,
            onReassign: _startReassignFlow,
          ),
        ),
      ),
    );
  }

  Widget _buildIdleView(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('idle'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_currentError != null) ...[
                ErrorBanner(
                  error: _currentError!,
                  onRetry: _startReading,
                  onDismiss: () => setState(() => _currentError = null),
                ),
                const SizedBox(height: AppSpace.xl),
              ],
              Icon(
                Icons.nfc_rounded,
                size: 72,
                color: AppColors.brand.withValues(alpha: 0.6),
              ),
              const SizedBox(height: AppSpace.md),
              const Text(
                'Acercá el colector a la etiqueta',
                textAlign: TextAlign.center,
                style: AppTypography.title,
              ),
              const SizedBox(height: AppSpace.xs),
              const Text(
                'Apretá el gatillo para leer la etiqueta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpcShownView(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('epcShown'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          children: [
            TagCard(
              epc: _currentEpc,
              isAssigned: false,
            ),
            const SizedBox(height: AppSpace.xxl),
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.brand,
              backgroundColor: AppColors.brandSoft,
            ),
            const SizedBox(height: AppSpace.md),
            const Text(
              'Consultando estado del EPC en servidor…',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingSkuView(BuildContext context) {
    final isAssigned = _lookupResult?.isAssigned == true;
    final isCollapsed = _skuFocusNode.hasFocus;

    return KeyedSubtree(
      key: const ValueKey('waitingSku'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isReassigning && _reassignOriginalSku != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: AppSpace.md),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        'Reasignando: actualmente $_reassignOriginalSku',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            TagCard(
              epc: _currentEpc,
              isAssigned: isAssigned,
              assignedSku: _lookupResult?.sku,
              assignedDescription: _lookupResult?.description,
              assignedBy: _lookupResult?.assignedBy,
              assignedAt: _lookupResult?.assignedAt,
              isCollapsed: isCollapsed,
            ),
            if (_currentError != null) ...[
              const SizedBox(height: AppSpace.sm),
              ErrorBanner(
                error: _currentError!,
                actionLabel: (_scannerInitFailed ||
                        _currentError!.title == 'Lector de códigos')
                    ? 'Usar cámara'
                    : null,
                onAction: (_scannerInitFailed ||
                        _currentError!.title == 'Lector de códigos')
                    ? _openCameraScanner
                    : null,
                onRetry: _currentError!.canRetry
                    ? (_currentError!.title == 'Lector de códigos'
                        ? (_scannerInitFailed
                            ? () => _open2dScanner()
                            : () => _startBarcodeScan())
                        : () => _performLookup(_currentEpc))
                    : null,
                onDismiss: () => setState(() => _currentError = null),
              ),
            ],
            const SizedBox(height: AppSpace.md),
            SkuInput(
              controller: _skuController,
              focusNode: _skuFocusNode,
              autofocus: true,
              isCameraFallback: _scannerInitFailed,
              isScanning: _isScanningBarcode,
              onChanged: _onSkuInputChanged,
              onSubmitted: _onSkuSubmitted,
              onScanPressed: _handleScanButtonPressed,
              onCameraPressed: _openCameraScanner,
            ),
            const SizedBox(height: AppSpace.sm),
            const Text(
              'Apretá el gatillo o la tecla lateral para escanear el QR',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (_suggestions.isNotEmpty)
              SuggestionList(
                suggestions: _suggestions,
                currentInput: _skuController.text,
                onSelect: _onProductSelected,
              ),
            const SizedBox(height: AppSpace.lg),
            Center(
              child: PressableScale(
                onPressed: _resetToIdle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.lg,
                    vertical: AppSpace.md,
                  ),
                  child: Text(
                    'Cancelar · otra etiqueta',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendingView(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('sending'),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 48,
              width: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                color: AppColors.brand,
              ),
            ),
            SizedBox(height: AppSpace.lg),
            Text(
              'Enviando asignación…',
              style: AppTypography.title,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('result'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: ResultCard(
            resultType: _lastResultType,
            sku: _lastAssignResult?.sku ?? _currentSku,
            description: _lastAssignResult?.description ??
                _currentProduct?.description,
            epc: _currentEpc,
            conflictSku: _lastAssignResult?.previousSku ??
                _lastAssignResult?.currentSku ??
                _reassignOriginalSku,
            conflictDescription: _lastAssignResult?.previousDescription ??
                _lastAssignResult?.currentDescription ??
                _reassignOriginalDesc,
            errorMessage: _lastErrorMessage,
            onDismiss: _resetToIdle,
            onReassign: _lastResultType == 'conflict'
                ? () => _handleConflictReassign()
                : null,
          ),
        ),
      ),
    );
  }
}
