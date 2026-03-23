class SubscriptionPlanModel {
  final String? id;
  final String name;
  final double price;
  final int durationInDays;
  final List<String>? features;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SubscriptionPlanModel({
    this.id,
    required this.name,
    required this.price,
    required this.durationInDays,
    this.features,
    this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['_id'] as String?,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      durationInDays: (json['durationInDays'] as num?)?.toInt() ?? 0,
      features: (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      isActive: json['isActive'] as bool?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'price': price,
      'durationInDays': durationInDays,
      'features': features,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
