class UserModel {
  final String userName;
  final List<Map<String, dynamic>> details;
  final double totalAmount;
  // final int mobileNo;

  UserModel({
    required this.userName,
    required this.details,
    required this.totalAmount,
    // required this.mobileNo
  });
}
