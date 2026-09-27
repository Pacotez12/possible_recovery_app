import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/data/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHttpAdapter implements HttpClientAdapter {
  ResponseBody Function(RequestOptions options)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (handler != null) {
      return handler!(options);
    }
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient apiClient;
  late MockHttpAdapter mockAdapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final dio = Dio();
    mockAdapter = MockHttpAdapter();
    dio.httpClientAdapter = mockAdapter;
    apiClient = ApiClient(customDio: dio);
  });

  group('ApiClient normalization', () {
    test('normalizeBaseUrl correctly formats trailing slash and api path', () {
      expect(ApiClient.normalizeBaseUrl('http://localhost:8001'), 'http://localhost:8001/api/');
      expect(ApiClient.normalizeBaseUrl('http://localhost:8001/'), 'http://localhost:8001/api/');
      expect(ApiClient.normalizeBaseUrl('http://localhost:8001/api'), 'http://localhost:8001/api/');
      expect(ApiClient.normalizeBaseUrl('http://localhost:8001/api/'), 'http://localhost:8001/api/');
    });
  });

  group('ApiClient login', () {
    test('successful login returns token and saves in prefs', () async {
      mockAdapter.handler = (options) {
        expect(options.path, 'login');
        return ResponseBody.fromString(
          jsonEncode({'token': 'test-jwt-token'}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final token = await apiClient.login('admin@admin.com', 'password');
      expect(token, 'test-jwt-token');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), 'test-jwt-token');
    });

    test('failed login throws ApiException', () async {
      mockAdapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({'message': 'Credenciales inválidas'}),
          401,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      expect(
        () => apiClient.login('bad@admin.com', 'wrong'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ApiClient catalog', () {
    test('fetches catalog list', () async {
      mockAdapter.handler = (options) {
        expect(options.path, 'recovery/catalog');
        return ResponseBody.fromString(
          jsonEncode([
            {
              'id': 1,
              'sku': 'AF-012918',
              'description': 'Laptop Dell',
              'location': 'Central › Depósito A',
            }
          ]),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final list = await apiClient.catalog();
      expect(list.length, 1);
      expect(list.first.sku, 'AF-012918');
      expect(list.first.description, 'Laptop Dell');
      expect(list.first.location, 'Central › Depósito A');
    });

    test('401 throws UnauthorizedException', () async {
      mockAdapter.handler = (options) {
        return ResponseBody.fromString('{}', 401);
      };

      expect(() => apiClient.catalog(), throwsA(isA<UnauthorizedException>()));
    });
  });

  group('ApiClient lookup', () {
    test('lookup returns assigned status with details', () async {
      mockAdapter.handler = (options) {
        expect(options.path, 'recovery/lookup');
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'assigned',
            'product_id': 10,
            'sku': 'AF-012918',
            'description': 'Laptop Dell',
            'assigned_by': 'Admin',
            'assigned_at': '2026-09-26T12:00:00Z',
          }),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final res = await apiClient.lookup('309373E167B0610BDCE43394');
      expect(res.isAssigned, isTrue);
      expect(res.sku, 'AF-012918');
      expect(res.assignedBy, 'Admin');
    });

    test('lookup returns new status for unassigned tag', () async {
      mockAdapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({'status': 'new'}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final res = await apiClient.lookup('309373E167B0610BDCE43394');
      expect(res.isNew, isTrue);
    });
  });

  group('ApiClient assign', () {
    test('assign created (201)', () async {
      mockAdapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'result': 'created',
            'sku': 'AF-012918',
            'description': 'Laptop Dell',
          }),
          201,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final res = await apiClient.assign(
        '309373E167B0610BDCE43394',
        'AF-012918',
        'uuid-1',
        'device-1',
      );
      expect(res.isCreated, isTrue);
      expect(res.result, 'created');
      expect(res.sku, 'AF-012918');
      expect(res.httpStatus, 201);
    });

    test('assign verified (200)', () async {
      mockAdapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'result': 'verified',
            'sku': 'AF-012918',
            'description': 'Laptop Dell',
          }),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final res = await apiClient.assign(
        '309373E167B0610BDCE43394',
        'AF-012918',
        'uuid-2',
        'device-1',
      );
      expect(res.isVerified, isTrue);
      expect(res.result, 'verified');
    });

    test('assign reassigned (200) with reassign=true passes payload and parses previous details', () async {
      mockAdapter.handler = (options) {
        expect(options.path, 'recovery/assign');
        expect(options.data['reassign'], isTrue);
        expect(options.data['sku'], 'AF-012918');
        return ResponseBody.fromString(
          jsonEncode({
            'result': 'reassigned',
            'sku': 'AF-012918',
            'description': 'Nuevo Equipo',
            'previous_sku': 'AF-012917',
            'previous_description': 'Pelota Oficial Conmebol',
          }),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final res = await apiClient.assign(
        '309373E167B0610BDCE43394',
        'AF-012918',
        'uuid-reassign',
        'device-1',
        reassign: true,
      );
      expect(res.isReassigned, isTrue);
      expect(res.result, 'reassigned');
      expect(res.sku, 'AF-012918');
      expect(res.previousSku, 'AF-012917');
      expect(res.previousDescription, 'Pelota Oficial Conmebol');
    });

    test('assign conflict (409) returns AssignResult instead of throwing', () async {
      mockAdapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'result': 'conflict',
            'current_sku': 'AF-999999',
            'current_description': 'Otro equipo',
          }),
          409,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final res = await apiClient.assign(
        '309373E167B0610BDCE43394',
        'AF-012918',
        'uuid-3',
        'device-1',
      );
      expect(res.isConflict, isTrue);
      expect(res.result, 'conflict');
      expect(res.currentSku, 'AF-999999');
      expect(res.httpStatus, 409);
    });

    test('assign rejected (422) returns AssignResult with message', () async {
      mockAdapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'result': 'rejected',
            'message': 'EPC inválido',
          }),
          422,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final res = await apiClient.assign(
        'INVALID',
        'AF-012918',
        'uuid-4',
        'device-1',
      );
      expect(res.isRejected, isTrue);
      expect(res.message, 'EPC inválido');
      expect(res.httpStatus, 422);
    });
  });

  group('ApiClient history minimal backend', () {
    test('parses history with null client_uuid, device_id, message and result created/reassigned', () async {
      mockAdapter.handler = (options) {
        expect(options.path, 'recovery/history');
        return ResponseBody.fromString(
          jsonEncode([
            {
              'epc': '309373E167B0610BDCE43394',
              'sku': 'AF-012917',
              'client_uuid': null,
              'device_id': null,
              'message': null,
              'result': 'created',
              'created_at': '2026-09-27T10:00:00Z',
            },
            {
              'epc': '30C2F1FEA18BC110CE23B02400000000',
              'sku': 'AF-012918',
              'client_uuid': null,
              'device_id': null,
              'message': null,
              'result': 'reassigned',
              'created_at': '2026-09-27T11:00:00Z',
            }
          ]),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      };

      final items = await apiClient.getHistory();
      expect(items.length, 2);
      expect(items[0].epc, '309373E167B0610BDCE43394');
      expect(items[0].sku, 'AF-012917');
      expect(items[0].isCreated, isTrue);
      expect(items[0].isReassigned, isFalse);

      expect(items[1].epc, '30C2F1FEA18BC110CE23B02400000000');
      expect(items[1].sku, 'AF-012918');
      expect(items[1].isReassigned, isTrue);
    });
  });
}
