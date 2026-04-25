class ApiConstants {
  // Base URL - Update this for production
  // static const String baseUrl = 'http://172.20.10.3:5000/api';
  static const String baseUrl = 'https://billing-pos-tvtw.onrender.com/api';

  // static const String baseUrl = 'https://pos-backend-xj6u.onrender.com/api';
  // Endpoints
  static const String users = '$baseUrl/users';
  static const String customers = '$baseUrl/customers';
  static const String categories = '$baseUrl/categories';
  static const String products = '$baseUrl/products';
  static const String orders = '$baseUrl/orders';
  static const String reports = '$baseUrl/reports';
  static const String expenses = '$baseUrl/expenses';
  static const String expenseCategories = '$baseUrl/expense-categories';
  static const String subscriptions = '$baseUrl/subscriptions';
  static const String menuUpload = '$baseUrl/menu-images/upload';
  static const String staff = '$baseUrl/staff';
  static const String unknownCustomers = '$baseUrl/unknown-customers';
  static const String tables = '$baseUrl/tables';
  static const String kot = '$baseUrl/kots';

  // Cloudinary Config (User needs to provide these)
  static const String cloudinaryCloudName = 'djgziksj8';
  static const String cloudinaryUploadPreset = 'accounts_pro';
}
