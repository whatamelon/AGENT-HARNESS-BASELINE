/// Domain-level network error taxonomy.
///
/// Raw transport errors (e.g. `DioException`) are normalized into this sealed
/// hierarchy at the client boundary so callers reason about domain failures,
/// never about HTTP internals. Messages are Korean, user-facing, and must not
/// leak secrets or raw responses.
library;

import 'package:meta/meta.dart';

/// Base type for all normalized network failures.
@immutable
sealed class AppException implements Exception {
  /// Creates an [AppException] with a [code], user-facing [message], and an
  /// optional underlying [cause].
  const AppException(this.code, this.message, {this.cause});

  /// Stable machine code for the failure (safe to log; no PII).
  final String code;

  /// Korean, user-facing message safe to surface in UI.
  final String message;

  /// Underlying cause for diagnostics. Never rendered to users.
  final Object? cause;

  @override
  String toString() => 'AppException($code): $message';
}

/// Connectivity failure (no route to host, DNS, connection refused).
@immutable
final class NetworkException extends AppException {
  /// Creates a [NetworkException].
  const NetworkException({Object? cause})
      : super('network', '네트워크 연결을 확인해 주세요.', cause: cause);
}

/// Request exceeded its time budget.
@immutable
final class TimeoutException extends AppException {
  /// Creates a [TimeoutException].
  const TimeoutException({Object? cause})
      : super(
          'timeout',
          '요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.',
          cause: cause,
        );
}

/// Authentication/authorization failure (HTTP 401/403).
@immutable
final class UnauthorizedException extends AppException {
  /// Creates an [UnauthorizedException].
  const UnauthorizedException({Object? cause})
      : super('unauthorized', '로그인이 필요하거나 권한이 없습니다.', cause: cause);
}

/// Resource conflict (HTTP 409). Carries the server's machine-readable
/// [status] (e.g. `already_confirmed`, `amount_mismatch`) when the response
/// body provides one, so callers can branch on the conflict reason without
/// parsing raw HTTP. The [status] is a stable, non-PII token safe to keep.
@immutable
final class ConflictException extends AppException {
  /// Creates a [ConflictException].
  const ConflictException({this.status, Object? cause})
      : super('conflict', '요청이 현재 상태와 충돌합니다.', cause: cause);

  /// Server-provided conflict status token, or `null` when absent.
  final String? status;
}

/// Server-side failure (HTTP 5xx).
@immutable
final class ServerException extends AppException {
  /// Creates a [ServerException], optionally carrying the HTTP [statusCode].
  const ServerException({this.statusCode, Object? cause})
      : super('server', '서버에 일시적인 문제가 발생했습니다.', cause: cause);

  /// HTTP status code when available.
  final int? statusCode;
}

/// Anything not covered by the cases above.
@immutable
final class UnknownException extends AppException {
  /// Creates an [UnknownException].
  const UnknownException({Object? cause})
      : super('unknown', '알 수 없는 오류가 발생했습니다.', cause: cause);
}
