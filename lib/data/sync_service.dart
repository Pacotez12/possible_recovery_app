import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/catalog_product.dart';
import 'api_client.dart';
import 'local_db.dart';

class SyncService extends ChangeNotifier {
  final ApiClient apiClient;
  final LocalDb localDb;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _lastError;
  String? get lastError => _lastError;

  SyncService({
    required this.apiClient,
    required this.localDb,
  });

  Future<int> syncCatalog() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final products = await apiClient.catalog();
      await localDb.replaceProducts(products);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
      await prefs.setInt('last_sync_count', products.length);

      _isSyncing = false;
      notifyListeners();
      return products.length;
    } catch (e) {
      _isSyncing = false;
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString('last_sync_time');
    if (timeStr == null || timeStr.isEmpty) return null;
    return DateTime.tryParse(timeStr);
  }

  Future<int> getLastSyncCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_sync_count') ?? 0;
  }

  Future<int> getLocalCount() async {
    return await localDb.getProductsCount();
  }

  Future<CatalogProduct?> findProductBySku(String sku) async {
    return await localDb.findProductBySku(sku);
  }

  Future<List<CatalogProduct>> searchProducts(String query) async {
    return await localDb.searchProducts(query);
  }
}
