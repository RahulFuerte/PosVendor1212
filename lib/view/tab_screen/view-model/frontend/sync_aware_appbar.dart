import 'package:flutter/material.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/sync_progress_dialog.dart';

/// App bar with integrated sync status indicator
class SyncAwareAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController _controller = TextEditingController();
  final String adminUid;
  final String? title;
  final List<Widget>? additionalActions;
  final VoidCallback? onSyncCompleted;

  SyncAwareAppBar({
    Key? key,
    required this.adminUid,
    this.title,
    this.additionalActions,
    this.onSyncCompleted,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _showSyncDialog(BuildContext context) {
    SyncProgressDialog.show(
      context,
      adminUid: adminUid,
      onSyncCompleted: onSyncCompleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: blueGrey.shade50,
      automaticallyImplyLeading: false,
      title: title != null 
          ? Text(
              title!,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            )
          : TextField(
              controller: _controller,
              cursorColor: Colors.black,
              decoration: InputDecoration(
                hintText: "Search",
                hintStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    // Implement search functionality
                  },
                ),
              ),
            ),
      actions: <Widget>[
        // Additional actions if provided
        if (additionalActions != null) ...additionalActions!,
        
        // Sync status indicator
        SyncStatusIndicator(
          onTap: () => _showSyncDialog(context),
          showBadge: true,
          iconSize: 24.0,
        ),
        
        // Clear button for search (only when no title is provided)
        if (title == null)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _controller.clear();
            },
          ),
        
        const SizedBox(width: 8),
      ],
    );
  }
}