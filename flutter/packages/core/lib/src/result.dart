import 'package:meta/meta.dart';

/// An immutable result type representing either success ([Ok]) or
/// failure ([Err]). Prefer this over throwing for recoverable domain errors.
///
/// All transformation methods return new instances — never mutate.
@immutable
sealed class Result<S, F> {
  const Result();

  /// Creates a success result.
  const factory Result.ok(S value) = Ok<S, F>;

  /// Creates a failure result.
  const factory Result.err(F failure) = Err<S, F>;

  /// True when this is an [Ok].
  bool get isOk => this is Ok<S, F>;

  /// True when this is an [Err].
  bool get isErr => this is Err<S, F>;

  /// Collapses both branches into a single value of type [T].
  T fold<T>(T Function(S value) onOk, T Function(F failure) onErr) {
    return switch (this) {
      Ok<S, F>(:final value) => onOk(value),
      Err<S, F>(:final failure) => onErr(failure),
    };
  }

  /// Pattern-match style alias for [fold].
  T when<T>({
    required T Function(S value) ok,
    required T Function(F failure) err,
  }) =>
      fold(ok, err);

  /// Maps the success value, leaving a failure untouched.
  Result<T, F> map<T>(T Function(S value) transform) {
    return switch (this) {
      Ok<S, F>(:final value) => Ok<T, F>(transform(value)),
      Err<S, F>(:final failure) => Err<T, F>(failure),
    };
  }

  /// Maps the failure value, leaving a success untouched.
  Result<S, T> mapErr<T>(T Function(F failure) transform) {
    return switch (this) {
      Ok<S, F>(:final value) => Ok<S, T>(value),
      Err<S, F>(:final failure) => Err<S, T>(transform(failure)),
    };
  }

  /// Returns the success value or [fallback] when this is an [Err].
  S getOrElse(S Function(F failure) fallback) =>
      fold((value) => value, fallback);
}

/// Success branch of [Result].
final class Ok<S, F> extends Result<S, F> {
  const Ok(this.value);

  final S value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<S, F> && other.value == value);

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

/// Failure branch of [Result].
final class Err<S, F> extends Result<S, F> {
  const Err(this.failure);

  final F failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Err<S, F> && other.failure == failure);

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}
