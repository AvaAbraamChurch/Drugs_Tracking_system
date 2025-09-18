class DrugModel {
  final int? id;
  final String name;
  final int stock;
  final String expiryDate;
  final String imageUrl;

  DrugModel({
    this.id,
    required this.name,
    required this.stock,
    required this.expiryDate,
    this.imageUrl = '',
  });

  factory DrugModel.fromJson(Map<String, dynamic> json) {
    return DrugModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      stock: json['stock'] as int? ?? 0,
      expiryDate: json['expiryDate'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stock': stock,
      'expiryDate': expiryDate,
      'imageUrl': imageUrl,
    };
  }

  DrugModel copyWith({
    int? id,
    String? name,
    int? stock,
    String? expiryDate,
    String? imageUrl,
  }) {
    return DrugModel(
      id: id ?? this.id,
      name: name ?? this.name,
      stock: stock ?? this.stock,
      expiryDate: expiryDate ?? this.expiryDate,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

}