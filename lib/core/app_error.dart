import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum AppErrorKind {
  network,
  auth,
  notFound,
  rateLimit,
  server,
  format,
  validation,
  hardware,
  permission,
  warning,
  unknown,
}

class AppError implements Exception {
  final AppErrorKind kind;
  final String title;
  final String message;
  final bool canRetry;
  final String? technicalDetail;

  const AppError({
    required this.kind,
    required this.title,
    required this.message,
    this.canRetry = false,
    this.technicalDetail,
  });

  @override
  String toString() => '$title: $message';
}

AppError mapError(Object e, {String? host, bool isLogin = false}) {
  final technical = e.toString();
  debugPrint('[AppError LOG] $technical');

  if (e is AppError) {
    return e;
  }

  final hostSuffix = (host != null && host.trim().isNotEmpty)
      ? ' Servidor: ${host.trim()}'
      : '';

  if (e is DioException) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    // 1. HTTP Status checks
    if (status == 401 || status == 403) {
      return AppError(
        kind: AppErrorKind.auth,
        title: isLogin ? 'Credenciales incorrectas' : 'Sesión expirada',
        message: isLogin
            ? 'Correo o contraseña incorrectos'
            : 'Tu sesión expiró. Iniciá sesión de nuevo',
        canRetry: false,
        technicalDetail: technical,
      );
    }

    if (status == 400) {
      final isInvalidCreds = (data is Map &&
              (data['error'] == 'invalid_credentials' ||
                  data['message']?.toString().contains('invalid_credentials') ==
                      true)) ||
          e.message?.contains('invalid_credentials') == true;

      if (isInvalidCreds) {
        return AppError(
          kind: AppErrorKind.auth,
          title: 'Credenciales incorrectas',
          message: 'Correo o contraseña incorrectos',
          canRetry: false,
          technicalDetail: technical,
        );
      }

      return AppError(
        kind: AppErrorKind.validation,
        title: 'Solicitud inválida',
        message: 'Los datos enviados no son válidos.',
        canRetry: false,
        technicalDetail: technical,
      );
    }

    if (status == 404) {
      return AppError(
        kind: AppErrorKind.notFound,
        title: 'Función no encontrada',
        message:
            'El servidor no tiene esta función. Verificá la dirección del servidor (debe terminar en /api/)',
        canRetry: false,
        technicalDetail: technical,
      );
    }

    if (status == 429) {
      return AppError(
        kind: AppErrorKind.rateLimit,
        title: 'Demasiados intentos',
        message: 'Demasiados intentos, esperá unos segundos',
        canRetry: true,
        technicalDetail: technical,
      );
    }

    if (status != null && status >= 500 && status < 600) {
      // If 502/503/504 returns non-JSON HTML, it's server problem
      return AppError(
        kind: AppErrorKind.server,
        title: 'Problema en el servidor',
        message: 'El servidor tuvo un problema. Intentá de nuevo en un momento',
        canRetry: true,
        technicalDetail: technical,
      );
    }

    // 2. Format / Non-JSON response checks
    if (e.error is FormatException ||
        (data is String &&
            (data.contains('<html') || data.contains('<!DOCTYPE html')))) {
      return AppError(
        kind: AppErrorKind.format,
        title: 'Respuesta inválida',
        message: 'Respuesta inválida del servidor',
        canRetry: true,
        technicalDetail: technical,
      );
    }

    // 3. Network / Connection checks
    final isConnectionClosed = e.message?.contains('Connection closed') == true ||
        e.error?.toString().contains('Connection closed') == true;

    final isSocketOrHandshake = e.error is SocketException ||
        e.error is HandshakeException ||
        e.message?.contains('SocketException') == true ||
        e.message?.contains('HandshakeException') == true;

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        isConnectionClosed ||
        isSocketOrHandshake) {
      return AppError(
        kind: AppErrorKind.network,
        title: 'No se pudo conectar con el servidor',
        message:
            'Revisá que el colector tenga red y que el servidor esté encendido.$hostSuffix',
        canRetry: true,
        technicalDetail: technical,
      );
    }

    if (e.type == DioExceptionType.badCertificate) {
      return AppError(
        kind: AppErrorKind.network,
        title: 'Certificado inválido',
        message:
            'No se pudo establecer una conexión segura con el servidor.$hostSuffix',
        canRetry: true,
        technicalDetail: technical,
      );
    }
  }

  if (e is SocketException || e is HandshakeException) {
    return AppError(
      kind: AppErrorKind.network,
      title: 'No se pudo conectar con el servidor',
      message:
          'Revisá que el colector tenga red y que el servidor esté encendido.$hostSuffix',
      canRetry: true,
      technicalDetail: technical,
    );
  }

  if (e is FormatException) {
    return AppError(
      kind: AppErrorKind.format,
      title: 'Respuesta inválida',
      message: 'Respuesta inválida del servidor',
      canRetry: true,
      technicalDetail: technical,
    );
  }

  // Any other error
  return AppError(
    kind: AppErrorKind.unknown,
    title: 'Error inesperado',
    message: 'Ocurrió un error inesperado',
    canRetry: true,
    technicalDetail: technical,
  );
}
