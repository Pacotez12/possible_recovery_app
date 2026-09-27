import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_error.dart';
import '../../data/queue_service.dart';
import '../../data/sync_service.dart';
import '../theme/tokens.dart';
import '../widgets/error_banner.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/session_strip.dart';
import 'queue_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class SyncScreen extends StatefulWidget {
  final bool initialSyncPrompt;

  const SyncScreen({super.key, this.initialSyncPrompt = false});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  int _localCount = 0;
  DateTime? _lastSyncTime;
  bool _isLoadingInfo = true;
  String? _successMessage;
  AppError? _syncError;

  @override
  void initState() {
    super.initState();
    _refreshInfo();
  }

  Future<void> _refreshInfo() async {
    final syncService = context.read<SyncService>();
    final count = await syncService.getLocalCount();
    final lastTime = await syncService.getLastSyncTime();

    if (mounted) {
      setState(() {
        _localCount = count;
        _lastSyncTime = lastTime;
        _isLoadingInfo = false;
      });
    }
  }

  String _formatRelativeTime(DateTime? time) {
    if (time == null) return 'nunca';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  Future<void> _performSync() async {
    final syncService = context.read<SyncService>();
    setState(() {
      _syncError = null;
      _successMessage = null;
    });

    try {
      final total = await syncService.syncCatalog();
      if (!mounted) return;
      setState(() {
        _syncError = null;
        _successMessage = 'Sincronización exitosa: $total productos descargados.';
      });
      await _refreshInfo();

      // On success auto-continue to scan after 800 ms
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      if (widget.initialSyncPrompt) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      final lastSyncStr = _lastSyncTime != null
          ? _formatRelativeTime(_lastSyncTime)
          : 'la instalación';

      setState(() {
        _syncError = AppError(
          kind: AppErrorKind.network,
          title: 'Error de sincronización',
          message:
              'No se pudo actualizar el catálogo. Seguís trabajando con el de $lastSyncStr.',
          canRetry: true,
          technicalDetail: e.toString(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();
    final queueService = context.watch<QueueService>();
    final isSyncing = syncService.isSyncing;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: widget.initialSyncPrompt
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Image.asset(
          'lib/assets/images/RECOVERY_DARK_TIGHT.png',
          height: 28,
          fit: BoxFit.contain,
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Cola offline',
                icon: const Icon(Icons.outbox_rounded),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QueueScreen()),
                  );
                },
              ),
              FutureBuilder<int>(
                future: queueService.getPendingCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.pending,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
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
            FutureBuilder<int>(
              future: queueService.getPendingCount(),
              builder: (context, snapshot) {
                return SessionStrip(
                  created: 0,
                  verified: 0,
                  conflict: 0,
                  pending: snapshot.data ?? 0,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QueueScreen()),
                    );
                  },
                );
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.initialSyncPrompt && _localCount == 0) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpace.md),
                        decoration: BoxDecoration(
                          color: AppColors.verified.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.verified.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.verified,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            const Expanded(
                              child: Text(
                                'Es necesario sincronizar el catálogo de productos antes de comenzar el escaneo.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                    ],
                    Container(
                      padding: const EdgeInsets.all(AppSpace.xl),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.cloud_sync_outlined,
                            size: 48,
                            color: AppColors.brand,
                          ),
                          const SizedBox(height: AppSpace.md),
                          _isLoadingInfo
                              ? const SizedBox(
                                  height: 48,
                                  width: 48,
                                  child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 3),
                                  ),
                                )
                              : Text(
                                  '$_localCount',
                                  style: AppTypography.display.copyWith(
                                    fontSize: 48,
                                    color: AppColors.brand,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                          const SizedBox(height: AppSpace.xs),
                          const Text(
                            'productos en el colector',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpace.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpace.xs),
                              Text(
                                'Última sincronización: ${_formatRelativeTime(_lastSyncTime)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (isSyncing) ...[
                            const SizedBox(height: AppSpace.lg),
                            const LinearProgressIndicator(
                              minHeight: 4,
                              color: AppColors.brand,
                              backgroundColor: AppColors.brandSoft,
                            ),
                            const SizedBox(height: AppSpace.sm),
                            const Text(
                              'Descargando catálogo…',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_syncError != null) ...[
                      const SizedBox(height: AppSpace.md),
                      ErrorBanner(
                        error: _syncError!,
                        onRetry: isSyncing ? null : _performSync,
                        onDismiss: () => setState(() => _syncError = null),
                      ),
                    ] else if (_successMessage != null) ...[
                      const SizedBox(height: AppSpace.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpace.md),
                        decoration: BoxDecoration(
                          color: AppColors.created.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.created.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.created,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(
                                  color: AppColors.created,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    PressableScale(
                      onPressed: isSyncing ? null : _performSync,
                      enabled: !isSyncing,
                      child: Container(
                        height: AppSize.primaryButton,
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isSyncing ? 'Sincronizando…' : 'Sincronizar ahora',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (_localCount > 0) ...[
                      const SizedBox(height: AppSpace.md),
                      PressableScale(
                        onPressed: isSyncing
                            ? null
                            : () {
                                if (widget.initialSyncPrompt) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const ScanScreen(),
                                    ),
                                  );
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                        child: Container(
                          height: AppSize.touch,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Continuar al escaneo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
