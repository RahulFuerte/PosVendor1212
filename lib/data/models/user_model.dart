class SubscriptionDetails {
  final String? planId;
  final String? planType;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final bool? autoRenew;

  SubscriptionDetails({
    this.planId,
    this.planType,
    this.startDate,
    this.endDate,
    this.status,
    this.autoRenew,
  });

  factory SubscriptionDetails.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic date) {
      if (date == null) return null;
      if (date is Map && date.containsKey('$date')) {
        return DateTime.tryParse(date['$date'].toString());
      }
      return DateTime.tryParse(date.toString());
    }

    return SubscriptionDetails(
      planId: json['planId'] as String?,
      planType: json['planType'] as String?,
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      status: json['status'] as String?,
      autoRenew: json['autoRenew'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'planType': planType,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status,
      'autoRenew': autoRenew,
    };
  }
}

class UserModel {
  final String? id;
  final String name;
  final String phoneNumber;
  final String? role;
  final String? parentAdminId;
  final SubscriptionDetails? subscription;
  final String? shopName;
  final String? adminContact;
  final String? address;
  final String? gstNo;
  final String? fssaiNo;
  final String? logoUrl;
  final String? upiId;
  final String? token;

  // ── Hive / UsersScreen compat ──────────────────────────────────────────────
  /// Display name stored in Hive (falls back to [name]).
  final String? _userName;

  /// Cart details stored in Hive.
  final List<Map<String, dynamic>> details;

  /// Cart total stored in Hive.
  final double totalAmount;

  String get userName => _userName ?? name;

  UserModel({
    this.id,
    required this.name,
    required this.phoneNumber,
    this.role,
    this.parentAdminId,
    this.subscription,
    this.shopName,
    this.adminContact,
    this.address,
    this.gstNo,
    this.fssaiNo,
    this.logoUrl,
    this.upiId,
    this.token,
    String? userName,
    this.details = const [],
    this.totalAmount = 0.0,
  }) : _userName = userName;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] as String?,
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      role: json['role'] as String?,
      parentAdminId: json['parentAdminId'] as String?,
      subscription: json['subscription'] != null ? SubscriptionDetails.fromJson(json['subscription']) : null,
      shopName: json['shopName'] as String? ?? json['shopDetails']?['shopName'] as String?,
      adminContact: json['phoneNumber'] as String? ?? json['shopDetails']?['phoneNumber'] as String?,
      address: json['address'] as String? ?? json['shopDetails']?['address'] as String?,
      gstNo: json['gstNo'] as String? ?? json['shopDetails']?['gstNo'] as String?,
      fssaiNo: json['fssaiNo'] as String? ?? json['shopDetails']?['fssaiNo'] as String?,
      logoUrl: json['logoUrl'] as String? ?? json['shopDetails']?['logoUrl'] as String?,
      upiId: json['upiId'] as String? ?? json['shopDetails']?['upiId'] as String?,
      token: json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'role': role,
      'parentAdminId': parentAdminId,
      'subscription': subscription?.toJson(),
      'shopName': shopName,
      'address': address,
      'adminContact': adminContact,
      'gstNo': gstNo,
      'fssaiNo': fssaiNo,
      'logoUrl': logoUrl,
      'upiId': upiId,
      'token': token,
    };
  }
}
