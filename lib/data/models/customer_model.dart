class CustomerModel {
  final String? id;
  final String name;
  final String phoneNumber;
  final String adminId;
  final String? address;
  final String? gstNo; // Local-DB compat field
  final bool isUploaded; // Local-DB compat field
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerModel({
    this.id,
    required this.name,
    required this.phoneNumber,
    this.adminId = '',
    this.address,
    this.gstNo,
    this.isUploaded = false,
    this.createdAt,
    this.updatedAt,
  });

  // ── Backward-compatibility alias ──────────────────────────────────────────
  /// Same as [phoneNumber]. Kept for old screens that use `.phone`.
  String get phone => phoneNumber;

  // ── JSON (Node.js API) ────────────────────────────────────────────────────
  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['_id'] as String?,
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      adminId: json['adminId'] as String? ?? '',
      address: json['address'] as String?,
      gstNo: json['gstNo'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'adminId': adminId,
      'address': address,
      'gstNo': gstNo,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // ── SQLite (local DB) ─────────────────────────────────────────────────────
  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id']?.toString(),
      name: map['name'] as String? ?? '',
      // Support both old 'phone' and new 'phoneNumber' column names
      phoneNumber: map['phoneNumber'] as String? ?? map['phone'] as String? ?? '',
      adminId: map['admin_uid'] as String? ?? '',
      address: map['address'] as String?,
      gstNo: map['gstNo'] as String?,
      isUploaded: (map['isUploaded'] == 1 || map['isUploaded'] == true),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
              : DateTime.tryParse(map['createdAt'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'admin_uid': adminId,
      'address': address,
      'gstNo': gstNo,
      'isUploaded': isUploaded ? 1 : 0,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? adminId,
    String? address,
    String? gstNo,
    bool? isUploaded,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      adminId: adminId ?? this.adminId,
      address: address ?? this.address,
      gstNo: gstNo ?? this.gstNo,
      isUploaded: isUploaded ?? this.isUploaded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
