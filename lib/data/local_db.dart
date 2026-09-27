import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../core/sku_ranking.dart';
import '../core/text_normalizer.dart';
import '../models/catalog_product.dart';
import '../models/queue_item.dart';

class LocalDb {
  static const String dbName = 'possible_recovery.db';
  static const int dbVersion = 4;

  final String? customPath;
  Database? _database;

  LocalDb({this.customPath});

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final String path;
    if (customPath != null) {
      path = customPath!;
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, dbName);
    }
    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER,
        sku TEXT UNIQUE,
        description TEXT,
        location TEXT,
        description_norm TEXT
      );
    ''');
    await db.execute('CREATE INDEX idx_products_sku ON products(sku);');
    await db.execute('CREATE INDEX idx_products_desc_norm ON products(description_norm);');

    await db.execute('''
      CREATE TABLE queue (
        client_uuid TEXT PRIMARY KEY,
        epc TEXT NOT NULL,
        sku TEXT NOT NULL,
        description TEXT,
        previous_sku TEXT,
        previous_description TEXT,
        device_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        status TEXT NOT NULL,
        result TEXT,
        message TEXT,
        reassign INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'local'
      );
    ''');
    await db.execute('CREATE INDEX idx_queue_status ON queue(status);');
    await db.execute('CREATE INDEX idx_queue_created_at ON queue(created_at);');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN description_norm TEXT;');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_desc_norm ON products(description_norm);');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE queue ADD COLUMN description TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE queue ADD COLUMN updated_at TEXT;');
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE queue ADD COLUMN source TEXT NOT NULL DEFAULT 'local';");
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_queue_created_at ON queue(created_at);');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE queue ADD COLUMN reassign INTEGER NOT NULL DEFAULT 0;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE queue ADD COLUMN previous_sku TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE queue ADD COLUMN previous_description TEXT;');
      } catch (_) {}
    }
  }

  Future<void> replaceProducts(List<CatalogProduct> products) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('products');

      // Insert in batches of 500
      const batchSize = 500;
      for (var i = 0; i < products.length; i += batchSize) {
        final end = (i + batchSize < products.length) ? i + batchSize : products.length;
        final chunk = products.sublist(i, end);
        final batch = txn.batch();
        for (final product in chunk) {
          batch.insert(
            'products',
            product.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<CatalogProduct?> findProductBySku(String sku) async {
    final db = await database;
    final results = await db.query(
      'products',
      where: 'sku = ?',
      whereArgs: [sku.toUpperCase().trim()],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return CatalogProduct.fromMap(results.first);
    }
    return null;
  }

  Future<List<CatalogProduct>> searchProducts(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final db = await database;
    final norm = normalizeText(trimmed);
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');

    // Build search patterns
    final skuPattern = digits.isNotEmpty ? '%$digits%' : '%${trimmed.toUpperCase()}%';
    final descPattern = '%$norm%';

    final rows = await db.query(
      'products',
      where: 'sku LIKE ? OR description_norm LIKE ?',
      whereArgs: [skuPattern, descPattern],
      limit: 40,
    );

    final candidates = rows.map((r) => CatalogProduct.fromMap(r)).toList();
    return SkuRanking.rankAndFilter(candidates, query, maxResults: 8);
  }

  Future<int> getProductsCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    if (res.isNotEmpty) {
      return Sqflite.firstIntValue(res) ?? 0;
    }
    return 0;
  }

  Future<void> insertQueueItem(QueueItem item) async {
    final db = await database;
    await db.insert(
      'queue',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertQueueItem(QueueItem item) async {
    final db = await database;
    final epc = item.epc.toUpperCase().trim();
    List<Map<String, dynamic>> existing = [];

    if (item.clientUuid.isNotEmpty && !item.clientUuid.startsWith('server-')) {
      existing = await db.query(
        'queue',
        where: 'client_uuid = ?',
        whereArgs: [item.clientUuid],
        limit: 1,
      );
    }

    if (existing.isEmpty && epc.isNotEmpty) {
      existing = await db.query(
        'queue',
        where: 'epc = ?',
        whereArgs: [epc],
        limit: 1,
      );
    }

    if (existing.isNotEmpty) {
      final prev = QueueItem.fromMap(existing.first);
      final merged = item.copyWith(
        clientUuid: prev.clientUuid,
        description: (item.description != null && item.description!.isNotEmpty)
            ? item.description
            : prev.description,
        deviceId: item.deviceId ?? prev.deviceId,
        createdAt: prev.createdAt.isNotEmpty ? prev.createdAt : item.createdAt,
        reassign: item.reassign || prev.reassign,
        previousSku: item.previousSku ?? prev.previousSku,
        previousDescription: item.previousDescription ?? prev.previousDescription,
        message: item.message ?? prev.message,
      );
      await db.update(
        'queue',
        merged.toMap(),
        where: 'client_uuid = ?',
        whereArgs: [prev.clientUuid],
      );
    } else {
      final uuid = item.clientUuid.isNotEmpty ? item.clientUuid : 'server-$epc';
      await db.insert(
        'queue',
        item.copyWith(clientUuid: uuid).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> upsertServerItems(List<QueueItem> items) async {
    if (items.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final item in items) {
        final epc = item.epc.toUpperCase().trim();
        List<Map<String, dynamic>> existing = [];

        if (item.clientUuid.isNotEmpty && !item.clientUuid.startsWith('server-')) {
          existing = await txn.query(
            'queue',
            where: 'client_uuid = ?',
            whereArgs: [item.clientUuid],
            limit: 1,
          );
        }

        if (existing.isEmpty && epc.isNotEmpty) {
          existing = await txn.query(
            'queue',
            where: 'epc = ?',
            whereArgs: [epc],
            limit: 1,
          );
        }

        if (existing.isNotEmpty) {
          final prev = QueueItem.fromMap(existing.first);
          final merged = item.copyWith(
            clientUuid: prev.clientUuid,
            description: (item.description != null && item.description!.isNotEmpty)
                ? item.description
                : prev.description,
            deviceId: item.deviceId ?? prev.deviceId,
            createdAt: prev.createdAt.isNotEmpty ? prev.createdAt : item.createdAt,
            reassign: item.reassign || prev.reassign,
            previousSku: item.previousSku ?? prev.previousSku,
            previousDescription: item.previousDescription ?? prev.previousDescription,
            message: item.message ?? prev.message,
          );
          await txn.update(
            'queue',
            merged.toMap(),
            where: 'client_uuid = ?',
            whereArgs: [prev.clientUuid],
          );
        } else {
          final uuid = item.clientUuid.isNotEmpty ? item.clientUuid : 'server-$epc';
          await txn.insert(
            'queue',
            item.copyWith(clientUuid: uuid, source: 'server').toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> updateQueueItem(
    String clientUuid, {
    required String status,
    String? result,
    String? message,
    String? updatedAt,
    String? description,
    String? source,
    bool? reassign,
    String? previousSku,
    String? previousDescription,
  }) async {
    final db = await database;
    final map = <String, dynamic>{
      'status': status,
      'result': result,
      'message': message,
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
    if (description != null) map['description'] = description;
    if (source != null) map['source'] = source;
    if (reassign != null) map['reassign'] = reassign ? 1 : 0;
    if (previousSku != null) map['previous_sku'] = previousSku;
    if (previousDescription != null) map['previous_description'] = previousDescription;

    await db.update(
      'queue',
      map,
      where: 'client_uuid = ?',
      whereArgs: [clientUuid],
    );
  }

  static bool isSameDay(String isoDate, DateTime target) {
    final d = DateTime.tryParse(isoDate)?.toLocal();
    if (d == null) return false;
    return d.year == target.year && d.month == target.month && d.day == target.day;
  }

  Future<List<QueueItem>> getTodayQueue({DateTime? date}) async {
    final db = await database;
    final rows = await db.query(
      'queue',
      orderBy: 'created_at DESC',
    );
    final target = date ?? DateTime.now();
    return rows
        .map((r) => QueueItem.fromMap(r))
        .where((item) => isSameDay(item.createdAt, target))
        .toList();
  }

  Future<List<QueueItem>> getProblemQueue() async {
    final db = await database;
    final rows = await db.query(
      'queue',
      where: "status = 'failed' OR result = 'conflict' OR result = 'rejected'",
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => QueueItem.fromMap(r)).toList();
  }

  Future<Map<String, int>> getTodayCounts({DateTime? date}) async {
    final all = await getAllQueue();
    final target = date ?? DateTime.now();
    final todayItems = all.where((i) => isSameDay(i.createdAt, target)).toList();

    final created = todayItems.where((i) => i.result == 'created' || i.result == 'reassigned').length;
    final verified = todayItems.where((i) => i.result == 'verified').length;
    final conflict = todayItems.where((i) => i.result == 'conflict').length;
    final pending = all.where((i) => i.isPending).length;

    return {
      'created': created,
      'verified': verified,
      'conflict': conflict,
      'pending': pending,
    };
  }

  Future<List<QueueItem>> getPendingQueue() async {
    final db = await database;
    final rows = await db.query(
      'queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => QueueItem.fromMap(r)).toList();
  }

  Future<List<QueueItem>> getAllQueue() async {
    final db = await database;
    final rows = await db.query(
      'queue',
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => QueueItem.fromMap(r)).toList();
  }

  Future<int> getPendingQueueCount() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM queue WHERE status = 'pending'",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> deleteQueueItem(String clientUuid) async {
    final db = await database;
    await db.delete('queue', where: 'client_uuid = ?', whereArgs: [clientUuid]);
  }

  Future<void> clearQueue() async {
    final db = await database;
    await db.delete('queue');
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
