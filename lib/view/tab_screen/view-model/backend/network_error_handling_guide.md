# Network Error Handling Guide

This guide explains how network connectivity issues and `SocketException` errors are handled throughout the POS application.

## Overview

The application now includes comprehensive network error handling to ensure graceful operation when:
- Device is offline
- Network connection is unstable
- Remote servers are unreachable
- DNS resolution fails (like the `india.amritsr.com` error)

## Key Components

### 1. NetworkErrorHandler Utility Class
Location: `lib/view/tab_screen/view-model/backend/network_error_handler.dart`

**Features:**
- Automatic network error detection
- User-friendly error messages
- Consistent UI patterns for network states
- Proper logging for debugging
- Retry functionality

**Key Methods:**
```dart
// Check if error is network-related
NetworkErrorHandler.isNetworkError(error)

// Get user-friendly error message
NetworkErrorHandler.getNetworkErrorMessage(error)

// Show error snackbar
NetworkErrorHandler.showNetworkErrorSnackBar(context, error)

// Execute operation with error handling
NetworkErrorHandler.executeWithNetworkHandling(...)

// Build UI widgets for network errors
NetworkErrorHandler.buildNetworkErrorWidget(...)
NetworkErrorHandler.buildOfflineIndicator(...)
```

### 2. Enhanced CachedBlobImage Widget
Location: `lib/view/tab_screen/view-model/widgets/cached_blob_image.dart`

**Features:**
- Offline-first image loading
- Automatic fallback to cached images
- Graceful network error handling
- Tap-to-retry functionality
- Proper error logging

**Error Handling:**
- Shows offline indicator for `SocketException`
- Allows users to retry when connection is restored
- Falls back to cached images when available
- Displays appropriate placeholder/error widgets

### 3. Improved ProductDashBoard
Location: `lib/view/home/productDashBoard.dart`

**Enhancements:**
- Network-aware data fetching
- Cached data fallbacks
- Improved avatar image loading
- User-friendly error messages
- Proper logging throughout

**Key Improvements:**
- `fetchUserData()` - Caches user data for offline use
- `fetchAdminUid()` - Falls back to cached adminUid
- Avatar image - Graceful network error handling
- All Firebase operations - Proper error handling

## Error Types Handled

### 1. SocketException
**Causes:**
- No internet connection
- DNS resolution failures (like `india.amritsr.com`)
- Network timeouts
- Server unreachable

**Handling:**
- Automatic detection
- User-friendly messages
- Fallback to cached data
- Retry functionality

### 2. Firebase Connectivity Issues
**Causes:**
- Firebase servers unreachable
- Authentication failures
- Regional server issues

**Handling:**
- Graceful degradation
- Local data fallbacks
- User notifications
- Automatic retry when online

### 3. Image Loading Failures
**Causes:**
- Image servers unreachable
- Invalid URLs
- Network timeouts

**Handling:**
- BLOB cache fallbacks
- Placeholder images
- Retry functionality
- Offline indicators

## Usage Examples

### Basic Network Operation
```dart
final result = await NetworkErrorHandler.executeWithNetworkHandling<String>(
  operation: () async {
    return await someNetworkOperation();
  },
  context: context,
  operationName: 'fetchData',
  component: 'MyWidget',
  fallbackValue: null,
  showUserMessage: true,
);
```

### Image with Network Error Handling
```dart
CachedBlobImage(
  imageUrl: 'https://example.com/image.jpg',
  tableName: 'food_items',
  recordId: 'item_123',
  width: 200,
  height: 150,
  // Automatic error handling included
)
```

### Custom Error Widget
```dart
if (NetworkErrorHandler.isNetworkError(error)) {
  return NetworkErrorHandler.buildNetworkErrorWidget(
    error: error,
    onRetry: () => _retryOperation(),
  );
}
```

## Best Practices

### 1. Always Use Offline-First Approach
- Check local cache first
- Fetch from network as secondary
- Cache successful network responses

### 2. Provide User Feedback
- Show loading states
- Display meaningful error messages
- Offer retry options
- Indicate offline mode

### 3. Graceful Degradation
- Continue operation with cached data
- Disable network-dependent features
- Provide alternative workflows

### 4. Proper Logging
- Use `developer.log()` instead of `print()`
- Include component names
- Log error details for debugging
- Distinguish between error types

## Testing Network Errors

### 1. Simulate Offline Mode
- Turn off device internet
- Use airplane mode
- Block specific domains

### 2. Test Error Scenarios
- Invalid URLs
- Timeout conditions
- DNS failures
- Server unavailability

### 3. Verify Fallbacks
- Cached data loading
- Error message display
- Retry functionality
- UI state consistency

## Common SocketException Messages

### "Failed host lookup"
- **Cause:** DNS resolution failed
- **Solution:** Check internet connection, verify URL
- **Handling:** Show offline indicator, use cached data

### "Network is unreachable"
- **Cause:** No network connectivity
- **Solution:** Check network settings
- **Handling:** Enable offline mode, show retry option

### "Connection timed out"
- **Cause:** Server not responding
- **Solution:** Retry operation, check server status
- **Handling:** Show timeout message, offer retry

## Monitoring and Debugging

### 1. Error Logging
All network errors are logged with:
- Component name
- Operation name
- Error details
- Stack trace (when needed)

### 2. User Feedback
Users receive:
- Clear error messages
- Offline indicators
- Retry options
- Status updates

### 3. Fallback Mechanisms
- Cached data loading
- Default values
- Alternative workflows
- Graceful degradation

## Future Enhancements

### 1. Connection Monitoring
- Real-time connectivity status
- Automatic retry when online
- Background sync queuing

### 2. Advanced Caching
- Intelligent cache management
- Selective data refresh
- Cache expiration policies

### 3. Performance Optimization
- Request batching
- Compression
- CDN integration

## Conclusion

The network error handling system ensures that the POS application remains functional even when network connectivity is poor or unavailable. Users experience graceful degradation with clear feedback and retry options, while developers benefit from comprehensive logging and debugging tools.

The `SocketException` errors like the one for `india.amritsr.com` are now handled gracefully throughout the application, providing a smooth user experience regardless of network conditions.