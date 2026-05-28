class ErrorUtils {
  static String getCleanErrorMessage(dynamic error) {
    String message = error.toString();
    
    // Remove "Exception: " prefix
    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }
    
    // Check if it still has "Exception: " (double-wrapped)
    if (message.contains('Exception: ')) {
      message = message.split('Exception: ').last;
    }
    
    // Optional: map common network errors
    if (message.contains('SocketException')) {
      return 'No internet connection';
    }
    
    return message.trim();
  }
}
