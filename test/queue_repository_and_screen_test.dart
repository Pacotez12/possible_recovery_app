import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/data/api_client.dart';
import 'package:possible_recovery/data/local_db.dart';
import 'package:possible_recovery/data/queue_service.dart';
import 'package:possible_recovery/models/queue_item.dart';
import 'package:possible_recovery/ui/screens/queue_screen.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeQueueService extends ChangeNotifier implements QueueService {
  @override
  SessionCounts todayCounts = const SessionCounts();

  @override
  bool isUsingLocalFallback = false;

  @override
  bool isFlushing = false;

  @override
  String? backgroundConflictMessage;

  List<QueueItem> todayItems = [];
  List<QueueItem> pendingItems = [];
  List<QueueItem> problemItems = [];

  @override
  Future<List<QueueItem>> getTodayItems({DateTime? date}) async => todayItems;

  @override
  Future<List<QueueItem>> getPendingItems() async => pendingItems;

  @override
  Future<List<QueueItem>> getProblemItems() async => problemItems;

  @override
  Future<List<QueueItem>> getAllItems() async => [...todayItems, ...pendingItems, ...problemItems];

  @override
  Future<int> getPendingCount() async => pendingItems.length;

  @override
  Future<bool> syncHistoryWithServer({String? since}) async => true;

  @override
  Future<void> flush() async {}

  @override
  Future<void> retryItem(QueueItem item) async {}

  @override
  Future<void> deleteItem(String clientUuid) async {}

  @override
  void clearBackgroundConflict() {}

  @override
  Future<QueueItem> recordPending({
    required String epc,
    required String sku,
    required String clientUuid,
    String? description,
    String? deviceId,
    bool reassign = false,
    String? previousSku,
    String? previousDescription,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> markSent(
    String clientUuid, {
    required String result,
    String? message,
    String? description,
    bool? reassign,
    String? previousSku,
    String? previousDescription,
  }) async {}

  @override
  Future<void> markFailed(
    String clientUuid, {
    required String message,
  }) async {}

  @override
  Future<void> refreshCounts([DateTime? date]) async {}

  @override
  ApiClient get apiClient => throw UnimplementedError();

  @override
  LocalDb get localDb => throw UnimplementedError();

  @override
  Future<void> enqueue({
    required String epc,
    required String sku,
    required String clientUuid,
    String? description,
    String? deviceId,
    bool reassign = false,
    String? previousSku,
    String? previousDescription,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LocalDb and QueueRepository unit tests', () {
    late LocalDb localDb;

    setUp(() async {
      localDb = LocalDb(customPath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await localDb.close();
    });

    test('insert before sending records pending item with client_uuid', () async {
      final item = QueueItem(
        clientUuid: 'test-uuid-1',
        epc: '309373E167B0610BDCE43394',
        sku: 'AF-012917',
        description: 'Pelota Oficial Conmebol',
        deviceId: 'device-test',
        createdAt: DateTime.now().toIso8601String(),
        status: 'pending',
        source: 'local',
      );

      await localDb.insertQueueItem(item);

      final pending = await localDb.getPendingQueue();
      expect(pending.length, 1);
      expect(pending.first.clientUuid, 'test-uuid-1');
      expect(pending.first.status, 'pending');
      expect(pending.first.source, 'local');
      expect(pending.first.description, 'Pelota Oficial Conmebol');
    });

    test('transition from pending to sent updates result and message', () async {
      final item = QueueItem(
        clientUuid: 'test-uuid-2',
        epc: '309373E167B0610BDCE43394',
        sku: 'AF-012917',
        createdAt: DateTime.now().toIso8601String(),
        status: 'pending',
      );
      await localDb.insertQueueItem(item);

      await localDb.updateQueueItem(
        'test-uuid-2',
        status: 'sent',
        result: 'created',
        message: 'Etiqueta asignada con éxito',
      );

      final all = await localDb.getAllQueue();
      expect(all.length, 1);
      expect(all.first.clientUuid, 'test-uuid-2');
      expect(all.first.status, 'sent');
      expect(all.first.result, 'created');
      expect(all.first.message, 'Etiqueta asignada con éxito');
    });

    test('transition from pending to failed updates status and message', () async {
      final item = QueueItem(
        clientUuid: 'test-uuid-3',
        epc: '309373E167B0610BDCE43394',
        sku: 'AF-012917',
        createdAt: DateTime.now().toIso8601String(),
        status: 'pending',
      );
      await localDb.insertQueueItem(item);

      await localDb.updateQueueItem(
        'test-uuid-3',
        status: 'failed',
        message: 'No se pudo conectar con el servidor',
      );

      final problems = await localDb.getProblemQueue();
      expect(problems.length, 1);
      expect(problems.first.status, 'failed');
      expect(problems.first.message, 'No se pudo conectar con el servidor');
    });

    test('upsertServerItems does not duplicate by client_uuid and preserves local description', () async {
      final localItem = QueueItem(
        clientUuid: 'test-uuid-4',
        epc: '309373E167B0610BDCE43394',
        sku: 'AF-012917',
        description: 'Descripción local conocida',
        createdAt: DateTime.now().toIso8601String(),
        status: 'pending',
        source: 'local',
      );
      await localDb.insertQueueItem(localItem);

      // Server returns history for same client_uuid without description
      final serverItem = QueueItem(
        clientUuid: 'test-uuid-4',
        epc: '309373E167B0610BDCE43394',
        sku: 'AF-012917',
        description: null,
        createdAt: DateTime.now().toIso8601String(),
        status: 'sent',
        result: 'created',
        source: 'server',
      );

      await localDb.upsertServerItems([serverItem]);

      final all = await localDb.getAllQueue();
      expect(all.length, 1);
      expect(all.first.clientUuid, 'test-uuid-4');
      expect(all.first.status, 'sent');
      expect(all.first.result, 'created');
      expect(all.first.source, 'server');
      expect(all.first.description, 'Descripción local conocida');
    });

    test('upsertServerItems deduplicates by EPC when server client_uuid is empty and preserves local info', () async {
      final localItem = QueueItem(
        clientUuid: 'local-uuid-unique',
        epc: '309373E167B0610BDCE43394',
        sku: 'AF-012917',
        description: 'Pelota Oficial Conmebol',
        deviceId: 'C72-DEVICE',
        message: 'Mensaje local',
        createdAt: DateTime.now().toIso8601String(),
        status: 'pending',
        source: 'local',
      );
      await localDb.insertQueueItem(localItem);

      // Backend mínimo sends client_uuid: null, description: null, device_id: null, message: null
      final serverItem = QueueItem(
        clientUuid: '',
        epc: '309373E167B0610BDCE43394',
        sku: 'AF-012917',
        description: null,
        deviceId: null,
        message: null,
        createdAt: DateTime.now().toIso8601String(),
        status: 'sent',
        result: 'created',
        source: 'server',
      );

      await localDb.upsertServerItems([serverItem]);

      final all = await localDb.getAllQueue();
      // NO duplicate row!
      expect(all.length, 1);
      // Local record data has priority and is preserved
      expect(all.first.clientUuid, 'local-uuid-unique');
      expect(all.first.description, 'Pelota Oficial Conmebol');
      expect(all.first.deviceId, 'C72-DEVICE');
      expect(all.first.message, 'Mensaje local');
      // Server update reflects in status and result
      expect(all.first.status, 'sent');
      expect(all.first.result, 'created');
    });

    test('upsertServerItems inserts new server item with server-EPC id when no local record exists', () async {
      final serverItem = QueueItem(
        clientUuid: '',
        epc: '30C2F1FEA18BC110CE23B02400000000',
        sku: 'AF-012918',
        description: null,
        createdAt: DateTime.now().toIso8601String(),
        status: 'sent',
        result: 'reassigned',
        reassign: true,
        source: 'server',
      );

      await localDb.upsertServerItems([serverItem]);

      final all = await localDb.getAllQueue();
      expect(all.length, 1);
      expect(all.first.clientUuid, 'server-30C2F1FEA18BC110CE23B02400000000');
      expect(all.first.epc, '30C2F1FEA18BC110CE23B02400000000');
      expect(all.first.sku, 'AF-012918');
      expect(all.first.isReassigned, isTrue);
    });

    test('upsertServerItems deduplicates multiple server items with same EPC in same payload', () async {
      final item1 = QueueItem(
        clientUuid: '',
        epc: '309373E167B0610BDCE43394',
        sku: 'AF-012917',
        createdAt: DateTime.now().toIso8601String(),
        status: 'sent',
        result: 'created',
      );
      final item2 = QueueItem(
        clientUuid: '',
        epc: '309373E167B0610BDCE43394',
        sku: 'AF-012918',
        createdAt: DateTime.now().toIso8601String(),
        status: 'sent',
        result: 'reassigned',
        reassign: true,
      );

      await localDb.upsertServerItems([item1, item2]);

      final all = await localDb.getAllQueue();
      expect(all.length, 1);
      expect(all.first.sku, 'AF-012918');
      expect(all.first.isReassigned, isTrue);
    });

    test('getTodayCounts calculates counts for today and ignores past days', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      // Today created
      await localDb.insertQueueItem(
        QueueItem(
          clientUuid: 't1',
          epc: 'EPC1',
          sku: 'AF-000001',
          createdAt: now.toIso8601String(),
          status: 'sent',
          result: 'created',
        ),
      );
      // Today verified
      await localDb.insertQueueItem(
        QueueItem(
          clientUuid: 't2',
          epc: 'EPC2',
          sku: 'AF-000002',
          createdAt: now.toIso8601String(),
          status: 'sent',
          result: 'verified',
        ),
      );
      // Today conflict
      await localDb.insertQueueItem(
        QueueItem(
          clientUuid: 't3',
          epc: 'EPC3',
          sku: 'AF-000003',
          createdAt: now.toIso8601String(),
          status: 'sent',
          result: 'conflict',
        ),
      );
      // Today pending
      await localDb.insertQueueItem(
        QueueItem(
          clientUuid: 't4',
          epc: 'EPC4',
          sku: 'AF-000004',
          createdAt: now.toIso8601String(),
          status: 'pending',
        ),
      );
      // Yesterday created (should NOT count in today's created)
      await localDb.insertQueueItem(
        QueueItem(
          clientUuid: 'y1',
          epc: 'EPC5',
          sku: 'AF-000005',
          createdAt: yesterday.toIso8601String(),
          status: 'sent',
          result: 'created',
        ),
      );

      final counts = await localDb.getTodayCounts(date: now);
      expect(counts['created'], 1);
      expect(counts['verified'], 1);
      expect(counts['conflict'], 1);
      expect(counts['pending'], 1);
    });

    test('reassign fields are persisted and getTodayCounts counts reassigned in created', () async {
      final now = DateTime.now();
      final item = QueueItem(
        clientUuid: 'reassign-uuid-1',
        epc: '30C2F1FEA18BC110CE23B02400000000',
        sku: 'AF-012918',
        description: 'Laptop Dell',
        previousSku: 'AF-012917',
        previousDescription: 'Pelota Oficial Conmebol',
        reassign: true,
        createdAt: now.toIso8601String(),
        status: 'pending',
      );

      await localDb.insertQueueItem(item);

      var pending = await localDb.getPendingQueue();
      expect(pending.first.reassign, isTrue);
      expect(pending.first.previousSku, 'AF-012917');
      expect(pending.first.previousDescription, 'Pelota Oficial Conmebol');

      await localDb.updateQueueItem(
        'reassign-uuid-1',
        status: 'sent',
        result: 'reassigned',
        reassign: true,
        previousSku: 'AF-012917',
        previousDescription: 'Pelota Oficial Conmebol',
      );

      final all = await localDb.getAllQueue();
      expect(all.first.isReassigned, isTrue);
      expect(all.first.statusLabel, 'Reasignada');
      expect(all.first.previousSku, 'AF-012917');

      final counts = await localDb.getTodayCounts(date: now);
      // Reassigned items are counted inside 'created' for session summary
      expect(counts['created'], 1);
    });
  });

  group('QueueScreen widget tests', () {
    late FakeQueueService fakeQueueService;

    setUp(() {
      fakeQueueService = FakeQueueService();
    });

    tearDown(() {
      fakeQueueService.dispose();
    });

    testWidgets('renders empty state for each tab', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<QueueService>.value(value: fakeQueueService),
          ],
          child: const MaterialApp(
            home: QueueScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 0: Hoy
      expect(find.text('Envíos'), findsOneWidget);
      expect(find.text('Todavía no enviaste etiquetas hoy'), findsOneWidget);

      // Tap Tab 1: Pendientes
      await tester.tap(find.text('Pendientes (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No hay nada pendiente'), findsOneWidget);

      // Tap Tab 2: Con problemas
      await tester.tap(find.text('Con problemas (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Sin problemas'), findsOneWidget);
    });

    testWidgets('renders populated stacked row and opens detail bottom sheet on tap',
        (tester) async {
      final now = DateTime.now();
      final item = QueueItem(
        clientUuid: 'client-uuid-1234567890',
        epc: '309373E167B0610BDCE43394',
        sku: 'AF-012918',
        description: 'Telefonos J139 IP Avaya',
        deviceId: 'C72-DEVICE',
        createdAt: now.toIso8601String(),
        status: 'sent',
        result: 'created',
        message: 'Asignado correctamente',
      );
      fakeQueueService.todayItems = [item];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<QueueService>.value(value: fakeQueueService),
          ],
          child: const MaterialApp(
            home: QueueScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Row elements visible in list
      expect(find.text('AF-012918'), findsOneWidget);
      expect(find.text('Asignada'), findsOneWidget);
      expect(find.text('Telefonos J139 IP Avaya'), findsOneWidget);
      expect(
        find.text('3093\u200973E1\u200967B0\u2009610B\u2009DCE4\u20093394'),
        findsOneWidget,
      );

      // Tap the row to open detail bottom sheet
      await tester.tap(find.text('AF-012918'));
      await tester.pumpAndSettle();

      // Detail sheet contents
      expect(find.text('EPC'), findsOneWidget);
      expect(find.text('Fecha'), findsOneWidget);
      expect(find.text('Dispositivo'), findsOneWidget);
      expect(find.text('C72-DEVICE'), findsOneWidget);
      expect(find.text('Asignado correctamente'), findsOneWidget);
    });

    testWidgets('renders 32-char full EPC in stacked row without ellipsis',
        (tester) async {
      final now = DateTime.now();
      final item = QueueItem(
        clientUuid: 'client-uuid-32char',
        epc: '30C2F1FEA18BC110CE23B02400000000',
        sku: 'AF-012917',
        description: 'Telefonos J139 IP con Licencia Avaya Endpoint',
        createdAt: now.toIso8601String(),
        status: 'sent',
        result: 'created',
      );
      fakeQueueService.todayItems = [item];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<QueueService>.value(value: fakeQueueService),
          ],
          child: const MaterialApp(
            home: QueueScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AF-012917'), findsOneWidget);
      expect(
        find.text(
          '30C2\u2009F1FE\u2009A18B\u2009C110\nCE23\u2009B024\u20090000\u20090000',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders reassigned item and displays De AF-XXXXX a AF-YYYYY in detail sheet',
        (tester) async {
      final now = DateTime.now();
      final item = QueueItem(
        clientUuid: 'client-uuid-reassigned',
        epc: '30C2F1FEA18BC110CE23B02400000000',
        sku: 'AF-012918',
        description: 'Telefonos J139 IP con Licencia Avaya Endpoint',
        previousSku: 'AF-012917',
        previousDescription: 'Pelota Oficial Conmebol',
        reassign: true,
        createdAt: now.toIso8601String(),
        status: 'sent',
        result: 'reassigned',
      );
      fakeQueueService.todayItems = [item];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<QueueService>.value(value: fakeQueueService),
          ],
          child: const MaterialApp(
            home: QueueScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AF-012918'), findsOneWidget);
      expect(find.text('Reasignada'), findsOneWidget);

      await tester.tap(find.text('AF-012918'));
      await tester.pumpAndSettle();

      expect(find.text('Reasignación'), findsOneWidget);
      // Appears in both list row and open detail sheet
      expect(find.text('De AF-012917 a AF-012918'), findsNWidgets(2));
    });
  });
}
