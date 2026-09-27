import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_error.dart';
import '../../data/queue_service.dart';
import '../../models/queue_item.dart';
import '../theme/tokens.dart';
import '../widgets/epc_text.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/session_strip.dart';

class QueueScreen extends StatefulWidget {
  final int initialTab;

  const QueueScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  late int _selectedTab; // 0: Hoy, 1: Pendientes, 2: Con problemas
  List<QueueItem> _todayItems = [];
  List<QueueItem> _pendingItems = [];
  List<QueueItem> _problemItems = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);
    await _loadFromLocal();
    if (mounted) {
      setState(() => _isLoading = false);
    }
    await _syncWithServer();
  }

  Future<void> _loadFromLocal() async {
    final queueService = context.read<QueueService>();
    final today = await queueService.getTodayItems();
    final pending = await queueService.getPendingItems();
    final problems = await queueService.getProblemItems();

    if (mounted) {
      setState(() {
        _todayItems = today;
        _pendingItems = pending;
        _problemItems = problems;
      });
    }
  }

  Future<void> _syncWithServer() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    final queueService = context.read<QueueService>();
    await queueService.syncHistoryWithServer();
    await _loadFromLocal();
    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _flushPending() async {
    final queueService = context.read<QueueService>();
    await queueService.flush();
    await _loadFromLocal();
  }

  Future<void> _retryItem(QueueItem item) async {
    final queueService = context.read<QueueService>();
    await queueService.retryItem(item);
    await _loadFromLocal();
  }

  Future<void> _deleteItem(QueueItem item) async {
    final queueService = context.read<QueueService>();
    await queueService.deleteItem(item.clientUuid);
    await _loadFromLocal();
  }

  String _formatRelativeTime(String createdAt) {
    final date = DateTime.tryParse(createdAt)?.toLocal();
    if (date == null) return createdAt;
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  String _formatFullDate(String createdAt) {
    final date = DateTime.tryParse(createdAt)?.toLocal();
    if (date == null) return createdAt;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  String? _formatItemMessage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.contains('Exception') || raw.contains('DioException')) {
      return mapError(raw).message;
    }
    return raw;
  }

  void _showDetailSheet(QueueItem item) {
    final msg = _formatItemMessage(item.message);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.xs,
              AppSpace.lg,
              AppSpace.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: item.statusColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: item.statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: item.statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatRelativeTime(item.createdAt),
                      style: AppTypography.body.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  item.sku,
                  style: AppTypography.display,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  item.description ?? 'Producto sin descripción',
                  style: AppTypography.title.copyWith(
                    fontSize: 16,
                    color: item.description != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: AppSpace.md),
                _buildDetailRow(
                  'EPC',
                  EpcText(
                    item.epc,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                _buildDetailRow(
                  'Fecha',
                  Text(
                    _formatFullDate(item.createdAt),
                    style: AppTypography.body.copyWith(fontSize: 13),
                  ),
                ),
                if (item.deviceId != null && item.deviceId!.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.sm),
                  _buildDetailRow(
                    'Dispositivo',
                    Text(
                      item.deviceId!,
                      style: AppTypography.body.copyWith(fontSize: 13),
                    ),
                  ),
                ],
                if (item.isReassigned || (item.previousSku != null && item.previousSku!.isNotEmpty)) ...[
                  const SizedBox(height: AppSpace.sm),
                  _buildDetailRow(
                    'Reasignación',
                    Text(
                      'De ${item.previousSku ?? "previo"} a ${item.sku}',
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.reassigned,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.sm),
                _buildDetailRow(
                  'Origen',
                  Text(
                    item.source == 'server' ? 'Servidor' : 'Colector (local)',
                    style: AppTypography.body.copyWith(fontSize: 13),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                _buildDetailRow(
                  'UUID',
                  Text(
                    item.clientUuid.length > 18
                        ? '${item.clientUuid.substring(0, 8)}...${item.clientUuid.substring(item.clientUuid.length - 8)}'
                        : item.clientUuid,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (msg != null && msg.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: BoxDecoration(
                      color: item.statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: item.statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.isProblem
                              ? Icons.error_outline_rounded
                              : Icons.info_outline_rounded,
                          size: 18,
                          color: item.statusColor,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                            msg,
                            style: AppTypography.body.copyWith(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (item.isPending || item.isFailed) ...[
                  const SizedBox(height: AppSpace.lg),
                  PressableScale(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _retryItem(item);
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Reintentar envío',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  PressableScale(
                    onPressed: () => _confirmDeleteDialog(ctx, item),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      child: const Text(
                        'Eliminar envío',
                        style: TextStyle(
                          color: AppColors.conflict,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: AppTypography.label.copyWith(fontSize: 12),
          ),
        ),
        Expanded(child: value),
      ],
    );
  }

  void _confirmDeleteDialog(BuildContext bottomSheetContext, QueueItem item) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('¿Eliminar este envío?'),
        content: const Text(
          'Se eliminará de la lista de envíos. Si no se había sincronizado con el servidor, no quedará registrado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              Navigator.of(bottomSheetContext).pop();
              _deleteItem(item);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.conflict),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queueService = context.watch<QueueService>();
    final counts = queueService.todayCounts;
    final isFlushing = queueService.isFlushing;

    final currentList = switch (_selectedTab) {
      0 => _todayItems,
      1 => _pendingItems,
      2 => _problemItems,
      _ => _todayItems,
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Envíos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar historial',
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isSyncing ? null : _syncWithServer,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SessionStrip(
              created: counts.created,
              verified: counts.verified,
              conflict: counts.conflict,
              pending: counts.pending,
            ),
            if (queueService.isUsingLocalFallback)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: 6,
                ),
                color: AppColors.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      'Mostrando datos del colector',
                      style: AppTypography.body.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            // 3-tab segmented control
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.md,
                AppSpace.lg,
                AppSpace.sm,
              ),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildTabButton(0, 'Hoy (${_todayItems.length})'),
                    _buildTabButton(1, 'Pendientes (${_pendingItems.length})'),
                    _buildTabButton(2, 'Con problemas (${_problemItems.length})'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    )
                  : RefreshIndicator(
                      onRefresh: _syncWithServer,
                      color: AppColors.brand,
                      child: currentList.isEmpty
                          ? _buildEmptyState(_selectedTab)
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpace.lg),
                              itemCount: currentList.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = currentList[index];
                                return _buildRow(item);
                              },
                            ),
                    ),
            ),
            if (_selectedTab == 1 && _pendingItems.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: PressableScale(
                    onPressed: isFlushing ? null : _flushPending,
                    enabled: !isFlushing,
                    child: Container(
                      height: AppSize.primaryButton,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: isFlushing
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Reintentar envíos pendientes',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
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

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(QueueItem item) {
    final relTime = _formatRelativeTime(item.createdAt);

    return PressableScale(
      onPressed: () => _showDetailSheet(item),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Línea 1: punto+estado a la izquierda y hora relativa + chevron a la derecha
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.statusColor,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      relTime,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Línea 2: SKU en negrita 20sp
            Text(
              item.sku,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (item.isReassigned || (item.previousSku != null && item.previousSku!.isNotEmpty)) ...[
              const SizedBox(height: 2),
              Text(
                'De ${item.previousSku ?? "previo"} a ${item.sku}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.reassigned,
                ),
              ),
            ],

            // Línea 3: descripción (máx 2 líneas, esta sí puede ellipsis)
            if (item.description != null && item.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Línea 4: EPC completo con EpcText (monospace 14sp, 2 líneas de 4 bloques si es de 32)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
              child: EpcText(
                item.epc,
                style: AppTypography.epc.copyWith(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(int tabIndex) {
    final (icon, message) = switch (tabIndex) {
      0 => (Icons.history_rounded, 'Todavía no enviaste etiquetas hoy'),
      1 => (Icons.check_circle_outline_rounded, 'No hay nada pendiente'),
      2 => (Icons.shield_outlined, 'Sin problemas'),
      _ => (Icons.inbox_outlined, 'Lista vacía'),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 52,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
