import 'package:flutter/material.dart';
import '../ui/theme/tokens.dart';

class QueueItem {
  final String clientUuid;
  final String epc;
  final String sku;
  final String? description;
  final String? previousSku;
  final String? previousDescription;
  final String? deviceId;
  final String createdAt;
  final String? updatedAt;
  final String status; // pending | sent | failed
  final String? result; // created | verified | conflict | rejected | reassigned
  final String? message;
  final bool reassign;
  final String source; // local | server

  QueueItem({
    this.clientUuid = '',
    required this.epc,
    required this.sku,
    this.description,
    this.previousSku,
    this.previousDescription,
    this.deviceId,
    required this.createdAt,
    this.updatedAt,
    required this.status,
    this.result,
    this.message,
    this.reassign = false,
    this.source = 'local',
  });

  bool get isPending => status == 'pending';
  bool get isSent => status == 'sent';
  bool get isFailed => status == 'failed';

  bool get isCreated => result == 'created';
  bool get isVerified => result == 'verified';
  bool get isReassigned => result == 'reassigned';
  bool get isConflict => result == 'conflict';
  bool get isRejected => result == 'rejected';
  bool get isProblem => isFailed || isConflict || isRejected;

  String get statusLabel {
    if (isPending) return 'Pendiente';
    if (isFailed) return 'Falló';
    if (isReassigned) return 'Reasignada';
    if (isCreated) return 'Asignada';
    if (isVerified) return 'Verificada';
    if (isConflict) return 'Conflicto';
    if (isRejected) return 'Rechazada';
    if (isSent) return 'Enviada';
    return 'Desconocido';
  }

  Color get statusColor {
    if (isPending) return AppColors.pending;
    if (isFailed || isConflict || isRejected) return AppColors.conflict;
    if (isReassigned) return AppColors.reassigned;
    if (isVerified) return AppColors.verified;
    if (isCreated) return AppColors.created;
    return AppColors.textSecondary;
  }

  factory QueueItem.fromMap(Map<String, dynamic> map) {
    return QueueItem(
      clientUuid: map['client_uuid']?.toString() ?? '',
      epc: map['epc']?.toString() ?? '',
      sku: map['sku']?.toString() ?? '',
      description: map['description']?.toString(),
      previousSku: map['previous_sku']?.toString(),
      previousDescription: map['previous_description']?.toString(),
      deviceId: map['device_id']?.toString(),
      createdAt: map['created_at']?.toString() ?? '',
      updatedAt: map['updated_at']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      result: map['result']?.toString(),
      message: map['message']?.toString(),
      reassign: (map['reassign'] == 1 || map['reassign'] == true),
      source: map['source']?.toString() ?? 'local',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'client_uuid': clientUuid,
      'epc': epc,
      'sku': sku,
      'description': description,
      'previous_sku': previousSku,
      'previous_description': previousDescription,
      'device_id': deviceId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'status': status,
      'result': result,
      'message': message,
      'reassign': reassign ? 1 : 0,
      'source': source,
    };
  }

  QueueItem copyWith({
    String? clientUuid,
    String? status,
    String? result,
    String? message,
    String? description,
    String? previousSku,
    String? previousDescription,
    String? deviceId,
    String? createdAt,
    String? updatedAt,
    bool? reassign,
    String? source,
  }) {
    return QueueItem(
      clientUuid: clientUuid ?? this.clientUuid,
      epc: epc,
      sku: sku,
      description: description ?? this.description,
      previousSku: previousSku ?? this.previousSku,
      previousDescription: previousDescription ?? this.previousDescription,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      result: result ?? this.result,
      message: message ?? this.message,
      reassign: reassign ?? this.reassign,
      source: source ?? this.source,
    );
  }
}
