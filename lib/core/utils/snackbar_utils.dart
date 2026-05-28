import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

class SnackBarUtils {
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Shows a success SnackBar (Green)
  static void showSuccess(BuildContext? context, String message) {
    _show(context, message, Colors.green);
  }

  /// Shows an error SnackBar (Red)
  static void showError(BuildContext? context, String message) {
    _show(context, message, Colors.red);
  }

  /// Shows a warning SnackBar (Orange/Amber)
  static void showWarning(BuildContext? context, String message) {
    _show(context, message, Colors.orange);
  }

  /// Shows an info SnackBar (Blue or Primary)
  static void showInfo(BuildContext? context, String message, {Color? color}) {
    _show(context, message, color ?? Colors.blue);
  }

  /// Internal method to show the snackbar
  static void _show(BuildContext? context, String message, Color backgroundColor) {
    final snackBar = SnackBar(
      content: MyText(
        text: message,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );

    try {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      } else {
        // Use the global messenger key if context is null or not available
        messengerKey.currentState?.hideCurrentSnackBar();
        messengerKey.currentState?.showSnackBar(snackBar);
      }
    } catch (e) {
      // Silently ignore if widget is deactivated
      debugPrint('SnackBar error: $e');
    }
  }
}
