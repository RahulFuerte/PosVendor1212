# Offline Bill Implementation Guide

## Overview

The offline bill functionality allows the POS system to continue operating and saving bills even when there's no internet connection. Bills are automatically synced to Firebase when connectivity is restored.

## Key Features

1. **Automatic Offline Detection**: System automatically detects when offline and saves bills locally
2. **Automatic Sync**: Bills sync automatically when connection is restored
3. **Manual Sync**: Users can manually trigger sync at any time
4. **Conflict Resolution**: Handles conflicts using timestamp-based resolution
5. **User Feedback**: Clear visual indicators for online/offline status

## Architecture

### Components

1. **DirectPrintHelper** (`printer.dart`)
   - Main entry point for printing and bill saving
   - Handles online/offline detection
   - Routes bills to Firebase (online) or SQLite (offline)

2. **OfflineBillManager** (`offline_bill_manager.dart`)
   - Manages offline bill storage and synchronization
   - Handles conflict resolution
   - Provides sync status streams

3. **ConnectionMonitor** (`connection_monitor.dart`)
   - Monitors internet connectivity
   - Triggers automatic sync when online

4. **UI Components**
   - `OfflineBillSyncButton`: Shows pending bills and sync button
   - `OfflineBillExampleScreen`: Full-featured example screen

## Usage

### Basic Bill Saving (Automatic Online/Offline Handling)

```dart
// This automatically handles online/offline scenarios
await DirectPrintHelper.saveBillToFirebase(
  adminUid: 'admin123',
  receiptNo: 'REC001',
  items: [
    {'name': 'Item 1', 'price': 10.0, 'quantity': 2},
    {'name': 'Item 2', 'price': 15.0, 'quantity': 1},
  ],
  subTotal: 35.0,
);
```

### Printing with Offline Support

```dart
await DirectPrintHelper.printReceipt(
  context: context,
  printer: selectedPrinter,
  paperSize: PaperSize.mm58,
  items: cartItems,
  total: totalAmount,
  shopName: 'My Shop',
  contact: '1234567890',
  address: '123 Main St',
  adminUid: 'admin123',
);
```

### Check Offline Bill Statistics

```dart
final stats = await DirectPrintHelper.getOfflineBillStats(adminUid);
print('Offline bills: ${stats['offlineBillsCount']}');
print('Synced bills: ${stats['syncedBillsCount']}');
print('Is online: ${stats['isConnected']}');
```

### Manual Sync

```dart
final result = await DirectPrintHelper.syncOfflineBills(adminUid);
if (result.success) {
  print('Synced ${result.billsSynced} bills');
} else {
  print('Sync failed: ${result.errorMessage}');
}
```

### Using the Sync Button Widget

```dart
// Add to your screen
OfflineBillSyncButton(
  adminUid: currentAdminUid,
  onSyncComplete: () {
    // Refresh your UI or show success message
    print('Sync completed!');
  },
)
```

## Data Flow

### Online Scenario
```
User prints receipt
    ↓
DirectPrintHelper.printReceipt()
    ↓
Check connectivity (online)
    ↓
Save directly to Firebase
    ↓
Show success message
```

### Offline Scenario
```
User prints receipt
    ↓
DirectPrintHelper.printReceipt()
    ↓
Check connectivity (offline)
    ↓
Save to SQLite via OfflineBillManager
    ↓
Show "saved offline" message
    ↓
[Later when online]
    ↓
ConnectionMonitor detects connection
    ↓
OfflineBillManager auto-syncs
    ↓
Bills uploaded to Firebase
    ↓
Local bills marked as synced
```

## Bill Data Structure

### Firebase Structure
```
AllBills/
  {adminUid}/
    myBills/
      {monthDoc}/        // e.g., "202512"
        {dateDoc}/       // e.g., "20251217"
          {receiptNo}/   // e.g., "12345678"
            - adminId
            - createdAt (serverTimestamp)
            - date (formatted string)
            - items (array)
            - receiptNo
            - subTotal
```

### SQLite Structure
```dart
{
  'id': 'LOCAL_1234567890_1234',  // Unique local ID
  'admin_uid': 'admin123',
  'receiptNo': '12345678',
  'items': '[{"name":"Item","price":10,"quantity":1}]',
  'subTotal': 10.0,
  'date': 'Dec 17, 2024',
  'monthDoc': '202512',
  'dateDoc': '20251217',
  'sync_status': 'pending',  // pending, synced, conflict
  'offline_created': true,
  'local_timestamp': 1234567890,
  'created_at': 1234567890,
  'updated_at': 1234567890,
}
```

