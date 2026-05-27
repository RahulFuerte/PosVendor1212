import 'dart:convert';

class CategoryModel {
  final String? id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String adminId;
  final String? syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CategoryModel({
    this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.adminId,
    this.syncStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['_id'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      adminId: json['adminId'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toString(),
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      adminId: map['admin_uid'] as String? ?? '',
      syncStatus: map['sync_status'] as String?,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'adminId': adminId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'admin_uid': adminId,
      'sync_status': syncStatus ?? 'pending',
      'created_at': createdAt?.millisecondsSinceEpoch,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? adminId,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      adminId: adminId ?? this.adminId,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
