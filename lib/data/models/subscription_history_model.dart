class SubscriptionHistoryModel {
  final String? id;
  final String userId;
  final String planId;
  final String planName;
  final double price;
  final int durationInDays;
  final DateTime startDate;
  final DateTime endDate;
  final String paymentId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SubscriptionHistoryModel({
    this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.price,
    required this.durationInDays,
    required this.startDate,
    required this.endDate,
    this.paymentId = "MANUAL",
    this.status = "completed",
    this.createdAt,
    this.updatedAt,
  });

  factory SubscriptionHistoryModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionHistoryModel(
      id: json['_id'] as String?,
      userId: json['userId'] as String? ?? '',
      planId: json['planId'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      durationInDays: (json['durationInDays'] as num?)?.toInt() ?? 0,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : DateTime.now(),
      paymentId: json['paymentId'] as String? ?? "MANUAL",
      status: json['status'] as String? ?? "completed",
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'planId': planId,
      'planName': planName,
      'price': price,
      'durationInDays': durationInDays,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'paymentId': paymentId,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
