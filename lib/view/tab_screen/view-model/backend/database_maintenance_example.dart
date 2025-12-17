import 'dart:developer' as developer;
import 'sqlite_helper.dart';
import 'database_maintenance_service.dart';

/// Example demonstrating how to use the database maintenance features
/// This shows the four main maintenance operations implemented in task 15
class DatabaseMaintenanceExample {
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  
  /// Demonstrate all database maintenance operations
  Future<void> demonstrateMaintenanceOperations() async {
    developer.log('Starting database maintenance demonstration', name: 'MaintenanceExample');
    
    try {
      // Initialize database
      await _sqliteHelper.initializeDatabase();
      
      // 1. Demonstrate automatic database vacuum operation
      await _demonstrateVacuumOperation();
      
      // 2. Demonstrate database integrity checks
      await _demonstrateIntegrityCheck();
      
      // 3. Demonstrate database size monitoring and cleanup
      await _demonstrateSizeMonitoringAndCleanup();
      
      // 4. Demonstrate automatic index maintenance
      await _demonstrateIndexMaintenance();
      
      // 5. Demonstrate comprehensive maintenance
      await _demonstrateComprehensiveMaintenance();
      
      // 6. Demonstrate maintenance history
      await _demonstrateMaintenanceHistory();
      
      developer.log('Database maintenance demonstration completed successfully', name: 'MaintenanceExample');
      
    } catch (e) {
      developer.log('Database maintenance demonstration failed: $e', name: 'MaintenanceExample');
    }
  }
  
  /// Demonstrate automatic database vacuum operation
  Future<void> _demonstrateVacuumOperation() async {
    developer.log('--- Demonstrating Vacuum Operation ---', name: 'MaintenanceExample');
    
    // Get database size before vacuum
    final sizeBeforeVacuum = await _sqliteHelper.getDatabaseSizeInformation();
    developer.log('Database size before vacuum: ${sizeBeforeVacuum.totalSizeMB.toStringAsFixed(2)}MB', name: 'MaintenanceExample');
    
    // Perform vacuum operation
    final vacuumResult = await _sqliteHelper.performDatabaseVacuum();
    
    if (vacuumResult.success) {
      developer.log('Vacuum completed successfully:', name: 'MaintenanceExample');
      developer.log('  - Size before: ${vacuumResult.sizeBefore.toStringAsFixed(2)}MB', name: 'MaintenanceExample');
      developer.log('  - Size after: ${vacuumResult.sizeAfter.toStringAsFixed(2)}MB', name: 'MaintenanceExample');
      developer.log('  - Space reclaimed: ${vacuumResult.spaceReclaimedMB.toStringAsFixed(2)}MB', name: 'MaintenanceExample');
      developer.log('  - Duration: ${vacuumResult.duration?.inMilliseconds ?? 0}ms', name: 'MaintenanceExample');
    } else {
      developer.log('Vacuum failed: ${vacuumResult.error}', name: 'MaintenanceExample');
    }
  }
  
  /// Demonstrate database integrity checks
  Future<void> _demonstrateIntegrityCheck() async {
    developer.log('--- Demonstrating Integrity Check ---', name: 'MaintenanceExample');
    
    // Perform integrity check
    final integrityResult = await _sqliteHelper.performDatabaseIntegrityCheck();
    
    if (integrityResult.success) {
      developer.log('Integrity check completed:', name: 'MaintenanceExample');
      developer.log('  - Database healthy: ${integrityResult.isHealthy}', name: 'MaintenanceExample');
      developer.log('  - SQLite integrity: ${integrityResult.sqliteIntegrityOk}', name: 'MaintenanceExample');
      developer.log('  - Foreign key constraints: ${integrityResult.foreignKeyConstraintsOk}', name: 'MaintenanceExample');
      developer.log('  - Orphaned records: ${integrityResult.orphanedRecordsOk}', name: 'MaintenanceExample');
      developer.log('  - Data consistency: ${integrityResult.dataConsistencyOk}', name: 'MaintenanceExample');
      developer.log('  - Index consistency: ${integrityResult.indexConsistencyOk}', name: 'MaintenanceExample');
      developer.log('  - Duration: ${integrityResult.duration?.inMilliseconds ?? 0}ms', name: 'MaintenanceExample');
      
      if (integrityResult.issues.isNotEmpty) {
        developer.log('  - Issues found:', name: 'MaintenanceExample');
        for (final issue in integrityResult.issues) {
          developer.log('    * $issue', name: 'MaintenanceExample');
        }
      }
      
      if (integrityResult.tableStatistics.isNotEmpty) {
        developer.log('  - Table statistics:', name: 'MaintenanceExample');
        integrityResult.tableStatistics.forEach((table, count) {
          developer.log('    * $table: $count records', name: 'MaintenanceExample');
        });
      }
    } else {
      developer.log('Integrity check failed: ${integrityResult.error}', name: 'MaintenanceExample');
    }
  }
  
