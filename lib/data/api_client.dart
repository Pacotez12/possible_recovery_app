import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_error.dart';
import '../core/epc_normalizer.dart';
import '../models/assign_result.dart';
import '../models/catalog_product.dart';
import '../models/lookup_result.dart';
import '../models/queue_item.dart';

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Sesión expirada o no autorizada']);

  @override
  String toString() => message;
}

class OfflineException implements Exception {
  final String message;
  OfflineException([this.message = 'Sin conexión con el servidor']);

  @override
  String toString() => message;
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final AppError? appError;

  ApiException(this.message, {this.statusCode, this.appError});

  @override
  String toString() => message;
}

class ApiClient {
  static const String defaultHost = 'http://127.0.0.1:8005/api/';
  final Dio dio;

  ApiClient({Dio? customDio}) : dio = customDio ?? Dio() {
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 30);
    dio.options.validateStatus = (status) => status != null && status < 500;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          return handler.next(options);
        },
      ),
    );
  }

  static String normalizeBaseUrl(String input) {
    var host = input.trim();
    if (host.isEmpty) host = defaultHost;
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    if (host.endsWith('/api')) {
      host = host.substring(0, host.length - '/api'.length);
    }
    return '$host/api/';
  }

  Future<void> updateBaseUrl([String? host]) async {
    final prefs = await SharedPreferences.getInstance();
    final url = normalizeBaseUrl(host ?? prefs.getString('api_host') ?? defaultHost);
    dio.options.baseUrl = url;
  }

  Future<String> login(String email, String password, {String? customHost}) async {
    await updateBaseUrl(customHost);
    try {
      final response = await dio.post(
        'login',
        data: {'email': email.trim(), 'password': password},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final token = response.data['token']?.toString();
        if (token != null && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          if (customHost != null) {
            await prefs.setString('api_host', customHost.trim());
          }
          return token;
        }
      }

      final appErr = mapError(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        ),
        host: dio.options.baseUrl,
        isLogin: true,
      );
      throw ApiException(appErr.message, statusCode: response.statusCode, appError: appErr);
    } on DioException catch (e) {
      _handleDioException(e, isLogin: true);
      final appErr = mapError(e, host: dio.options.baseUrl, isLogin: true);
      throw ApiException(appErr.message, statusCode: e.response?.statusCode, appError: appErr);
    }
  }

  Future<List<CatalogProduct>> catalog() async {
    await updateBaseUrl();
    try {
      final response = await dio.get('recovery/catalog');
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw UnauthorizedException();
      }
      if (response.statusCode != 200) {
        final appErr = mapError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
          host: dio.options.baseUrl,
        );
        throw ApiException(appErr.message, statusCode: response.statusCode, appError: appErr);
      }

      final data = response.data;
      if (data is List) {
        return data.map((item) => CatalogProduct.fromMap(Map<String, dynamic>.from(item as Map))).toList();
      }
      return [];
    } on DioException catch (e) {
      _handleDioException(e);
      final appErr = mapError(e, host: dio.options.baseUrl);
      throw ApiException(appErr.message, statusCode: e.response?.statusCode, appError: appErr);
    }
  }

  Future<LookupResult> lookup(String epc) async {
    await updateBaseUrl();
    try {
      final response = await dio.post(
        'recovery/lookup',
        data: {'epc': normalizeEpc(epc)},
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw UnauthorizedException();
      }
      if (response.statusCode != 200) {
        final appErr = mapError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
          host: dio.options.baseUrl,
        );
        throw ApiException(appErr.message, statusCode: response.statusCode, appError: appErr);
      }

      final data = response.data;
      if (data is Map) {
        return LookupResult.fromJson(Map<String, dynamic>.from(data));
      }
      return LookupResult(status: 'new');
    } on DioException catch (e) {
      _handleDioException(e);
      final appErr = mapError(e, host: dio.options.baseUrl);
      throw ApiException(appErr.message, statusCode: e.response?.statusCode, appError: appErr);
    }
  }

  Future<AssignResult> assign(
    String epc,
    String sku,
    String clientUuid,
    String? deviceId, {
    bool reassign = false,
  }) async {
    await updateBaseUrl();
    try {
      final payload = <String, dynamic>{
        'epc': normalizeEpc(epc),
        'sku': sku.toUpperCase().trim(),
        'client_uuid': clientUuid,
        'device_id': deviceId,
      };
      if (reassign) {
        payload['reassign'] = true;
      }
      final response = await dio.post(
        'recovery/assign',
        data: payload,
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw UnauthorizedException();
      }

      // 200, 201, 409, 422 are all valid application results according to contract
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      return AssignResult.fromJson(data, response.statusCode ?? 500);
    } on DioException catch (e) {
      _handleDioException(e);
      final appErr = mapError(e, host: dio.options.baseUrl);
      throw ApiException(appErr.message, statusCode: e.response?.statusCode, appError: appErr);
    }
  }

  Future<List<QueueItem>> getHistory({String? since}) async {
    await updateBaseUrl();
    try {
      final queryParams = <String, dynamic>{};
      if (since != null && since.isNotEmpty) {
        queryParams['since'] = since;
      }
      final response = await dio.get(
        'recovery/history',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw UnauthorizedException();
      }
      if (response.statusCode != 200) {
        final appErr = mapError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
          host: dio.options.baseUrl,
        );
        throw ApiException(appErr.message, statusCode: response.statusCode, appError: appErr);
      }

      final data = response.data;
      if (data is List) {
        return data.map((json) {
          final map = Map<String, dynamic>.from(json as Map);
          final rawMsg = map['message']?.toString();
          String? prevSku = map['previous_sku']?.toString();
          if (prevSku == null && rawMsg != null && rawMsg.startsWith('Reasignada de ')) {
            final match = RegExp(r'Reasignada de (AF-\d+) a').firstMatch(rawMsg);
            if (match != null) {
              prevSku = match.group(1);
            }
          }
          final resType = map['result']?.toString();
          return QueueItem(
            clientUuid: map['client_uuid']?.toString() ?? '',
            epc: map['epc']?.toString() ?? '',
            sku: map['sku']?.toString() ?? '',
            description: map['description']?.toString(),
            previousSku: prevSku,
            previousDescription: map['previous_description']?.toString(),
            deviceId: map['device_id']?.toString(),
            createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            status: 'sent',
            result: resType,
            message: rawMsg,
            reassign: resType == 'reassigned',
            source: 'server',
          );
        }).toList();
      }
      return [];
    } on DioException catch (e) {
      _handleDioException(e);
      final appErr = mapError(e, host: dio.options.baseUrl);
      throw ApiException(appErr.message, statusCode: e.response?.statusCode, appError: appErr);
    }
  }

  void _handleDioException(DioException e, {bool isLogin = false}) {
    final appError = mapError(e, host: dio.options.baseUrl, isLogin: isLogin);
    if (appError.kind == AppErrorKind.auth && !isLogin) {
      throw UnauthorizedException(appError.message);
    }
    if (appError.kind == AppErrorKind.network) {
      throw OfflineException(appError.message);
    }
    throw ApiException(
      appError.message,
      statusCode: e.response?.statusCode,
      appError: appError,
    );
  }
}
