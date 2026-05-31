/// 401 single-flight refresh-retry interceptor for the raw `Dio`/`ApiClient`
/// (Edge Functions / Next.js BFF / custom backends).
///
/// The Supabase REST/RPC client self-handles 401 refresh internally, so this
/// is ONLY for the token-forwarding raw client (§5.6/§13.1). Behaviour:
///  - On a 401 that has not already been retried, share ONE refresh future
///    across all concurrent 401s (single-flight latch) — N parallel requests
///    that all 401 trigger exactly ONE refresh.
///  - If refresh succeeds, retry the original request ONCE with the new token,
///    tagging it via `extra['__retried__']` so a second 401 cannot loop.
///  - If refresh fails (or the retry 401s again), invoke the `onUnrecoverable`
///    callback (the host triggers sign-out) and propagate the error.
///
/// SDK-free and unit-testable: all collaborators are injected callbacks + a
/// retry `Dio`. Tokens are never logged here.
library;

import 'package:dio/dio.dart';

/// Marks a request as already retried after a refresh, so a second 401 on the
/// same request is propagated instead of looping forever.
const String kRetriedExtraKey = '__retried__';

/// Performs a token refresh, returning `true` on success.
typedef RefreshSession = Future<bool> Function();

/// Supplies the current bearer access token, or `null` when signed out.
typedef CurrentToken = String? Function();

/// Invoked when the session cannot be recovered (refresh failed / repeated
/// 401). The host typically signs the user out here.
typedef OnUnrecoverable = Future<void> Function();

/// dio [Interceptor] that refreshes the session once on 401 and retries the
/// original request, deduping concurrent refreshes via a single-flight latch.
class AuthRefreshInterceptor extends Interceptor {
  /// Creates an [AuthRefreshInterceptor].
  ///
  /// [refresh] performs the token refresh; [currentToken] reads the (possibly
  /// new) access token to re-stamp the retried request; [onUnrecoverable] runs
  /// when recovery is impossible; [retryDio] re-issues the original request
  /// (must NOT itself carry this interceptor, to avoid recursion).
  AuthRefreshInterceptor({
    required RefreshSession refresh,
    required CurrentToken currentToken,
    required OnUnrecoverable onUnrecoverable,
    required Dio retryDio,
  })  : _refresh = refresh,
        _currentToken = currentToken,
        _onUnrecoverable = onUnrecoverable,
        _retryDio = retryDio;

  final RefreshSession _refresh;
  final CurrentToken _currentToken;
  final OnUnrecoverable _onUnrecoverable;
  final Dio _retryDio;

  /// The shared in-flight refresh future, or `null` when no refresh is running.
  /// All concurrent 401s await this same future (single-flight).
  Future<bool>? _inFlightRefresh;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final options = err.requestOptions;

    final isUnauthorized = response?.statusCode == 401;
    final alreadyRetried = options.extra[kRetriedExtraKey] == true;

    if (!isUnauthorized || alreadyRetried) {
      // Not our concern, or we already gave it one retry — propagate.
      handler.next(err);
      return;
    }

    final refreshed = await _sharedRefresh();
    if (!refreshed) {
      await _onUnrecoverable();
      handler.next(err);
      return;
    }

    try {
      final retried = await _retryOriginal(options);
      handler.resolve(retried);
    } on DioException catch (retryErr) {
      // The retry itself failed. A second 401 means the fresh token is also
      // rejected -> unrecoverable. Either way, no further retry (the request is
      // tagged), so this cannot loop.
      if (retryErr.response?.statusCode == 401) {
        await _onUnrecoverable();
      }
      handler.next(retryErr);
    }
  }

  /// Returns the shared refresh future, creating it only if none is running.
  ///
  /// The latch is cleared in a `whenComplete` so the NEXT independent 401 wave
  /// can refresh again — but all 401s racing during a single refresh collapse
  /// onto one call.
  Future<bool> _sharedRefresh() {
    final existing = _inFlightRefresh;
    if (existing != null) return existing;
    final future = _refresh().whenComplete(() => _inFlightRefresh = null);
    _inFlightRefresh = future;
    return future;
  }

  Future<Response<dynamic>> _retryOriginal(RequestOptions options) {
    final token = _currentToken();
    final headers = Map<String, dynamic>.of(options.headers);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final retryOptions = Options(
      method: options.method,
      headers: headers,
      responseType: options.responseType,
      contentType: options.contentType,
      sendTimeout: options.sendTimeout,
      receiveTimeout: options.receiveTimeout,
      extra: {...options.extra, kRetriedExtraKey: true},
    );
    return _retryDio.request<dynamic>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      cancelToken: options.cancelToken,
      options: retryOptions,
    );
  }
}
