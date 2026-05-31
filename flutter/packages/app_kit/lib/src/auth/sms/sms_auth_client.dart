/// SMS phone-verification client (CLIENT ONLY).
///
/// §8-A H-6: the client never decides verification — it calls the Edge
/// Functions and renders state. The server owns the code, attempts, expiry, and
/// the `phone_verified` write. The client only:
///   - normalizes/validates the KR mobile number (reject malformed pre-flight),
///   - posts to the shared Edge Function contract,
///   - normalizes responses into a `Result` with Korean messages.
///
/// Shared HTTP contract (must match Lane B server exactly):
/// BOTH endpoints require `Authorization: Bearer <supabase-jwt>` (the flow is
/// social-login first, then phone verification, so a session already exists).
/// The issued code is bound to the requesting user server-side (`requested_by`)
/// and may only be redeemed by that same user (number-takeover block). The
/// shared [ApiClient] injects the Bearer header on every request via its
/// `tokenProvider`, so callers do not set it manually.
/// - `POST /functions/v1/sms-request-code` (header `Authorization: Bearer <jwt>`)
///   body `{"phone":"+8210XXXXXXXX"}`
///   - `200 {"ok":true,"ttlSeconds":180}` (uniform; existence not disclosed)
///   - `401 {"ok":false,"reason":"unauthenticated"}`
///   - `429 {"ok":false,"retryAfter":<sec>}`
/// - `POST /functions/v1/sms-verify-code` (header `Authorization: Bearer <jwt>`)
///   body `{"phone":"+8210XXXXXXXX","code":"123456"}`
///   - `200 {"verified":true}`
///   - `400 {"verified":false,"reason":"invalid|expired|too_many_attempts"}`
///   - `401 {"verified":false,"reason":"unauthenticated"}`
///
/// `Result` failure type is [SmsError] (a sibling of core's sealed
/// `AppException`, which cannot be extended): it carries a structured
/// [SmsFailure] reason plus an optional underlying transport [AppException].
library;

import 'package:core/core.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:meta/meta.dart';

/// Outcome of a `requestCode` call.
@immutable
class SmsRequestResult {
  /// Creates an [SmsRequestResult].
  const SmsRequestResult({required this.ttlSeconds});

  /// Seconds the code remains valid (server-authoritative).
  final int ttlSeconds;
}

/// Reason an SMS request/verification failed.
enum SmsFailure {
  /// Malformed phone number or wrong code (client- or server-detected).
  invalid,

  /// Code expired.
  expired,

  /// Too many attempts; locked out.
  tooManyAttempts,

  /// Rate limited at request stage (429).
  rateLimited,

  /// Transport/network failure.
  transport,

  /// Anything else.
  unknown,
}

