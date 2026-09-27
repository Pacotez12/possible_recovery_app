import '../core/text_normalizer.dart';

class CatalogProduct {
  final int? id;
  final String sku;
  final String? description;
  final String? location;
  final String? descriptionNorm;

  CatalogProduct({
    this.id,
    required this.sku,
    this.description,
    this.location,
    this.descriptionNorm,
  });

  factory CatalogProduct.fromMap(Map<String, dynamic> map) {
    return CatalogProduct(
      id: map['id'] is int ? map['id'] as int : int.tryParse(map['id']?.toString() ?? ''),
      sku: (map['sku'] ?? '').toString().toUpperCase().trim(),
      description: map['description']?.toString(),
      location: map['location']?.toString(),
      descriptionNorm: map['description_norm']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sku': sku,
      'description': description,
      'location': location,
      'description_norm': descriptionNorm ?? normalizeText(description ?? ''),
    };
  }
}
