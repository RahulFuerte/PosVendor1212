// Project imports:
import 'package:pos/core/error/failures.dart';

/// Base use case interface
/// [Type] is the return type
/// [Params] is the input parameters type
abstract class UseCase<Type, Params> {
  Future<Result<Type>> call(Params params);
}

/// Use case with no parameters
abstract class UseCaseNoParams<Type> {
  Future<Result<Type>> call();
}

/// Result wrapper for use case responses
/// Provides a clean way to handle success/failure without exceptions
class Result<T> {
  final T? data;
  final Failure? failure;
  
  const Result._({this.data, this.failure});
  
  factory Result.success(T data) => Result._(data: data);
  factory Result.failure(Failure failure) => Result._(failure: failure);
  
  bool get isSuccess => failure == null;
  bool get isFailure => failure != null;
  
  /// Fold the result into a single value
  R fold<R>(R Function(Failure failure) onFailure, R Function(T data) onSuccess) {
    if (isFailure) {
      return onFailure(failure!);
    }
    return onSuccess(data as T);
  }
  
  /// Map the success value
  Result<R> map<R>(R Function(T data) mapper) {
    if (isFailure) {
      return Result.failure(failure!);
    }
    return Result.success(mapper(data as T));
  }
}

/// No parameters marker class
class NoParams {
  const NoParams();
}
