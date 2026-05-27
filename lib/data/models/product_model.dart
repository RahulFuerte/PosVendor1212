import 'dart:convert';

class ProductModel {
  final String? id;
  final String name;
  final double price;
  final String? description;
  final String categoryId;
  final String adminId;
  final List<dynamic>? addons;
  final String? syncStatus;
  final String? baseVariant;
  final String? department;
  final String? foodCode;
  final String? imagePath;
  final bool? isHot;
  final double? price2;
  final double? price3;
  final String? priceType;
  final int? stocks;
  final String? tax;
  final List<dynamic>? variants;
  final String? imageUrl;
  final bool? inStock;
  final bool? isVeg;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? barcode;

  ProductModel({
    this.id,
    required this.name,
    required this.price,
    this.description,
    required this.categoryId,
    required this.adminId,
    this.addons,
    this.syncStatus,
    this.baseVariant,
    this.department,
    this.foodCode,
    this.imagePath,
    this.isHot,
    this.price2,
    this.price3,
    this.priceType,
    this.stocks,
    this.tax,
    this.variants,
    this.imageUrl,
    this.inStock,
    this.isVeg,
    this.createdAt,
    this.updatedAt,
    this.barcode,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['_id'] as String?,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      categoryId: _extractCategoryId(json),
      adminId: json['adminId'] as String? ?? '',
      addons: json['addons'] as List<dynamic>?,
      syncStatus: json['syncStatus'] as String?,
      baseVariant: json['baseVariant'] as String?,
      department: json['department'] as String?,
      foodCode: json['foodCode'] as String?,
      imagePath: json['imagePath'] as String?,
      isHot: json['isHot'] as bool?,
      price2: (json['price2'] as num?)?.toDouble(),
      price3: (json['price3'] as num?)?.toDouble(),
      priceType: json['priceType'] as String?,
      stocks: (json['stocks'] as num?)?.toInt() ?? (json['stock'] as num?)?.toInt(),
      tax: json['tax'] as String?,
      variants: json['variants'] as List<dynamic>?,
      imageUrl: json['imageUrl'] as String?,
      inStock: json['inStock'] as bool? ?? json['isAvailable'] as bool?,
      isVeg: json['isVeg'] as bool?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      barcode: json['barcode'] as String?,
    );
  }

  static String _extractCategoryId(Map<String, dynamic> json) {
    if (json['categoryId'] != null) {
      if (json['categoryId'] is Map) return json['categoryId']['_id']?.toString() ?? '';
      return json['categoryId'].toString();
    }
    if (json['category'] != null) {
      if (json['category'] is Map) return json['category']['_id']?.toString() ?? '';
      return json['category'].toString();
    }
    return '';
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id']?.toString(),
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String?,
      categoryId: map['categoryId']?.toString() ?? map['category']?.toString() ?? '',
      adminId: map['admin_uid'] as String? ?? '',
      syncStatus: map['sync_status'] as String?,
      baseVariant: map['baseVariant'] as String?,
      department: map['department'] as String?,
      foodCode: map['foodCode']?.toString(),
      imagePath: map['image_path'] as String?,
      isHot: map['is_hot'] == 1 || map['is_hot'] == true,
      price2: (map['price2'] as num?)?.toDouble(),
      price3: (map['price3'] as num?)?.toDouble(),
      priceType: map['priceType'] as String?,
      stocks: (map['stocks'] as num?)?.toInt() ?? (map['stock'] as num?)?.toInt(),
      tax: map['tax'] as String?,
      variants:
          map['variants'] != null ? (map['variants'] is String ? jsonDecode(map['variants']) : map['variants']) : null,
      imageUrl: map['image_url'] as String? ?? map['imageUrl'] as String?,
      inStock:
          map['in_stock'] == 1 || map['in_stock'] == true || map['is_available'] == 1 || map['is_available'] == true,
      isVeg: map['is_veg'] == 1 || map['is_veg'] == true || map['isVeg'] == true,
      createdAt: map['created_at'] != null
          ? (map['created_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
              : DateTime.tryParse(map['created_at'].toString()))
          : null,
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
              : DateTime.tryParse(map['updated_at'].toString()))
          : null,
      barcode: map['barcode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': id,
      'name': name,
      'price': price,
      'description': description,
      'categoryId': categoryId,
      'adminId': adminId,
      'addons': addons,
      'syncStatus': syncStatus,
      'baseVariant': baseVariant,
      'department': department,
      'foodCode': foodCode,
      'imagePath': imagePath,
      'isHot': isHot,
      'price2': price2,
      'price3': price3,
      'priceType': priceType,
      'stocks': stocks,
      'tax': tax,
      'variants': variants,
      'imageUrl': imageUrl,
      'inStock': inStock,
      'isVeg': isVeg,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'barcode': barcode,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'admin_uid': adminId,
      'name': name,
      'price': price,
      'description': description,
      'category': categoryId,
      'image_url': imageUrl,
      'image_path': imagePath,
      'foodCode': foodCode,
      'department': department,
      'stocks': stocks,
      'is_hot': (isHot ?? false) ? 1 : 0,
      'in_stock': (inStock ?? true) ? 1 : 0,
      'tax': tax,
      'sync_status': syncStatus ?? 'pending',
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'baseVariant': baseVariant,
      'addons': jsonEncode(addons),
      'variants': jsonEncode(variants),
      'barcode': barcode,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    double? price,
    String? description,
    String? categoryId,
    String? adminId,
    List<dynamic>? addons,
    String? syncStatus,
    String? baseVariant,
    String? department,
    String? foodCode,
    String? imagePath,
    bool? isHot,
    double? price2,
    double? price3,
    String? priceType,
    int? stocks,
    String? tax,
    List<dynamic>? variants,
    String? imageUrl,
    bool? inStock,
    bool? isVeg,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? barcode,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      adminId: adminId ?? this.adminId,
      addons: addons ?? this.addons,
      syncStatus: syncStatus ?? this.syncStatus,
      baseVariant: baseVariant ?? this.baseVariant,
      department: department ?? this.department,
      foodCode: foodCode ?? this.foodCode,
      imagePath: imagePath ?? this.imagePath,
      isHot: isHot ?? this.isHot,
      price2: price2 ?? this.price2,
      price3: price3 ?? this.price3,
      priceType: priceType ?? this.priceType,
      stocks: stocks ?? this.stocks,
      tax: tax ?? this.tax,
      variants: variants ?? this.variants,
      imageUrl: imageUrl ?? this.imageUrl,
      inStock: inStock ?? this.inStock,
      isVeg: isVeg ?? this.isVeg,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      barcode: barcode ?? this.barcode,
    );
  }
}
