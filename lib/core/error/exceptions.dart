/// Base exception class for data layer errors
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  const AppException(this.message, {this.code, this.originalError});
  
  @override
  String toString() => 'AppException: $message';
}

/// Server/API exceptions
class ServerException extends AppException {
  const ServerException(super.message, {super.code, super.originalError});
}

/// Local database exceptions
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code, super.originalError});
}

/// Cache exceptions
class CacheException extends AppException {
  const CacheException(super.message, {super.code, super.originalError});
}

/// Network exceptions
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.originalError});
}
