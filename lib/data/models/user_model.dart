class UserModel {
  final String userName;
  final String phoneNumber;
  final List<Map<String, dynamic>> details;
  final double totalAmount;

  UserModel({
    required this.userName,
    required this.phoneNumber,
    required this.details,
    required this.totalAmount,
  });
}
