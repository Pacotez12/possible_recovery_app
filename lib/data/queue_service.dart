import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../core/app_error.dart';
import '../core/epc_normalizer.dart';
import '../models/queue_item.dart';
import 'api_client.dart';
import 'local_db.dart';

class SessionCounts {
  final int created;
  final int verified;
  final int conflict;
  final int pending;

  const SessionCounts({
    this.created = 0,
    this.verified = 0,
    this.conflict = 0,
    this.pending = 0,
  });
}

class QueueService extends ChangeNotifier {
  final ApiClient apiClient;
  final LocalDb localDb;
  final Connectivity _connectivity;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isFlushing = false;
  bool get isFlushing => _isFlushing;

  SessionCounts _todayCounts = const SessionCounts();
  SessionCounts get todayCounts => _todayCounts;

  String? _backgroundConflictMessage;
  String? get backgroundConflictMessage => _backgroundConflictMessage;

  bool _isUsingLocalFallback = false;
  bool get isUsingLocalFallback => _isUsingLocalFallback;

  bool _disposed = false;

  QueueService({
    required this.apiClient,
    required this.localDb,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity() {
    _initListeners();
    refreshCounts();
  }

  void _initListeners() {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      flush();
    });

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        flush();
      }
    });
  }

  void clearBackgroundConflict() {
    _backgroundConflictMessage = null;
    notifyListeners();
  }

  Future<void> refreshCounts([DateTime? date]) async {
    try {
      final counts = await localDb.getTodayCounts(date: date);
      if (_disposed) return;
      _todayCounts = SessionCounts(
        created: counts['created'] ?? 0,
        verified: counts['verified'] ?? 0,
        conflict: counts['conflict'] ?? 0,
        pending: counts['pending'] ?? 0,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('QueueService refreshCounts error: $e');
    }
  }

  Future<QueueItem> recordPending({
    required String epc,
    required String sku,
    required String clientUuid,
    String? description,
    String? deviceId,
    bool reassign = false,
    String? previousSku,
    String? previousDescription,
  }) async {
    final normEpc = normalizeEpc(epc);
    final item = QueueItem(
      clientUuid: clientUuid,
      epc: normEpc,
      sku: sku.toUpperCase().trim(),
      description: description,
      previousSku: previousSku,
      previousDescription: previousDescription,
      deviceId: deviceId,
      createdAt: DateTime.now().toIso8601String(),
      status: 'pending',
      reassign: reassign,
      source: 'local',
    );

    await localDb.insertQueueItem(item);
    await refreshCounts();
    return item;
  }

  Future<void> markSent(
    String clientUuid, {
    required String result,
    String? message,
    String? description,
    bool? reassign,
    String? previousSku,
    String? previousDescription,
  }) async {
    await localDb.updateQueueItem(
      clientUuid,
      status: 'sent',
      result: result,
      message: message,
      description: description,
      reassign: reassign,
      previousSku: previousSku,
      previousDescription: previousDescription,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await refreshCounts();
  }

  Future<void> markFailed(
    String clientUuid, {
    required String message,
  }) async {
    await localDb.updateQueueItem(
      clientUuid,
      status: 'failed',
      message: message,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await refreshCounts();
  }

  Future<void> enqueue({
    required String epc,
    required String sku,
    required String clientUuid,
    String? description,
    String? deviceId,
    bool reassign = false,
    String? previousSku,
    String? previousDescription,
  }) async {
    await recordPending(
      epc: epc,
      sku: sku,
      clientUuid: clientUuid,
      description: description,
      deviceId: deviceId,
      reassign: reassign,
      previousSku: previousSku,
      previousDescription: previousDescription,
    );
    flush();
  }

  Future<void> flush() async {
    if (_isFlushing) return;
    _isFlushing = true;
    notifyListeners();

    try {
      final pending = await localDb.getPendingQueue();
      for (final item in pending) {
        try {
          final res = await apiClient.assign(
            item.epc,
            item.sku,
            item.clientUuid,
            item.deviceId,
            reassign: item.reassign,
          );

          await localDb.updateQueueItem(
            item.clientUuid,
            status: 'sent',
            result: res.result,
            message: res.message ?? res.description ?? res.currentDescription,
            description: item.description ?? res.description ?? res.currentDescription,
            reassign: res.isReassigned || item.reassign,
            previousSku: res.previousSku ?? item.previousSku,
            previousDescription: res.previousDescription ?? item.previousDescription,
          );

          if (res.isConflict || res.isRejected) {
            _backgroundConflictMessage =
                'Una etiqueta enviada sin conexión volvió con conflicto';
          }
        } on OfflineException {
          // Still offline, stop trying current batch
          break;
        } on UnauthorizedException {
          // Auth problem, stop flush
          break;
        } catch (e) {
          final appErr = mapError(e);
          await localDb.updateQueueItem(
            item.clientUuid,
            status: 'failed',
            message: appErr.message,
          );
        }
      }
    } finally {
      _isFlushing = false;
      await refreshCounts();
    }
  }

  Future<bool> syncHistoryWithServer({String? since}) async {
    final now = DateTime.now();
    final todayStr = since ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      final serverItems = await apiClient.getHistory(since: todayStr);
      final normalizedItems = serverItems
          .map((item) => item.copyWith(epc: normalizeEpc(item.epc)))
          .toList();
      _isUsingLocalFallback = false;
      await localDb.upsertServerItems(normalizedItems);
      await refreshCounts();
      return true;
    } catch (e) {
      debugPrint('QueueService syncHistoryWithServer fallback to local: $e');
      _isUsingLocalFallback = true;
      await refreshCounts();
      return false;
    }
  }

  Future<void> retryItem(QueueItem item) async {
    await localDb.updateQueueItem(
      item.clientUuid,
      status: 'pending',
      result: null,
      message: null,
    );
    await refreshCounts();
    flush();
  }

  Future<void> deleteItem(String clientUuid) async {
    await localDb.deleteQueueItem(clientUuid);
    await refreshCounts();
  }

  Future<List<QueueItem>> getTodayItems({DateTime? date}) async {
    return await localDb.getTodayQueue(date: date);
  }

  Future<List<QueueItem>> getPendingItems() async {
    return await localDb.getPendingQueue();
  }

  Future<List<QueueItem>> getProblemItems() async {
    return await localDb.getProblemQueue();
  }

  Future<List<QueueItem>> getAllItems() async {
    return await localDb.getAllQueue();
  }

  Future<int> getPendingCount() async {
    return await localDb.getPendingQueueCount();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
