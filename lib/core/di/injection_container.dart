// Dependency injection container for Clean Architecture
// Imports for clean architecture components

// Project imports:
import 'package:pos/core/network/connection_monitor.dart';
import 'package:pos/core/network/network_info.dart';
import 'package:pos/data/datasources/local/food_item_local_datasource.dart';
import 'package:pos/data/datasources/local/sqlite_dao.dart';
import 'package:pos/data/datasources/remote/firebase_dao.dart';
import 'package:pos/data/datasources/remote/food_item_remote_datasource.dart';
import 'package:pos/data/repositories/bill_repository_impl.dart';
import 'package:pos/data/repositories/department_repository_impl.dart';
import 'package:pos/data/repositories/food_item_repository_impl.dart';
import 'package:pos/domain/repositories/bill_repository.dart';
import 'package:pos/domain/repositories/department_repository.dart';
import 'package:pos/domain/repositories/food_item_repository.dart';
import 'package:pos/domain/usecases/bill/delete_bill.dart';
import 'package:pos/domain/usecases/bill/get_bills.dart';
import 'package:pos/domain/usecases/bill/save_bill.dart';
import 'package:pos/domain/usecases/bill/sync_offline_bills.dart';
import 'package:pos/domain/usecases/bill/update_bill.dart';
import 'package:pos/domain/usecases/department/delete_department.dart';
import 'package:pos/domain/usecases/department/get_departments.dart';
import 'package:pos/domain/usecases/department/save_department.dart';
import 'package:pos/domain/usecases/department/update_department.dart';
import 'package:pos/domain/usecases/food_item/get_food_items.dart';
import 'package:pos/domain/usecases/food_item/save_food_item.dart';

// Imports for existing services

// Additional imports for Department and Bill repositories

// Use case imports

/// Simple dependency injection container
/// For production, consider using get_it or riverpod
class InjectionContainer {
  static final InjectionContainer _instance = InjectionContainer._internal();
  factory InjectionContainer() => _instance;
  InjectionContainer._internal();

  final Map<Type, dynamic> _dependencies = {};

  /// Register a dependency
  void register<T>(T instance) {
    _dependencies[T] = instance;
  }

  /// Register a lazy singleton
  void registerLazySingleton<T>(T Function() factory) {
    _dependencies[T] = _LazyFactory<T>(factory);
  }

  /// Get a dependency
  T get<T>() {
    final dependency = _dependencies[T];
    if (dependency == null) {
      throw Exception('Dependency $T not registered');
    }
    if (dependency is _LazyFactory<T>) {
      final instance = dependency.create();
      _dependencies[T] = instance;
      return instance;
    }
    return dependency as T;
  }

  /// Check if dependency is registered
  bool isRegistered<T>() => _dependencies.containsKey(T);

  /// Clear all dependencies
  void clear() => _dependencies.clear();
}

class _LazyFactory<T> {
  final T Function() factory;
  _LazyFactory(this.factory);
  T create() => factory();
}

/// Global injection container instance
final sl = InjectionContainer();

/// Initialize all dependencies
Future<void> initDependencies() async {
  // Existing services (these will be injected into our new implementations)
  final connectionMonitor = ConnectionMonitor();
  await connectionMonitor.initialize();
  
  final sqliteDAO = SQLiteDAO();
  await sqliteDAO.initialize();
  
  final firebaseDAO = FirebaseDAO();
  await firebaseDAO.initialize();
  
  // Core
  sl.register<NetworkInfo>(NetworkInfoImpl(connectionMonitor));

  // Data sources
  sl.registerLazySingleton<FoodItemLocalDataSource>(() => FoodItemLocalDataSourceImpl(sqliteDAO));
  sl.registerLazySingleton<FoodItemRemoteDataSource>(() => FoodItemRemoteDataSourceImpl(firebaseDAO));

  // Additional data sources for Department and Bill
  sl.registerLazySingleton<DepartmentLocalDataSource>(() => DepartmentLocalDataSourceImpl(sqliteDAO));
  sl.registerLazySingleton<DepartmentRemoteDataSource>(() => DepartmentRemoteDataSourceImpl(firebaseDAO));
  sl.registerLazySingleton<BillLocalDataSource>(() => BillLocalDataSourceImpl(sqliteDAO));
  sl.registerLazySingleton<BillRemoteDataSource>(() => BillRemoteDataSourceImpl(firebaseDAO));

  // Repositories
  sl.registerLazySingleton<FoodItemRepository>(() => FoodItemRepositoryImpl(
    localDataSource: sl.get<FoodItemLocalDataSource>(),
    remoteDataSource: sl.get<FoodItemRemoteDataSource>(),
    networkInfo: sl.get<NetworkInfo>(),
  ));

  sl.registerLazySingleton<DepartmentRepository>(() => DepartmentRepositoryImpl(
    localDataSource: sl.get<DepartmentLocalDataSource>(),
    remoteDataSource: sl.get<DepartmentRemoteDataSource>(),
    networkInfo: sl.get<NetworkInfo>(),
  ));

  sl.registerLazySingleton<BillRepository>(() => BillRepositoryImpl(
    localDataSource: sl.get<BillLocalDataSource>(),
    remoteDataSource: sl.get<BillRemoteDataSource>(),
    networkInfo: sl.get<NetworkInfo>(),
  ));

  // Use cases
  sl.registerLazySingleton(() => GetFoodItems(sl.get<FoodItemRepository>()));
  sl.registerLazySingleton(() => SaveFoodItem(sl.get<FoodItemRepository>()));
  
  // Department use cases
  sl.registerLazySingleton(() => GetDepartments(sl.get<DepartmentRepository>()));
  sl.registerLazySingleton(() => SaveDepartment(sl.get<DepartmentRepository>()));
  sl.registerLazySingleton(() => UpdateDepartment(sl.get<DepartmentRepository>()));
  sl.registerLazySingleton(() => DeleteDepartment(sl.get<DepartmentRepository>()));
  
  // Bill use cases
  sl.registerLazySingleton(() => GetBills(sl.get<BillRepository>()));
  sl.registerLazySingleton(() => SaveBill(sl.get<BillRepository>()));
  sl.registerLazySingleton(() => UpdateBill(sl.get<BillRepository>()));
  sl.registerLazySingleton(() => DeleteBill(sl.get<BillRepository>()));
  sl.registerLazySingleton(() => SyncOfflineBills(sl.get<BillRepository>()));
}
