class UserModel {
  final String userName;
  final List<Map<String, dynamic>> details;
  final double totalAmount;
  final String mobileNo; // Made nullable and changed to String for better handling

  UserModel({
    required this.userName,
    required this.details,
    required this.totalAmount,
    required this.mobileNo, // Made optional
  });

  // Factory constructor for creating UserModel from Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userName: map['userName'] ?? 'Unknown User',
      details: _parseDetails(map['details']),
      totalAmount: _parseDouble(map['totalAmount']),
      mobileNo: map['mobileNo'].toString(),
    );
  }

  // Convert UserModel to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'details': details,
      'totalAmount': totalAmount,
      'mobileNo': mobileNo,
    };
  }

  // Helper method to parse details safely
  static List<Map<String, dynamic>> _parseDetails(dynamic details) {
    if (details is List && details.isNotEmpty) {
      List<Map<String, dynamic>> decodedList = [];
      
      for (var item in details) {
        if (item is Map<dynamic, dynamic>) {
          Map<String, dynamic> convertedItem = {};
          item.forEach((key, value) {
            convertedItem[key.toString()] = value;
          });
          decodedList.add(convertedItem);
        } else if (item is Map<String, dynamic>) {
          decodedList.add(item);
        }
      }
      
      return decodedList;
    }
    return [];
  }

  // Helper method to parse double safely
  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Validation methods
  bool get isValid => userName.isNotEmpty && details.isNotEmpty && totalAmount >= 0;
  
  bool get hasMobileNo => mobileNo != null && mobileNo!.isNotEmpty;
  
  String get displayMobileNo => hasMobileNo ? mobileNo! : 'N/A';
  
  int get itemCount => details.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));
  
  // Override toString for debugging
  @override
  String toString() {
    return 'UserModel(userName: $userName, mobileNo: $mobileNo, totalAmount: $totalAmount, itemCount: $itemCount)';
  }
}

