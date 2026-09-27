class LookupResult {
  final String status; // new | assigned
  final int? productId;
  final String? sku;
  final String? description;
  final String? assignedBy;
  final String? assignedAt;
  final String? location;

  LookupResult({
    required this.status,
    this.productId,
    this.sku,
    this.description,
    this.assignedBy,
    this.assignedAt,
    this.location,
  });

  bool get isNew => status == 'new';
  bool get isAssigned => status == 'assigned';

  factory LookupResult.fromJson(Map<String, dynamic> json) {
    return LookupResult(
      status: (json['status'] ?? 'new').toString().toLowerCase(),
      productId: json['product_id'] is int
          ? json['product_id'] as int
          : int.tryParse(json['product_id']?.toString() ?? ''),
      sku: json['sku']?.toString(),
      description: json['description']?.toString(),
      assignedBy: json['assigned_by']?.toString(),
      assignedAt: json['assigned_at']?.toString(),
      location: json['location']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'product_id': productId,
      'sku': sku,
      'description': description,
      'assigned_by': assignedBy,
      'assigned_at': assignedAt,
      'location': location,
    };
  }
}