  /// Demonstrate database size monitoring and cleanup
  Future<void> _demonstrateSizeMonitoringAndCleanup() async {
    developer.log('--- Demonstrating Size Monitoring and Cleanup ---', name: 'MaintenanceExample');
    
    // Get database size information
    final sizeInfo = await _sqliteHelper.getDatabaseSizeInformation();
    
    if (sizeInfo.success) {
      developer.log('Database size information:', name: 'MaintenanceExample');
      developer.log('  - Total size: ${sizeInfo.totalSizeMB.toStringAsFixed(2)}MB', name: 'MaintenanceExample');
      developer.log('  - Free space: ${sizeInfo.freeSizeMB.toStringAsFixed(2)}MB', name: 'MaintenanceExample');
      developer.log('  - Page count: ${sizeInfo.pageCount}', name: 'MaintenanceExample');
      developer.log('  - Page size: ${sizeInfo.pageSize} bytes', name: 'MaintenanceExample');
      developer.log('  - Free pages: ${sizeInfo.freePages}', name: 'MaintenanceExample');
      
      if (sizeInfo.tableSizes.isNotEmpty) {
        developer.log('  - Table sizes:', name: 'MaintenanceExample');
        sizeInfo.tableSizes.forEach((table, sizeMB) {
          developer.log('    * $table: ${sizeMB.toStringAsFixed(2)}MB', name: 'MaintenanceExample');
        });
      }
    } else {
      developer.log('Failed to get size information: ${sizeInfo.error}', name: 'MaintenanceExample');
    }
    
    // Perform data cleanup
    final cleanupResult = await _sqliteHelper.performDatabaseCleanup();
    
    if (cleanupResult.success) {
      developer.log('Data cleanup completed:', name: 'MaintenanceExample');
      developer.log('  - Total items removed: ${cleanupResult.itemsRemoved}', name: 'MaintenanceExample');
      developer.log('  - Sync logs removed: ${cleanupResult.syncLogsRemoved}', name: 'MaintenanceExample');
      developer.log('  - Image cache entries removed: ${cleanupResult.imageCacheEntriesRemoved}', name: 'MaintenanceExample');
      developer.log('  - Orphaned images removed: ${cleanupResult.orphanedImagesRemoved}', name: 'MaintenanceExample');
      developer.log('  - Migration logs removed: ${cleanupResult.migrationLogsRemoved}', name: 'MaintenanceExample');
      developer.log('  - Duration: ${cleanupResult.duration?.inMilliseconds ?? 0}ms', name: 'MaintenanceExample');
    } else {
      developer.log('Data cleanup failed: ${cleanupResult.error}', name: 'MaintenanceExample');
    }
  }
  
  /// Demonstrate automatic index maintenance
  Future<void> _demonstrateIndexMaintenance() async {
    developer.log('--- Demonstrating Index Maintenance ---', name: 'MaintenanceExample');
    
    // Perform index optimization
    final indexResult = await _sqliteHelper.optimizeDatabaseIndexes();
    
    if (indexResult.success) {
      developer.log('Index optimization completed:', name: 'MaintenanceExample');
      developer.log('  - Statistics updated: ${indexResult.statisticsUpdated}', name: 'MaintenanceExample');
      developer.log('  - Indexes analyzed: ${indexResult.indexesAnalyzed}', name: 'MaintenanceExample');
      developer.log('  - FTS index rebuilt: ${indexResult.ftsIndexRebuilt}', name: 'MaintenanceExample');
      developer.log('  - Duration: ${indexResult.duration?.inMilliseconds ?? 0}ms', name: 'MaintenanceExample');
      
      if (indexResult.missingIndexes.isNotEmpty) {
        developer.log('  - Missing indexes created:', name: 'MaintenanceExample');
        for (final index in indexResult.missingIndexes) {
          developer.log('    * $index', name: 'MaintenanceExample');
        }
      }
      
      if (indexResult.indexUsageStats.isNotEmpty) {
        developer.log('  - Index usage statistics:', name: 'MaintenanceExample');
        developer.log('    * Total indexes: ${indexResult.indexUsageStats['totalIndexes']}', name: 'MaintenanceExample');
      }
    } else {
      developer.log('Index optimization failed: ${indexResult.error}', name: 'MaintenanceExample');
    }
  }
  
