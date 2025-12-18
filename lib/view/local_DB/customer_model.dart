class CustomerModel {
  final int? id;
  final String name;
  final String phone;
  final String? gstNo;
  final DateTime createdAt;
  final bool isUploaded;

  CustomerModel({
    this.id,
    required this.name,
    required this.phone,
    this.gstNo,
    required this.createdAt,
    this.isUploaded = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'gstNo': gstNo,
      'createdAt': createdAt.toIso8601String(),
      'isUploaded': isUploaded ? 1 : 0,
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      gstNo: map['gstNo'],
      createdAt: DateTime.parse(map['createdAt']),
      isUploaded: map['isUploaded'] == 1,
    );
  }

  CustomerModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? gstNo,
    DateTime? createdAt,
    bool? isUploaded,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      gstNo: gstNo ?? this.gstNo,
      createdAt: createdAt ?? this.createdAt,
      isUploaded: isUploaded ?? this.isUploaded,
    );
  }
}
