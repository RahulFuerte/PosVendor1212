# UI Documentation

## Newly Added Screens (Drawer Navigation)

The following screens have been added to the main `ProductDashBoard` drawer to improve accessibility and functionality.

### 1. My Customers (`CustomersListScreen`)

- **Path:** `lib/view/home/customer_listScreen.dart`
- **Description:** A screen to manage the local customer database.
- **Features:**
  - View list of customers saved locally.
  - Sync/Upload customer data to Firebase (Cloud Firestore).
  - Add new customers (if functionality exists within the screen).
- **Access:** Open the Drawer -> Tap "My Customers".

### 2. Saved Orders (`UsersScreen`)

- **Path:** `lib/view/home/usersDataScreen.dart`
- **Description:** A screen to view and manage saved/held orders.
- **Features:**
  - View list of orders saved temporarily (using Hive local storage).
  - **Restore:** Import a saved order back into the active cart (`PrintProvider`).
  - **Delete:** Remove a saved order.
- **Access:** Open the Drawer -> Tap "Saved Orders".

### 4. Sync Diagnostics (`SyncStatusPage`)

- **Path:** `lib/view/tab_screen/view-model/widgets/sync_status_page.dart`
- **Description:** A technical screen to monitor synchronization processes in real-time.
- **Features:**
  - Monitor sync operation status (Idle, In Progress, Success, Error).
  - View detailed sync results and statistics.
  - Check network connectivity status.
- **Access:** Open the Drawer -> Tap "Sync Diagnostics".

### 5. Performance Dashboard (`PerformanceDashboardScreen`)

- **Path:** `lib/view/home/performance_dashboard_screen.dart`
- **Description:** A comprehensive dashboard to monitor app performance and system health.
- **Features:**
  - **Overview:** System status, health score, and performance trends.
  - **Queries:** Analysis of slow and frequent database queries.
  - **Memory:** Memory usage tracking and leak detection.
  - **Health:** Overall system health assessment and optimization recommendations.
- **Access:** Open the Drawer -> Tap "Performance Dashboard".

### 6. System Notifications (`ErrorNotificationScreen`)

- **Path:** `lib/view/home/error_notification_screen.dart`
- **Description:** A central hub for viewing system error logs and notifications.
- **Features:**
  - View error banners and logs.
  - Monitor system health and recovery actions.
- **Access:** Open the Drawer -> Tap "System Notifications".

## Existing Navigation Structure

### Bottom Navigation Bar

1.  **Home:** `ProductDashBoard` (POS Grid)
2.  **Restaurant:** `RestaurantScreen` (Table/Dining Management)
3.  **Calculator:** `PLUCalculatorScreen` (Quick Bill/Cart)
4.  **Search:** `SearchReceiptScreen` (Find past receipts)

### Drawer Menu

- **Printer Status:** Connection indicator.
- **Connect/Disconnect Printer:** Printer management.
- **My Customers:** (New) Customer list management.
- **Saved Orders:** (New) Held bill management.
- **Offline Status & Bills:** (New) View local bills and sync status.
- **System Notifications:** (New) View error logs.
- **Sales Report:** Daily sales summary.
- **Billwise Report:** Detailed bill history.
- **Itemwise Report:** Item sales analysis.
- **Datewise Report:** Sales by date range.
- **Edit Bill Receipt:** Customize receipt header/footer.
- **Log Out:** Sign out of the application.
