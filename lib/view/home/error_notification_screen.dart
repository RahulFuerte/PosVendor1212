import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../tab_screen/view-model/widgets/error_notification_widget.dart';
import '../tab_screen/view-model/backend/user_error_service.dart';
import '../tab_screen/view-model/backend/error_recovery_service.dart';

/// Full screen wrapper for ErrorNotificationWidget
class ErrorNotificationScreen extends StatefulWidget {
  const ErrorNotificationScreen({Key? key}) : super(key: key);

  @override
  State<ErrorNotificationScreen> createState() => _ErrorNotificationScreenState();
}

class _ErrorNotificationScreenState extends State<ErrorNotificationScreen> {
  late UserErrorService _userErrorService;
  late ErrorRecoveryService _recoveryService;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    try {
      // Try to get services from Provider, or create new instances if not available
      _userErrorService = Provider.of<UserErrorService>(context, listen: false);
      _recoveryService = Provider.of<ErrorRecoveryService>(context, listen: false);
      setState(() {
        _servicesInitialized = true;
      });
    } catch (e) {
      // If Provider services are not available, create new instances
      _userErrorService = UserErrorService();
      _recoveryService = ErrorRecoveryService();
      setState(() {
        _servicesInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Notifications'),
        backgroundColor: Colors.red[50],
      ),
      body: _servicesInitialized
          ? Column(
              children: [
                // Error banner at the top
                ErrorBannerWidget(
                  userErrorService: _userErrorService,
                  recoveryService: _recoveryService,
                ),
                // Main content area
                Expanded(
                  child: Stack(
                    children: [
                      // Background content
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_active,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Error Notifications',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'System errors and notifications will appear here',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Error notifications overlay
                      ErrorNotificationWidget(
                        userErrorService: _userErrorService,
                        recoveryService: _recoveryService,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}