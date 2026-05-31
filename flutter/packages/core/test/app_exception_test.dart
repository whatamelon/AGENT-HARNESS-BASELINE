import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

RequestOptions _opts() => RequestOptions(path: '/x');

DioException _dio(DioExceptionType type, {int? status}) => DioException(
      requestOptions: _opts(),
      type: type,
      response: status == null
          ? null
          : Response<dynamic>(requestOptions: _opts(), statusCode: status),
    );

void main() {
  group('normalizeDioException', () {
    test('timeouts map to TimeoutException', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(normalizeDioException(_dio(t)), isA<TimeoutException>());
      }
    });

    test('connection error maps to NetworkException', () {
      expect(
        normalizeDioException(_dio(DioExceptionType.connectionError)),
        isA<NetworkException>(),
      );
    });

    test('401/403 map to UnauthorizedException', () {
      expect(
        normalizeDioException(
          _dio(DioExceptionType.badResponse, status: 401),
        ),
        isA<UnauthorizedException>(),
      );
      expect(
        normalizeDioException(
          _dio(DioExceptionType.badResponse, status: 403),
        ),
        isA<UnauthorizedException>(),
      );
    });

    test('5xx maps to ServerException with status', () {
      final ex = normalizeDioException(
        _dio(DioExceptionType.badResponse, status: 503),
      );
      expect(ex, isA<ServerException>());
      expect((ex as ServerException).statusCode, 503);
    });

    test('4xx (non-auth) maps to UnknownException', () {
      expect(
        normalizeDioException(
          _dio(DioExceptionType.badResponse, status: 422),
        ),
        isA<UnknownException>(),
      );
    });

    test('messages are Korean and non-empty', () {
      const exceptions = <AppException>[
        NetworkException(),
        TimeoutException(),
        UnauthorizedException(),
        ServerException(),
        UnknownException(),
      ];
      for (final e in exceptions) {
        expect(e.message, isNotEmpty);
        expect(RegExp('[가-힣]').hasMatch(e.message), isTrue);
      }
    });
  });

  group('log redaction', () {
    test('masks bearer token, email, phone', () {
      final out = redactSensitive(
        'Bearer abc.def-123 user@example.com 010-1234-5678',
      );
      expect(out.contains('abc.def-123'), isFalse);
      expect(out.contains('user@example.com'), isFalse);
      expect(out.contains('010-1234-5678'), isFalse);
    });

    test('masks sensitive headers', () {
      final masked = redactHeaders(<String, Object?>{
        'Authorization': 'Bearer secret',
        'apikey': 'anon-key',
        'Content-Type': 'application/json',
      });
      expect(masked['Authorization'], '***');
      expect(masked['apikey'], '***');
      expect(masked['Content-Type'], 'application/json');
    });
  });
}
