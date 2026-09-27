class AssignResult {
  final String result; // created | verified | conflict | rejected | reassigned
  final String? sku;
  final String? description;
  final String? currentSku;
  final String? currentDescription;
  final String? previousSku;
  final String? previousDescription;
  final String? message;
  final int httpStatus;

  AssignResult({
    required this.result,
    this.sku,
    this.description,
    this.currentSku,
    this.currentDescription,
    this.previousSku,
    this.previousDescription,
    this.message,
    required this.httpStatus,
  });

  bool get isCreated => result == 'created';
  bool get isVerified => result == 'verified';
  bool get isReassigned => result == 'reassigned';
  bool get isConflict => result == 'conflict';
  bool get isRejected => result == 'rejected';

  factory AssignResult.fromJson(Map<String, dynamic> json, int statusCode) {
    return AssignResult(
      result: (json['result'] ?? '').toString().toLowerCase(),
      sku: json['sku']?.toString(),
      description: json['description']?.toString(),
      currentSku: json['current_sku']?.toString(),
      currentDescription: json['current_description']?.toString(),
      previousSku: (json['previous_sku'] ?? json['current_sku'])?.toString(),
      previousDescription: (json['previous_description'] ?? json['current_description'])?.toString(),
      message: json['message']?.toString(),
      httpStatus: statusCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'result': result,
      'sku': sku,
      'description': description,
      'current_sku': currentSku,
      'current_description': currentDescription,
      'previous_sku': previousSku,
      'previous_description': previousDescription,
      'message': message,
      'http_status': httpStatus,
    };
  }
}