## Conflict Resolution

The system uses timestamp-based conflict resolution:

1. When syncing, check if bill exists on Firebase
2. Compare local timestamp with Firebase timestamp
3. If Firebase is newer, skip local sync (Firebase wins)
4. If local is newer or equal, sync local version (local wins)
5. Mark conflicts for manual review if needed

## Error Handling

### Fallback Strategy
```dart
try {
  // Try to save online
  await saveToFirebase();
} catch (e) {
  // Fallback to offline storage
  await saveOffline();
}
```

### User Feedback
- **Online save**: Green snackbar with "saved online"
- **Offline save**: Orange snackbar with "saved offline, will sync"
- **Sync success**: Green snackbar with count
- **Sync failure**: Red snackbar with error message

## Testing

### Test Offline Functionality
1. Turn off internet/WiFi
2. Print a receipt
3. Verify "saved offline" message appears
4. Check offline bill count increases
5. Turn on internet
6. Verify automatic sync occurs
7. Check bill appears in Firebase

### Test Manual Sync
1. Create offline bills
2. Go online
3. Tap sync button
4. Verify bills sync successfully
5. Check offline count decreases to 0

## Best Practices

1. **Always use DirectPrintHelper methods** - They handle online/offline automatically
2. **Show sync status** - Use OfflineBillSyncButton to keep users informed
3. **Handle errors gracefully** - Always have fallback to offline storage
4. **Test offline scenarios** - Regularly test with no internet connection
5. **Monitor sync status** - Use the statistics methods to track sync health

## Integration Example

```dart
class MyPOSScreen extends StatefulWidget {
  @override
  State<MyPOSScreen> createState() => _MyPOSScreenState();
}

class _MyPOSScreenState extends State<MyPOSScreen> {
  final String adminUid = 'admin123';
  final String userId = 'user456';

  Future<void> _printBill() async {
    try {
      await DirectPrintHelper.printReceipt(
        context: context,
        printer: selectedPrinter,
        paperSize: PaperSize.mm58,
        items: cartItems,
        total: calculateTotal(),
        shopName: 'My Shop',
        contact: '1234567890',
        address: '123 Main St',
        adminUid: adminUid,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS'),
        actions: [
          // Show offline bill sync button
          OfflineBillSyncButton(
            adminUid: adminUid,
            onSyncComplete: () {
              setState(() {}); // Refresh UI
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Your POS UI here
          ElevatedButton(
            onPressed: _printBill,
            child: const Text('Print Bill'),
          ),
        ],
      ),
    );
  }
}
```

## Troubleshooting

### Bills not syncing
1. Check internet connection
2. Verify OfflineBillManager is initialized
3. Check Firebase permissions
4. Look for error messages in logs

### Duplicate bills
1. Check if conflict resolution is working
2. Verify unique receipt numbers
3. Check local_timestamp values

### Sync taking too long
1. Check number of pending bills
2. Verify internet speed
3. Consider batch size (currently 5)
4. Check Firebase write limits

## Future Enhancements

1. **Batch optimization**: Adjust batch size based on connection speed
2. **Retry logic**: Implement exponential backoff for failed syncs
3. **Partial sync**: Allow syncing specific bills
4. **Sync scheduling**: Schedule syncs during off-peak hours
5. **Compression**: Compress bill data for faster sync
6. **Progress tracking**: Show detailed sync progress
7. **Conflict UI**: Manual conflict resolution interface

## Related Files

- `lib/view/tab_screen/view-model/widgets/printers/printer.dart`
- `lib/view/tab_screen/view-model/backend/offline_bill_manager.dart`
- `lib/view/tab_screen/view-model/backend/connection_monitor.dart`
- `lib/view/tab_screen/view-model/backend/sqlite_dao.dart`
- `lib/view/tab_screen/view-model/backend/firebase_dao.dart`
- `lib/view/tab_screen/view-model/widgets/offline_bill_sync_button.dart`
- `lib/view/tab_screen/view-model/widgets/printers/offline_bill_example.dart`
