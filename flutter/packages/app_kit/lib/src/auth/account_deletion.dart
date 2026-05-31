/// In-app account deletion client (CLIENT ONLY) — Apple App Store Guideline
/// 5.1.1(v): an app supporting account creation MUST offer in-app account
/// deletion.
///
/// Mirrors `sms_auth_client.dart`: dio-based (via the shared [ApiClient]),
/// SDK-neutral (no `supabase_flutter` coupling — `dio` only). It returns a
/// `Result` with a structured failure + Korean messages. The server owns the
/// deletion — this client only calls the Edge Function and renders the outcome.
///
/// Shared HTTP contract (must match the `account-delete` Edge Function exactly,
/// see `templates/backend/supabase/functions/account-delete/`):
///   `POST /functions/v1/account-delete` (header `Authorization: Bearer <jwt>`)
///   - body is OPTIONAL; when present `{"userId":"<uuid>"}` MUST equal the
///     token's sub (self-only). The server trusts the token, not the body.
///   - `200 {"status":"deleted"}`           — account removed.
///   - `200 {"status":"already_deleted"}`   — idempotent repeat (treated as
///     success: the account is gone either way).
///   - `401 {"error":"unauthenticated"}`    — no/invalid session.
///   - `403 {"error":"forbidden"}`          — targetId != caller (self-only).
///   - `400 {"error":"invalid"}`            — malformed request.
///   - `405 {"error":"method_not_allowed"}` / `500 {"error":"server_error"}`.
///
/// The shared [ApiClient] injects the Bearer header from the active session, so
/// callers do not set it manually.
///
/// NOTE on status mapping: the [ApiClient] normalizer folds BOTH 401 and 403
/// into [UnauthorizedException]. This client re-reads the underlying
/// [DioException] response to split a 403 `forbidden` (self-only violation) out
/// of a 401 `unauthenticated`, the way `sms_auth_client.dart` recovers a 400
/// reason from the bad-response body.
///
/// `Result` failure type is [AccountDeletionError] (a sibling of core's sealed
/// `AppException`, which cannot be extended).
library;

import 'package:core/core.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:meta/meta.dart';

/// Reason an account-deletion request failed.
enum AccountDeletionFailure {
  /// No/invalid session (401) — the user must re-authenticate.
  unauthenticated,

  /// Self-only violation (403) — a caller tried to delete another account.
  forbidden,

  /// Malformed request (400).
  invalid,

  /// Transport/network failure.
  transport,

  /// Server error (5xx) or anything else.
  unknown,
}

/// Korean, user-facing message for an [AccountDeletionFailure].
String accountDeletionFailureMessage(AccountDeletionFailure failure) {
  switch (failure) {
    case AccountDeletionFailure.unauthenticated:
      return '로그인이 필요합니다. 다시 로그인한 뒤 시도해 주세요.';
    case AccountDeletionFailure.forbidden:
      return '본인 계정만 탈퇴할 수 있습니다.';
    case AccountDeletionFailure.invalid:
      return '요청이 올바르지 않습니다.';
    case AccountDeletionFailure.transport:
      return '네트워크 연결을 확인해 주세요.';
    case AccountDeletionFailure.unknown:
      return '회원 탈퇴를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }
}

/// Structured client-side error for the account-deletion flow.
@immutable
class AccountDeletionError {
  /// Creates an [AccountDeletionError].
  const AccountDeletionError(this.failure, {this.cause});

  /// The structured failure reason.
  final AccountDeletionFailure failure;

  /// Underlying transport failure, when this wraps an [AppException].
  final AppException? cause;

  /// Korean, user-facing message.
  String get message => accountDeletionFailureMessage(failure);

  @override
  bool operator ==(Object other) =>
      other is AccountDeletionError && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'AccountDeletionError(${failure.name})';
}

/// Path of the account-delete Edge Function (joined onto the ApiClient base
/// URL). Matches the deployed `account-delete` function.
const String kAccountDeletePath = '/functions/v1/account-delete';

/// Client for the in-app account-deletion Edge Function.
class AccountDeletionClient {
  /// Creates an [AccountDeletionClient] over a configured [ApiClient].
  const AccountDeletionClient(this._api);

  final ApiClient _api;

  /// Requests deletion of the **signed-in** user's account.
  ///
  /// Requires an authenticated session — the [ApiClient] injects the Supabase
  /// JWT and the server resolves the user from the token's sub. [userId] is an
  /// optional defense-in-depth echo of the caller's own id; when provided it
  /// MUST equal the token's sub server-side (otherwise `forbidden`).
  ///
  /// Idempotent: an `already_deleted` server response maps to [Ok] — the
  /// account is gone either way, so a retried/duplicated tap succeeds.
  Future<Result<void, AccountDeletionError>> deleteAccount({
    String? userId,
  }) async {
    final result = await _api.post<Map<String, dynamic>>(
      kAccountDeletePath,
      body: userId == null ? null : <String, String>{'userId': userId},
    );
    return result.fold(
      (data) {
        final status = data['status'];
        if (status == 'deleted' || status == 'already_deleted') {
          return const Ok(null);
        }
        // A 200 with an unexpected body is treated as a generic failure.
        return const Err(AccountDeletionError(AccountDeletionFailure.unknown));
      },
      (e) => Err(_mapError(e)),
    );
  }

  AccountDeletionError _mapError(AppException e) {
    switch (e) {
      case UnauthorizedException():
        // 401 and 403 both arrive here; split by the underlying HTTP status.
        return _statusCodeOf(e) == 403
            ? AccountDeletionError(AccountDeletionFailure.forbidden, cause: e)
            : AccountDeletionError(
                AccountDeletionFailure.unauthenticated,
                cause: e,
              );
      case NetworkException():
      case TimeoutException():
        return AccountDeletionError(
          AccountDeletionFailure.transport,
          cause: e,
        );
      case ServerException():
        return AccountDeletionError(AccountDeletionFailure.unknown, cause: e);
      case ConflictException():
      case UnknownException():
        // A 400 surfaces as UnknownException; recover the "invalid" body reason
        // (mirrors sms_auth_client's _reasonFromBadResponse).
        return _statusCodeOf(e) == 400 || _bodyErrorOf(e) == 'invalid'
            ? AccountDeletionError(AccountDeletionFailure.invalid, cause: e)
            : AccountDeletionError(AccountDeletionFailure.unknown, cause: e);
    }
  }

  /// HTTP status code of the underlying [DioException] response, when present.
  int? _statusCodeOf(AppException e) {
    final cause = e.cause;
    if (cause is! DioException) return null;
    return cause.response?.statusCode;
  }

  /// `error` token from the underlying [DioException] response body, when JSON.
  String? _bodyErrorOf(AppException e) {
    final cause = e.cause;
    if (cause is! DioException) return null;
    final data = cause.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is String) return error;
    }
    return null;
  }
}