  /// Demonstrate comprehensive maintenance
  Future<void> _demonstrateComprehensiveMaintenance() async {
    developer.log('--- Demonstrating Comprehensive Maintenance ---', name: 'MaintenanceExample');
    
    // Perform comprehensive maintenance with all options enabled
    final maintenanceResult = await _sqliteHelper.performDatabaseMaintenance(
      forceVacuum: true,
      forceIntegrityCheck: true,
      cleanupOldData: true,
      optimizeIndexes: true,
    );
    
    if (maintenanceResult.success) {
      developer.log('Comprehensive maintenance completed successfully:', name: 'MaintenanceExample');
      developer.log('  - Duration: ${maintenanceResult.duration?.inMilliseconds ?? 0}ms', name: 'MaintenanceExample');
      
      if (maintenanceResult.warnings.isNotEmpty) {
        developer.log('  - Warnings:', name: 'MaintenanceExample');
        for (final warning in maintenanceResult.warnings) {
          developer.log('    * $warning', name: 'MaintenanceExample');
        }
      }
      
      // Show summary of all operations
      if (maintenanceResult.vacuumResult != null) {
        developer.log('  - Vacuum: ${maintenanceResult.vacuumResult!.spaceReclaimedMB.toStringAsFixed(2)}MB reclaimed', name: 'MaintenanceExample');
      }
      
      if (maintenanceResult.integrityCheckResult != null) {
        developer.log('  - Integrity: ${maintenanceResult.integrityCheckResult!.isHealthy ? "HEALTHY" : "ISSUES FOUND"}', name: 'MaintenanceExample');
      }
      
      if (maintenanceResult.cleanupResult != null) {
        developer.log('  - Cleanup: ${maintenanceResult.cleanupResult!.itemsRemoved} items removed', name: 'MaintenanceExample');
      }
      
      if (maintenanceResult.indexOptimizationResult != null) {
        developer.log('  - Indexes: ${maintenanceResult.indexOptimizationResult!.indexesAnalyzed} analyzed', name: 'MaintenanceExample');
      }
      
    } else {
      developer.log('Comprehensive maintenance failed: ${maintenanceResult.error}', name: 'MaintenanceExample');
    }
  }
  
  /// Demonstrate maintenance history
  Future<void> _demonstrateMaintenanceHistory() async {
    developer.log('--- Demonstrating Maintenance History ---', name: 'MaintenanceExample');
    
    // Get maintenance history
    final history = await _sqliteHelper.getMaintenanceHistory(limit: 10);
    
    if (history.isNotEmpty) {
      developer.log('Recent maintenance operations:', name: 'MaintenanceExample');
      for (final entry in history) {
        final operation = entry['operation'] as String;
        final executedAt = DateTime.fromMillisecondsSinceEpoch(entry['executed_at'] as int);
        final success = entry['success'] == 1;
        
        developer.log('  - $operation: ${success ? "SUCCESS" : "FAILED"} at ${executedAt.toIso8601String()}', name: 'MaintenanceExample');
      }
    } else {
      developer.log('No maintenance history found', name: 'MaintenanceExample');
    }
  }
  
  /// Demonstrate scheduled automatic maintenance
  Future<void> demonstrateAutomaticMaintenance() async {
    developer.log('--- Demonstrating Automatic Maintenance ---', name: 'MaintenanceExample');
    
    // This would typically be called by a background scheduler
    // For demonstration, we'll just call it manually
    await _sqliteHelper.scheduleAutomaticMaintenance();
    
    developer.log('Automatic maintenance check completed', name: 'MaintenanceExample');
  }
}

/// Usage example
Future<void> runDatabaseMaintenanceExample() async {
  final example = DatabaseMaintenanceExample();
  
  // Run the complete demonstration
  await example.demonstrateMaintenanceOperations();
  
  // Demonstrate automatic maintenance
  await example.demonstrateAutomaticMaintenance();
}