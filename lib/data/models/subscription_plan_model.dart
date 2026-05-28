class FeaturePermission {
  final bool view;
  final bool create;
  final bool edit;
  final bool delete;

  FeaturePermission({
    this.view = false,
    this.create = false,
    this.edit = false,
    this.delete = false,
  });

  factory FeaturePermission.fromJson(Map<String, dynamic> json) {
    return FeaturePermission(
      view: json['view'] == true,
      create: json['create'] == true,
      edit: json['edit'] == true,
      delete: json['delete'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'view': view,
        'create': create,
        'edit': edit,
        'delete': delete,
      };
}

class PlanFeature {
  final String key;
  final bool enabled;
  final FeaturePermission? permissions;

  PlanFeature({
    required this.key,
    this.enabled = true,
    this.permissions,
  });

  factory PlanFeature.fromJson(Map<String, dynamic> json) {
    return PlanFeature(
      key: json['key'] ?? '',
      enabled: json['enabled'] != false,
      permissions: json['permissions'] != null ? FeaturePermission.fromJson(json['permissions']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'enabled': enabled,
        'permissions': permissions?.toJson(),
      };
}

class PlanLimit {
  final String key;
  final int value;

  PlanLimit({
    required this.key,
    this.value = -1,
  });

  factory PlanLimit.fromJson(Map<String, dynamic> json) {
    return PlanLimit(
      key: json['key'] ?? '',
      value: (json['value'] as num?)?.toInt() ?? -1,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
      };
}

class PlanPricing {
  final double amount;
  final String currency;
  final String billingCycle;
  final int trialDays;

  PlanPricing({
    required this.amount,
    this.currency = 'INR',
    this.billingCycle = 'monthly',
    this.trialDays = 0,
  });

  factory PlanPricing.fromJson(Map<String, dynamic> json) {
    return PlanPricing(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'INR',
      billingCycle: json['billingCycle'] ?? 'monthly',
      trialDays: (json['trialDays'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'currency': currency,
        'billingCycle': billingCycle,
        'trialDays': trialDays,
      };
}

class DisplayFeature {
  final String title;
  final String? description;
  final bool highlight;

  DisplayFeature({
    required this.title,
    this.description,
    this.highlight = false,
  });

  factory DisplayFeature.fromJson(Map<String, dynamic> json) {
    return DisplayFeature(
      title: json['title'] ?? '',
      description: json['description'],
      highlight: json['highlight'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'highlight': highlight,
      };
}

class SubscriptionPlanModel {
  final String? id;
  final String name;
  final double price; // backward compatibility
  final int durationInDays;
  final PlanPricing? pricing;
  final List<DisplayFeature>? displayFeatures;
  final List<PlanFeature>? features;
  final List<PlanLimit>? limits;
  
  // Backward compatibility for old features array of strings
  final List<String>? legacyFeatures;

  final bool? isActive;
  final bool isRecommended;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SubscriptionPlanModel({
    this.id,
    required this.name,
    required this.price,
    required this.durationInDays,
    this.pricing,
    this.displayFeatures,
    this.features,
    this.limits,
    this.legacyFeatures,
    this.isActive,
    this.isRecommended = false,
    this.createdAt,
    this.updatedAt,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    List<String>? parsedLegacyFeatures;
    List<PlanFeature>? parsedFeatures;
    
    if (json['features'] != null && json['features'] is List) {
      if ((json['features'] as List).isNotEmpty && json['features'][0] is String) {
        parsedLegacyFeatures = (json['features'] as List).map((e) => e.toString()).toList();
      } else {
        parsedFeatures = (json['features'] as List).map((e) => PlanFeature.fromJson(e)).toList();
      }
    }
    
    // Parse createdAt and updatedAt handles string date or map with $date (from snippet)
    DateTime? parseDate(dynamic dateVal) {
      if (dateVal == null) return null;
      if (dateVal is Map && dateVal.containsKey('\$date')) {
         return DateTime.tryParse(dateVal['\$date'].toString());
      }
      return DateTime.tryParse(dateVal.toString());
    }

    return SubscriptionPlanModel(
      id: (json['_id'] is Map) ? json['_id']['\$oid'] as String? : json['_id'] as String?,
      name: json['name'] as String? ?? '',
      price: json['pricing'] != null ? ((json['pricing']['amount'] as num?)?.toDouble() ?? 0.0) : ((json['price'] as num?)?.toDouble() ?? 0.0),
      durationInDays: (json['durationInDays'] as num?)?.toInt() ?? 0,
      pricing: json['pricing'] != null ? PlanPricing.fromJson(json['pricing']) : null,
      displayFeatures: json['displayFeatures'] != null ? (json['displayFeatures'] as List).map((e) => DisplayFeature.fromJson(e)).toList() : null,
      features: parsedFeatures,
      limits: json['limits'] != null ? (json['limits'] as List).map((e) => PlanLimit.fromJson(e)).toList() : null,
      legacyFeatures: parsedLegacyFeatures,
      isActive: json['isActive'] as bool?,
      isRecommended: json['isRecommended'] as bool? ?? false,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'price': price,
      'durationInDays': durationInDays,
      'pricing': pricing?.toJson(),
      'displayFeatures': displayFeatures?.map((e) => e.toJson()).toList(),
      'features': features != null ? features!.map((e) => e.toJson()).toList() : legacyFeatures,
      'limits': limits?.map((e) => e.toJson()).toList(),
      'isActive': isActive,
      'isRecommended': isRecommended,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
