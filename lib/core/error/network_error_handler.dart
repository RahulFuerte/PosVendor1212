// Dart imports:
import 'dart:developer' as developer;
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';

/// Utility class for handling network-related errors gracefully
class NetworkErrorHandler {
  /// Checks if an error is network-related
  static bool isNetworkError(dynamic error) {
    return error is SocketException ||
           error.toString().contains('Failed host lookup') ||
           error.toString().contains('Network is unreachable') ||
           error.toString().contains('Connection timed out');
  }

  /// Gets a user-friendly message for network errors
  static String getNetworkErrorMessage(dynamic error) {
    if (error is SocketException) {
      if (error.message.contains('Failed host lookup')) {
        return 'No internet connection. Please check your network settings.';
      } else if (error.message.contains('Connection timed out')) {
        return 'Connection timed out. Please try again.';
      } else {
        return 'Network error. Please check your connection and try again.';
      }
    }
    return 'Connection error. Please try again later.';
  }

  /// Shows a user-friendly snackbar for network errors
  static void showNetworkErrorSnackBar(BuildContext context, dynamic error) {
    if (!isNetworkError(error)) return;

    final message = getNetworkErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Logs network errors with appropriate detail level
  static void logNetworkError(dynamic error, String component, String operation) {
    if (error is SocketException) {
      developer.log(
        'Network error in $operation: ${error.message}',
        name: component,
        error: error,
      );
    } else {
      developer.log(
        'Connection error in $operation: $error',
        name: component,
        error: error,
      );
    }
  }

  /// Executes a network operation with automatic error handling
  static Future<T?> executeWithNetworkHandling<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    required String operationName,
    String component = 'NetworkOperation',
    T? fallbackValue,
    bool showUserMessage = true,
  }) async {
    try {
      return await operation();
    } catch (e) {
      logNetworkError(e, component, operationName);
      
      if (showUserMessage && isNetworkError(e)) {
        showNetworkErrorSnackBar(context, e);
      }
      
      return fallbackValue;
    }
  }

  /// Creates a retry button widget for network errors
  static Widget buildRetryButton({
    required VoidCallback onRetry,
    String text = 'Retry',
    IconData icon = Icons.refresh,
  }) {
    return ElevatedButton.icon(
      onPressed: onRetry,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Creates an offline indicator widget
  static Widget buildOfflineIndicator({
    String message = 'You are offline',
    VoidCallback? onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            buildRetryButton(onRetry: onRetry),
          ],
        ],
      ),
    );
  }

  /// Creates a network error widget for use in UI
  static Widget buildNetworkErrorWidget({
    required dynamic error,
    VoidCallback? onRetry,
    String? customMessage,
  }) {
    final message = customMessage ?? getNetworkErrorMessage(error);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              buildRetryButton(onRetry: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
