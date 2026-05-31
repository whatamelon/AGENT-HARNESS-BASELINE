import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter that returns a canned response or throws a canned error.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter({this.response, this.error});

  final ResponseBody? response;
  final DioException? error;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    final err = error;
    if (err != null) {
      throw DioException(requestOptions: options, type: err.type);
    }
    return response!;
  }

  @override
  void close({bool force = false}) {}
}

Dio dioWith(FakeAdapter adapter) => Dio()..httpClientAdapter = adapter;

AppException? errOf(Result<Object?, AppException> r) =>
    r.fold((_) => null, (f) => f);

void main() {
  group('ApiClient', () {
    test('successful GET returns Ok with data', () async {
      final adapter = FakeAdapter(
        response: ResponseBody.fromString(
          '{"k":"v"}',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );
      final client = ApiClient(dio: dioWith(adapter));

      final result = await client.get<Map<String, dynamic>>('/x');
      expect(result.isOk, isTrue);
      expect(result.fold((v) => v['k'], (_) => null), 'v');
    });

    test('timeout error maps to Err(TimeoutException)', () async {
      final adapter = FakeAdapter(
        error: DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      final client = ApiClient(dio: dioWith(adapter));

      final result = await client.get<dynamic>('/x');
      expect(result.isErr, isTrue);
      expect(errOf(result), isA<TimeoutException>());
    });

    test('401 maps to Err(UnauthorizedException)', () async {
      final adapter = FakeAdapter(
        response: ResponseBody.fromString('unauthorized', 401),
      );
      final client = ApiClient(dio: dioWith(adapter));

      final result = await client.get<dynamic>('/x');
      expect(result.isErr, isTrue);
      expect(errOf(result), isA<UnauthorizedException>());
    });

    test('500 maps to Err(ServerException)', () async {
      final adapter = FakeAdapter(
        response: ResponseBody.fromString('boom', 500),
      );
      final client = ApiClient(dio: dioWith(adapter));

      final result = await client.get<dynamic>('/x');
      expect(result.isErr, isTrue);
      expect(errOf(result), isA<ServerException>());
    });

    test('connection error maps to Err(NetworkException)', () async {
      final adapter = FakeAdapter(
        error: DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      final client = ApiClient(dio: dioWith(adapter));

      final result = await client.get<dynamic>('/x');
      expect(result.isErr, isTrue);
      expect(errOf(result), isA<NetworkException>());
    });

    test('injects Authorization header from tokenProvider', () async {
      final adapter = FakeAdapter(
        response: ResponseBody.fromString(
          '{}',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );
      final client = ApiClient(
        dio: dioWith(adapter),
        tokenProvider: () => 'tok123',
      );

      await client.get<dynamic>('/x');
      expect(adapter.lastOptions?.headers['Authorization'], 'Bearer tok123');
    });

    test('omits Authorization header when no token', () async {
      final adapter = FakeAdapter(
        response: ResponseBody.fromString(
          '{}',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );
      final client = ApiClient(dio: dioWith(adapter));

      await client.get<dynamic>('/x');
      expect(
        adapter.lastOptions?.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });
}
