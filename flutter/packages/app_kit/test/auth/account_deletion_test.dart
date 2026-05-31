import 'dart:convert';
import 'dart:typed_data';

import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns a canned response (or error) and records the last request.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.statusCode, this.bodyJson, this.error});
  final int statusCode;
  final Map<String, dynamic>? bodyJson;
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
    return ResponseBody.fromString(
      jsonEncode(bodyJson ?? <String, dynamic>{}),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _clientWith(_FakeAdapter adapter, {String? token}) => ApiClient(
      dio: Dio()..httpClientAdapter = adapter,
      tokenProvider: token == null ? null : () => token,
    );

void main() {
  group('AccountDeletionClient.deleteAccount', () {
    test('200 deleted -> Ok, correct endpoint + auth header', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        bodyJson: {'status': 'deleted'},
      );
      final client = AccountDeletionClient(
        _clientWith(adapter, token: 'jwt-d'),
      );

      final result = await client.deleteAccount();

      expect(result.isOk, isTrue);
      expect(adapter.lastOptions?.path, kAccountDeletePath);
      expect(adapter.lastOptions?.headers['Authorization'], 'Bearer jwt-d');
    });

    test('200 already_deleted -> Ok (idempotent success)', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        bodyJson: {'status': 'already_deleted'},
      );
      final client = AccountDeletionClient(_clientWith(adapter, token: 'jwt'));

      final result = await client.deleteAccount();
      expect(result.isOk, isTrue);
    });

    test('forwards optional userId in the body', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        bodyJson: {'status': 'deleted'},
      );
      final client = AccountDeletionClient(_clientWith(adapter, token: 'jwt'));

      await client.deleteAccount(userId: 'u-123');
      expect(adapter.lastOptions?.data, {'userId': 'u-123'});
    });

    test('omits the body entirely when no userId is given', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        bodyJson: {'status': 'deleted'},
      );
      final client = AccountDeletionClient(_clientWith(adapter, token: 'jwt'));

      await client.deleteAccount();
      expect(adapter.lastOptions?.data, isNull);
    });

    test('403 forbidden -> Err(forbidden)', () async {
      final adapter = _FakeAdapter(
        statusCode: 403,
        bodyJson: {'error': 'forbidden'},
      );
      final client = AccountDeletionClient(_clientWith(adapter, token: 'jwt'));

      final result = await client.deleteAccount(userId: 'other');
      expect(
        result.fold((_) => null, (e) => e.failure),
        AccountDeletionFailure.forbidden,
      );
    });

    test('401 unauthenticated -> Err(unauthenticated)', () async {
      final adapter = _FakeAdapter(
        statusCode: 401,
        bodyJson: {'error': 'unauthenticated'},
      );
      final client = AccountDeletionClient(_clientWith(adapter));

      final result = await client.deleteAccount();
      expect(
        result.fold((_) => null, (e) => e.failure),
        AccountDeletionFailure.unauthenticated,
      );
    });

    test('400 invalid -> Err(invalid)', () async {
      final adapter = _FakeAdapter(
        statusCode: 400,
        bodyJson: {'error': 'invalid'},
      );
      final client = AccountDeletionClient(_clientWith(adapter, token: 'jwt'));

      final result = await client.deleteAccount();
      expect(
        result.fold((_) => null, (e) => e.failure),
        AccountDeletionFailure.invalid,
      );
    });

    test('500 server_error -> Err(unknown)', () async {
      final adapter = _FakeAdapter(
        statusCode: 500,
        bodyJson: {'error': 'server_error'},
      );
      final client = AccountDeletionClient(_clientWith(adapter, token: 'jwt'));

      final result = await client.deleteAccount();
      expect(
        result.fold((_) => null, (e) => e.failure),
        AccountDeletionFailure.unknown,
      );
    });

    test('network failure -> Err(transport)', () async {
      final adapter = _FakeAdapter(
        statusCode: 0,
        error: DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      final client = AccountDeletionClient(_clientWith(adapter, token: 'jwt'));

      final result = await client.deleteAccount();
      expect(
        result.fold((_) => null, (e) => e.failure),
        AccountDeletionFailure.transport,
      );
    });

    test('Korean failure messages are populated', () {
      expect(
        accountDeletionFailureMessage(AccountDeletionFailure.forbidden),
        contains('본인 계정'),
      );
      expect(
        const AccountDeletionError(AccountDeletionFailure.unauthenticated)
            .message,
        contains('로그인'),
      );
    });
  });
}
