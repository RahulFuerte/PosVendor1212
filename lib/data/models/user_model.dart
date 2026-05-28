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
      if (date is Map && date.containsKey('\$date')) {
        return DateTime.tryParse(date['\$date'].toString());
      }
      return DateTime.tryParse(date.toString());
    }

    String? parseString(dynamic val) {
      if (val == null) return null;
      if (val is Map) {
        if (val.containsKey('\$oid')) return val['\$oid'].toString();
        if (val.containsKey('_id')) return parseString(val['_id']);
        return null;
      }
      return val.toString();
    }

    return SubscriptionDetails(
      planId: parseString(json['planId']),
      planType: parseString(json['planType']),
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      status: parseString(json['status']),
      autoRenew: json['autoRenew'] == true || json['autoRenew'] == 1,
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

class GeoLocation {
  final String type;
  final List<double> coordinates; // [longitude, latitude]

  GeoLocation({this.type = "Point", required this.coordinates});

  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    return GeoLocation(
      type: json['type'] as String? ?? "Point",
      coordinates: (json['coordinates'] as List).map((e) => (e as num).toDouble()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        "type": type,
        "coordinates": coordinates,
      };

  double? get latitude => coordinates.length > 1 ? coordinates[1] : null;
  double? get longitude => coordinates.isNotEmpty ? coordinates[0] : null;
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
  final String? city;
  final bool? isShopOpen;
  final GeoLocation? location;
  final String? businessCategory;
  final String? businessIcon;
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
    this.city,
    this.isShopOpen,
    this.location,
    this.businessCategory,
    this.businessIcon,
    this.token,
    String? userName,
    this.details = const [],
    this.totalAmount = 0.0,
  }) : _userName = userName;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    bool? parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value.toLowerCase() == 'true';
      return null;
    }

    String? parseId(dynamic val) {
      if (val == null) return null;
      if (val is Map) {
        if (val.containsKey('\$oid')) return val['\$oid'].toString();
        if (val.containsKey('_id')) return parseId(val['_id']);
        return null;
      }
      return val.toString();
    }

    return UserModel(
      id: parseId(json['_id']),
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
      city: json['city'] as String? ?? json['shopDetails']?['city'] as String?,
      isShopOpen: parseBool(json['isShopOpen']) ?? parseBool(json['shopDetails']?['isShopOpen']),
      location: json['location'] != null
          ? GeoLocation.fromJson(json['location'])
          : (json['shopDetails']?['location'] != null ? GeoLocation.fromJson(json['shopDetails']['location']) : null),
      businessCategory: json['businessCategory'] as String? ?? json['shopDetails']?['businessCategory'] as String?,
      businessIcon: json['businessIcon'] as String? ?? json['shopDetails']?['businessIcon'] as String?,
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
      'city': city,
      'isShopOpen': isShopOpen,
      'location': location?.toJson(),
      'businessCategory': businessCategory,
      'businessIcon': businessIcon,
      'token': token,
    };
  }
}
