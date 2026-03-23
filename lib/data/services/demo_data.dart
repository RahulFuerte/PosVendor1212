import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';
import '../models/expense_category_model.dart';

class DemoData {
  static List<CategoryModel> get categories => [
        CategoryModel(id: 'cat1', name: 'Fast Food', imageUrl: '', adminId: 'demo_admin_123'),
        CategoryModel(id: 'cat2', name: 'Main Course', imageUrl: '', adminId: 'demo_admin_123'),
        CategoryModel(id: 'cat3', name: 'Beverages', imageUrl: '', adminId: 'demo_admin_123'),
        CategoryModel(id: 'cat4', name: 'Desserts', imageUrl: '', adminId: 'demo_admin_123'),
      ];

  static List<ProductModel> get products => [
        ProductModel(
          id: 'p1',
          name: 'Paneer Burger',
          price: 120.0,
          categoryId: 'cat1',
          adminId: 'demo_admin_123',
          description: 'Delicious paneer patty burger',
          foodCode: 'FF001',
          inStock: true,
        ),
        ProductModel(
          id: 'p2',
          name: 'Veg Pizza',
          price: 250.0,
          categoryId: 'cat1',
          adminId: 'demo_admin_123',
          description: 'Cheese and veggie loaded pizza',
          foodCode: 'FF002',
          inStock: true,
        ),
        ProductModel(
          id: 'p3',
          name: 'Dal Makhani',
          price: 180.0,
          categoryId: 'cat2',
          adminId: 'demo_admin_123',
          description: 'Classic buttery black lentils',
          foodCode: 'MC001',
          inStock: true,
        ),
        ProductModel(
          id: 'p4',
          name: 'Butter Naan',
          price: 40.0,
          categoryId: 'cat2',
          adminId: 'demo_admin_123',
          foodCode: 'MC002',
          inStock: true,
        ),
        ProductModel(
          id: 'p5',
          name: 'Cold Coffee',
          price: 80.0,
          categoryId: 'cat3',
          adminId: 'demo_admin_123',
          foodCode: 'BV001',
          inStock: true,
        ),
        ProductModel(
          id: 'p6',
          name: 'Gulab Jamun',
          price: 50.0,
          categoryId: 'cat4',
          adminId: 'demo_admin_123',
          foodCode: 'DS001',
          inStock: true,
        ),
      ];

  static UserModel get profile => UserModel(
        id: 'demo_admin_123',
        name: 'Demo User',
        phoneNumber: '1234567890',
        role: 'admin',
        shopName: 'Demo Restaurant',
        address: '123 Demo Street, Tech City',
        gstNo: '22AAAAA0000A1Z5',
        fssaiNo: '12345678901234',
        upiId: 'demo@upi',
      );

  static Map<String, dynamic> get salesReport => {
        "revenue": 1500.0,
        "orders": 12,
        "averageOrderValue": 125.0,
        "topProducts": [
          {"name": "Paneer Burger", "quantity": 15, "revenue": 1800.0},
          {"name": "Veg Pizza", "quantity": 10, "revenue": 2500.0}
        ]
      };

  static List<dynamic> get dateWiseReport => [
        {"date": "2026-03-01", "revenue": 5000.0, "orders": 25},
        {"date": "2026-03-02", "revenue": 4500.0, "orders": 22},
        {"date": "2026-03-03", "revenue": 6000.0, "orders": 30},
        {"date": "2026-03-04", "revenue": 5500.0, "orders": 28},
        {"date": "2026-03-05", "revenue": 7000.0, "orders": 35},
      ];

  static Map<String, dynamic> get dashboardReport => {
        "totalSales": 25000.0,
        "totalOrders": 150,
        "totalExpenses": 8000.0,
        "netProfit": 17000.0,
        "orderTypeDistribution": {"DineIn": 80, "PickUp": 40, "Delivery": 30}
      };

  static List<ExpenseCategoryModel> get expenseCategories => [
        ExpenseCategoryModel(id: 'ex1', name: 'Rent', adminId: 'demo_admin_123'),
        ExpenseCategoryModel(id: 'ex2', name: 'Electricity', adminId: 'demo_admin_123'),
        ExpenseCategoryModel(id: 'ex3', name: 'Raw Material', adminId: 'demo_admin_123'),
      ];

  static List<ExpenseModel> get expenses => [
        ExpenseModel(
          id: 'e1',
          expenseCategoryId: 'ex1',
          amount: 5000.0,
          note: 'Monthly Rent',
          date: DateTime.now().subtract(const Duration(days: 5)),
          adminId: 'demo_admin_123',
        ),
        ExpenseModel(
          id: 'e2',
          expenseCategoryId: 'ex2',
          amount: 1500.0,
          note: 'Electricity Bill',
          date: DateTime.now().subtract(const Duration(days: 2)),
          adminId: 'demo_admin_123',
        ),
      ];
}