/// Korean, user-facing message for an [SmsFailure].
String smsFailureMessage(SmsFailure failure, {int? retryAfterSeconds}) {
  switch (failure) {
    case SmsFailure.invalid:
      return '인증번호 또는 휴대폰 번호가 올바르지 않습니다.';
    case SmsFailure.expired:
      return '인증번호가 만료되었습니다. 다시 요청해 주세요.';
    case SmsFailure.tooManyAttempts:
      return '시도 횟수를 초과했습니다. 잠시 후 다시 시도해 주세요.';
    case SmsFailure.rateLimited:
      final wait = retryAfterSeconds;
      return wait == null
          ? '요청이 많습니다. 잠시 후 다시 시도해 주세요.'
          : '요청이 많습니다. $wait초 후 다시 시도해 주세요.';
    case SmsFailure.transport:
      return '네트워크 연결을 확인해 주세요.';
    case SmsFailure.unknown:
      return '인증을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }
}

/// Structured client-side error for the SMS flow.
@immutable
class SmsError {
  /// Creates an [SmsError].
  const SmsError(this.failure, {this.retryAfterSeconds, this.cause});

  /// The structured failure reason.
  final SmsFailure failure;

  /// Seconds to wait before retrying when [failure] is
  /// [SmsFailure.rateLimited].
  final int? retryAfterSeconds;

  /// Underlying transport failure, when this wraps an [AppException].
  final AppException? cause;

  /// Korean, user-facing message.
  String get message =>
      smsFailureMessage(failure, retryAfterSeconds: retryAfterSeconds);

  @override
  bool operator ==(Object other) =>
      other is SmsError &&
      other.failure == failure &&
      other.retryAfterSeconds == retryAfterSeconds;

  @override
  int get hashCode => Object.hash(failure, retryAfterSeconds);

  @override
  String toString() => 'SmsError(${failure.name})';
}

/// Normalizes a user-entered KR mobile number to E.164 `+8210XXXXXXXX`.
///
/// Accepts `010XXXXXXXX` (11 digits) or already-`+8210XXXXXXXX`; returns `null`
/// when the input is not a valid KR mobile number. Pure/synchronous so callers
/// can validate before any network call (H-6: reject malformed pre-flight).
String? normalizeKrMobile(String input) {
  final digits = input.replaceAll(RegExp(r'[^\d+]'), '');
  // +8210######## (E.164): country 82 + 10 + 8 subscriber digits.
  final e164 = RegExp(r'^\+8210\d{8}$');
  if (e164.hasMatch(digits)) return digits;
  // 010######## (domestic 11 digits).
  final domestic = RegExp(r'^010\d{8}$');
  if (domestic.hasMatch(digits)) {
    return '+8210${digits.substring(3)}';
  }
  return null;
}

/// Client for the SMS verification Edge Functions.
class SmsAuthClient {
  /// Creates an [SmsAuthClient] over a configured [ApiClient].
  const SmsAuthClient(this._api);

  static const _requestPath = '/functions/v1/sms-request-code';
  static const _verifyPath = '/functions/v1/sms-verify-code';

  final ApiClient _api;

  /// Requests an SMS code for [phone].
  ///
  /// Requires an authenticated session — the [ApiClient] must already inject
  /// the Supabase JWT (the issued code is bound to the signed-in user
  /// server-side). Validates the number client-side first; on success returns
  /// the server-reported TTL. A 429 maps to [SmsFailure.rateLimited] carrying
  /// `retryAfter`.
  Future<Result<SmsRequestResult, SmsError>> requestCode(String phone) async {
    final normalized = normalizeKrMobile(phone);
    if (normalized == null) {
      return const Err(SmsError(SmsFailure.invalid));
    }

    final result = await _api.post<Map<String, dynamic>>(
      _requestPath,
      body: <String, String>{'phone': normalized},
    );
    return result.fold(
      (data) => Ok(
        SmsRequestResult(ttlSeconds: _asInt(data['ttlSeconds']) ?? 0),
      ),
      (e) => Err(_mapRequestError(e)),
    );
  }

  /// Verifies [code] for [phone]. Requires an authenticated session — the
  /// [ApiClient] must already inject the Supabase JWT (number is bound to the
  /// signed-in user server-side).
  Future<Result<bool, SmsError>> verifyCode(String phone, String code) async {
    final normalized = normalizeKrMobile(phone);
    if (normalized == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      return const Err(SmsError(SmsFailure.invalid));
    }

    final result = await _api.post<Map<String, dynamic>>(
      _verifyPath,
      body: <String, String>{'phone': normalized, 'code': code},
    );
    return result.fold(
      (data) => (data['verified'] == true)
          ? const Ok(true)
          : Err(SmsError(_reasonOf(data['reason']))),
      (e) => Err(_mapVerifyError(e)),
    );
  }

  SmsError _mapRequestError(AppException e) {
    final retryAfter = _retryAfterFrom(e);
    if (retryAfter != null) {
      return SmsError(
        SmsFailure.rateLimited,
        retryAfterSeconds: retryAfter,
        cause: e,
      );
    }
    return SmsError(_transportFailureOf(e), cause: e);
  }

  SmsError _mapVerifyError(AppException e) {
    // A 400 with a JSON body is delivered as Ok(data) by core only on 2xx;
    // dio rejects 4xx, so a server "reason" 400 still reaches here. Recover the
    // reason from the response body when present.
    final reason = _reasonFromBadResponse(e);
    if (reason != null) return SmsError(reason, cause: e);
    return SmsError(_transportFailureOf(e), cause: e);
  }

  SmsFailure _transportFailureOf(AppException e) => switch (e) {
        NetworkException() || TimeoutException() => SmsFailure.transport,
        _ => SmsFailure.unknown,
      };

  SmsFailure _reasonOf(Object? reason) {
    switch (reason) {
      case 'invalid':
        return SmsFailure.invalid;
      case 'expired':
        return SmsFailure.expired;
      case 'too_many_attempts':
        return SmsFailure.tooManyAttempts;
      default:
        return SmsFailure.unknown;
    }
  }

  static int? _asInt(Object? value) => switch (value) {
        final int v => v,
        final num v => v.toInt(),
        final String v => int.tryParse(v),
        _ => null,
      };

  int? _retryAfterFrom(AppException e) {
    // core normalizes a 429 to UnknownException and stores the raw
    // DioException as the cause; the {retryAfter} body lives on its response.
    final cause = e.cause;
    if (cause is! DioException) return null;
    final response = cause.response;
    if (response == null || response.statusCode != 429) return null;
    final data = response.data;
    if (data is Map) return _asInt(data['retryAfter']);
    return null;
  }

  SmsFailure? _reasonFromBadResponse(AppException e) {
    final cause = e.cause;
    if (cause is! DioException) return null;
    final response = cause.response;
    if (response == null || response.statusCode != 400) return null;
    final data = response.data;
    if (data is Map) return _reasonOf(data['reason']);
    return null;
  }
}
