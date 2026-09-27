import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possible_recovery/core/app_error.dart';

void main() {
  group('mapError unit tests for all categories', () {
    final dummyRequestOptions = RequestOptions(path: '/test');

    test('DioException connectionError maps to network error with host info', () {
      final dioErr = DioException(
        requestOptions: dummyRequestOptions,
        type: DioExceptionType.connectionError,
        message: 'Connection failed',
      );

      final error = mapError(dioErr, host: '127.0.0.1:8001');

      expect(error.kind, AppErrorKind.network);
      expect(error.title, 'No se pudo conectar con el servidor');
      expect(
        error.message,
        'Revisá que el colector tenga red y que el servidor esté encendido. Servidor: 127.0.0.1:8001',
      );
      expect(error.canRetry, isTrue);
    });

    test('DioException timeouts map to network error', () {
      final timeoutTypes = [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ];

      for (final type in timeoutTypes) {
        final err = DioException(
          requestOptions: dummyRequestOptions,
          type: type,
        );
        final appErr = mapError(err);
        expect(appErr.kind, AppErrorKind.network);
        expect(appErr.canRetry, isTrue);
      }
    });

    test('Connection closed raw message maps to network error (no raw text in message)', () {
      final err = DioException(
        requestOptions: dummyRequestOptions,
        type: DioExceptionType.unknown,
        message:
            'The connection errored: Connection closed before full header was received This indicates an error which most likely cannot be solved by the library.',
      );

      final appErr = mapError(err, host: '127.0.0.1:8001');
      expect(appErr.kind, AppErrorKind.network);
      expect(appErr.title, 'No se pudo conectar con el servidor');
      expect(appErr.message.contains('Connection closed'), isFalse);
      expect(
        appErr.message,
        'Revisá que el colector tenga red y que el servidor esté encendido. Servidor: 127.0.0.1:8001',
      );
    });

    test('SocketException and HandshakeException map to network error', () {
      final socketErr = const SocketException('Connection refused');
      final appErr1 = mapError(socketErr, host: '192.168.1.50');
      expect(appErr1.kind, AppErrorKind.network);
      expect(appErr1.message.contains('192.168.1.50'), isTrue);

      final handshakeErr = const HandshakeException('Handshake failed');
      final appErr2 = mapError(handshakeErr);
      expect(appErr2.kind, AppErrorKind.network);
    });

    test('401/403 in login maps to incorrect credentials', () {
      final dioErr = DioException(
        requestOptions: dummyRequestOptions,
        response: Response(
          requestOptions: dummyRequestOptions,
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );

      final appErr = mapError(dioErr, isLogin: true);
      expect(appErr.kind, AppErrorKind.auth);
      expect(appErr.title, 'Credenciales incorrectas');
      expect(appErr.message, 'Correo o contraseña incorrectos');
      expect(appErr.canRetry, isFalse);
    });

    test('401/403 outside login maps to expired session', () {
      final dioErr = DioException(
        requestOptions: dummyRequestOptions,
        response: Response(
          requestOptions: dummyRequestOptions,
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );

      final appErr = mapError(dioErr, isLogin: false);
      expect(appErr.kind, AppErrorKind.auth);
      expect(appErr.title, 'Sesión expirada');
      expect(appErr.message, 'Tu sesión expiró. Iniciá sesión de nuevo');
      expect(appErr.canRetry, isFalse);
    });

    test('400 with invalid_credentials maps to incorrect credentials', () {
      final dioErr = DioException(
        requestOptions: dummyRequestOptions,
        response: Response(
          requestOptions: dummyRequestOptions,
          statusCode: 400,
          data: {'error': 'invalid_credentials'},
        ),
        type: DioExceptionType.badResponse,
      );

      final appErr = mapError(dioErr);
      expect(appErr.kind, AppErrorKind.auth);
      expect(appErr.title, 'Credenciales incorrectas');
      expect(appErr.message, 'Correo o contraseña incorrectos');
      expect(appErr.canRetry, isFalse);
    });

    test('404 maps to not found with /api/ recommendation', () {
      final dioErr = DioException(
        requestOptions: dummyRequestOptions,
        response: Response(
          requestOptions: dummyRequestOptions,
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      );

      final appErr = mapError(dioErr);
      expect(appErr.kind, AppErrorKind.notFound);
      expect(appErr.title, 'Función no encontrada');
      expect(
        appErr.message,
        'El servidor no tiene esta función. Verificá la dirección del servidor (debe terminar en /api/)',
      );
      expect(appErr.canRetry, isFalse);
    });

    test('429 maps to rate limit', () {
      final dioErr = DioException(
        requestOptions: dummyRequestOptions,
        response: Response(
          requestOptions: dummyRequestOptions,
          statusCode: 429,
        ),
        type: DioExceptionType.badResponse,
      );

      final appErr = mapError(dioErr);
      expect(appErr.kind, AppErrorKind.rateLimit);
      expect(appErr.title, 'Demasiados intentos');
      expect(appErr.message, 'Demasiados intentos, esperá unos segundos');
      expect(appErr.canRetry, isTrue);
    });

    test('5xx maps to server problem with retry', () {
      final serverStatuses = [500, 502, 503, 504];

      for (final code in serverStatuses) {
        final dioErr = DioException(
          requestOptions: dummyRequestOptions,
          response: Response(
            requestOptions: dummyRequestOptions,
            statusCode: code,
          ),
          type: DioExceptionType.badResponse,
        );

        final appErr = mapError(dioErr);
        expect(appErr.kind, AppErrorKind.server);
        expect(appErr.title, 'Problema en el servidor');
        expect(
          appErr.message,
          'El servidor tuvo un problema. Intentá de nuevo en un momento',
        );
        expect(appErr.canRetry, isTrue);
      }
    });

    test('FormatException and non-JSON HTML responses map to format error', () {
      final formatErr = const FormatException('Unexpected character');
      final appErr1 = mapError(formatErr);
      expect(appErr1.kind, AppErrorKind.format);
      expect(appErr1.title, 'Respuesta inválida');
      expect(appErr1.message, 'Respuesta inválida del servidor');
      expect(appErr1.canRetry, isTrue);

      final htmlDioErr = DioException(
        requestOptions: dummyRequestOptions,
        response: Response(
          requestOptions: dummyRequestOptions,
          statusCode: 200,
          data: '<!DOCTYPE html><html><body>Error 502 Bad Gateway</body></html>',
        ),
        type: DioExceptionType.badResponse,
      );

      final appErr2 = mapError(htmlDioErr);
      expect(appErr2.kind, AppErrorKind.format);
      expect(appErr2.message, 'Respuesta inválida del servidor');
      expect(appErr2.canRetry, isTrue);
    });

    test('Any other unexpected error maps to unknown error with retry', () {
      final weirdErr = StateError('Something went wrong in app logic');
      final appErr = mapError(weirdErr);

      expect(appErr.kind, AppErrorKind.unknown);
      expect(appErr.title, 'Error inesperado');
      expect(appErr.message, 'Ocurrió un error inesperado');
      expect(appErr.canRetry, isTrue);
      expect(appErr.technicalDetail, contains('Something went wrong'));
    });
  });
}
