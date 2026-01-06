// import 'dart:developer' as developer;
// import 'lib/view/tab_screen/view-model/backend/database_index_manager.dart';
// import 'lib/view/tab_screen/view-model/backend/smart_database_service.dart';

// void main() async {
//   try {
//     developer.log('Testing FTS5 fixes...', name: 'TestFixes');
    
//     // Test database index manager
//     final indexManager = DatabaseIndexManager();
//     final capabilities = await indexManager.getSearchCapabilities();
//     developer.log('Search capabilities: $capabilities', name: 'TestFixes');
    
//     // Test smart database service
//     final smartDB = SmartDatabaseService();
//     await smartDB.initialize();
//     developer.log('Smart database service initialized successfully', name: 'TestFixes');
    
//     developer.log('All fixes working correctly!', name: 'TestFixes');
//   } catch (e) {
//     developer.log('Error in fixes: $e', name: 'TestFixes');
//   }
// }