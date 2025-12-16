import 'package:flutter/material.dart';
import '../backend/network_error_handler.dart';

/// Example widget demonstrating how to use NetworkErrorHandler
/// for graceful network error handling throughout the app
class NetworkErrorExample extends StatefulWidget {
  const NetworkErrorExample({Key? key}) : super(key: key);

  @override
  State<NetworkErrorExample> createState() => _NetworkErrorExampleState();
}

class _NetworkErrorExampleState extends State<NetworkErrorExample> {
  bool _isLoading = false;
  String? _data;
  dynamic _lastError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Error Handling Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Network Error Handling Examples:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Example 1: Simple network operation with error handling
            ElevatedButton(
              onPressed: _isLoading ? null : _performNetworkOperation,
              child: _isLoading 
                ? const CircularProgressIndicator()
                : const Text('Test Network Operation'),
            ),
            
            const SizedBox(height: 16),
            
            // Example 2: Show offline indicator
            NetworkErrorHandler.buildOfflineIndicator(
              message: 'This is how offline mode looks',
              onRetry: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Retry button pressed!')),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Example 3: Network error widget
            if (_lastError != null && NetworkErrorHandler.isNetworkError(_lastError))
              Expanded(
                child: NetworkErrorHandler.buildNetworkErrorWidget(
                  error: _lastError!,
                  onRetry: _performNetworkOperation,
                ),
              ),
            
            // Example 4: Success state
            if (_data != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(height: 8),
                    Text(
                      'Success: $_data',
                      style: TextStyle(color: Colors.green.shade900),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Features Demonstrated:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• Automatic network error detection'),
                Text('• User-friendly error messages'),
                Text('• Offline indicators and retry buttons'),
                Text('• Graceful error handling with fallbacks'),
                Text('• Consistent UI patterns for network states'),
                Text('• Proper logging for debugging'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performNetworkOperation() async {
    setState(() {
      _isLoading = true;
      _data = null;
      _lastError = null;
    });

    // Simulate a network operation that might fail
    final result = await NetworkErrorHandler.executeWithNetworkHandling<String>(
      operation: () async {
        // Simulate network delay
        await Future.delayed(const Duration(seconds: 2));
        
        // Simulate random network failure (50% chance)
        if (DateTime.now().millisecond % 2 == 0) {
          throw Exception('Simulated network error for demonstration');
        }
        
        return 'Data loaded successfully at ${DateTime.now()}';
      },
      context: context,
      operationName: 'performNetworkOperation',
      component: 'NetworkErrorExample',
      fallbackValue: null,
      showUserMessage: true,
    );

    setState(() {
      _isLoading = false;
      if (result != null) {
        _data = result;
      } else {
        _lastError = Exception('Network operation failed');
      }
    });
  }
}