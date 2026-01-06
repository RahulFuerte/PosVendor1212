/// Base failure class for domain layer errors
abstract class Failure {
  final String message;
  final String? code;
  
  const Failure(this.message, {this.code});
  
  @override
  String toString() => 'Failure: $message${code != null ? ' (code: $code)' : ''}';
}

/// Server/Network related failures
class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

/// Local database failures
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.code});
}

/// Cache failures
class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code});
}

/// Network connectivity failures
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

/// Sync failures
class SyncFailure extends Failure {
  final int? pendingCount;
  const SyncFailure(super.message, {super.code, this.pendingCount});
}
