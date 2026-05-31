/// Thin, safe `dio` wrapper returning `Result<T, AppException>`.
///
/// Never trusts the client: every call funnels through error normalization so
/// callers handle domain failures, not transport internals. Auth header
/// injection and logging are interceptor-based; the token is supplied lazily by
/// the app layer (P3 connects it to the real session).
library;

import 'package:core/src/logger.dart';
import 'package:core/src/network/app_exception.dart';
import 'package:core/src/network/log_redaction.dart';
import 'package:core/src/result.dart';
import 'package:dio/dio.dart';

/// Lazily supplies the current bearer access token, or `null` when signed out.
typedef AccessTokenProvider = String? Function();

/// Configuration for [ApiClient].
class ApiClientConfig {
  /// Creates an [ApiClientConfig].
  const ApiClientConfig({
    this.baseUrl = '',
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
  });

  /// Base URL prepended to relative paths.
  final String baseUrl;

  /// Connection timeout.
  final Duration connectTimeout;

  /// Response receive timeout.
  final Duration receiveTimeout;
}

/// HTTP client that returns domain results.
class ApiClient {
  /// Creates an [ApiClient].
  ///
  /// Pass a pre-built [dio] for testing (e.g. with a fake adapter); otherwise
  /// one is constructed from [config]. [tokenProvider] supplies the auth token
  /// per request — defaults to none (P3 wires it to the session).
  ApiClient({
    Dio? dio,
    ApiClientConfig config = const ApiClientConfig(),
    AccessTokenProvider? tokenProvider,
    AppLogger logger = const AppLogger(name: 'http'),
  })  : _logger = logger,
        _tokenProvider = tokenProvider ?? _noToken,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = config.baseUrl
      ..connectTimeout = config.connectTimeout
      ..receiveTimeout = config.receiveTimeout;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  final Dio _dio;
  final AppLogger _logger;
  final AccessTokenProvider _tokenProvider;

  static String? _noToken() => null;

  /// Issues a GET request to [path].
  Future<Result<T, AppException>> get<T>(
    String path, {
    Map<String, Object?>? query,
  }) =>
      _send<T>(() => _dio.get<T>(path, queryParameters: query));

  /// Issues a POST request to [path] with optional [body].
  Future<Result<T, AppException>> post<T>(
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) =>
      _send<T>(
        () => _dio.post<T>(path, data: body, queryParameters: query),
      );

  /// Issues a PUT request to [path] with optional [body].
  Future<Result<T, AppException>> put<T>(
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) =>
      _send<T>(
        () => _dio.put<T>(path, data: body, queryParameters: query),
      );

  /// Issues a DELETE request to [path].
  Future<Result<T, AppException>> delete<T>(
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) =>
      _send<T>(
        () => _dio.delete<T>(path, data: body, queryParameters: query),
      );

  Future<Result<T, AppException>> _send<T>(
    Future<Response<T>> Function() run,
  ) async {
    try {
      final response = await run();
      final data = response.data;
      if (data == null) {
        return const Err(UnknownException());
      }
      return Ok(data);
    } on DioException catch (e) {
      return Err(normalizeDioException(e));
    } on AppException catch (e) {
      return Err(e);
    } on Object catch (e) {
      return Err(UnknownException(cause: e));
    }
  }

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    final url = redactSensitive('${options.baseUrl}${options.path}');
    _logger.debug('-> ${options.method} $url');
    handler.next(options);
  }

  void _onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final opts = response.requestOptions;
    final url = redactSensitive('${opts.baseUrl}${opts.path}');
    _logger.debug('<- ${response.statusCode} $url');
    handler.next(response);
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) {
    final opts = error.requestOptions;
    final url = redactSensitive('${opts.baseUrl}${opts.path}');
    final status = error.response?.statusCode;
    _logger.warn('x! ${error.type.name} status=$status $url');
    handler.next(error);
  }
}

/// Maps a raw [DioException] into the [AppException] domain taxonomy.
///
/// Exposed for unit testing of the normalization contract.
AppException normalizeDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return TimeoutException(cause: e);
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return NetworkException(cause: e);
    case DioExceptionType.cancel:
      return UnknownException(cause: e);
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return UnauthorizedException(cause: e);
      }
      if (status == 409) {
        return ConflictException(status: _conflictStatus(e.response?.data));
      }
      if (status != null && status >= 500) {
        return ServerException(statusCode: status, cause: e);
      }
      if (e.type == DioExceptionType.unknown && e.error is Exception) {
        return NetworkException(cause: e);
      }
      return UnknownException(cause: e);
  }
}

/// Extracts a `status` token from a 409 response [body] when present.
///
/// Accepts the decoded map dio yields for JSON responses; anything else yields
/// `null` (the caller then has no machine-readable reason, only the conflict).
String? _conflictStatus(Object? body) {
  if (body is Map) {
    final status = body['status'];
    if (status is String && status.isNotEmpty) return status;
  }
  return null;
}
