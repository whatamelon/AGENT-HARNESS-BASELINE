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
  group('normalizeKrMobile', () {
    test('accepts and normalizes 010 domestic form', () {
      expect(normalizeKrMobile('010-1234-5678'), '+821012345678');
      expect(normalizeKrMobile('01012345678'), '+821012345678');
    });

    test('passes through valid E.164', () {
      expect(normalizeKrMobile('+821012345678'), '+821012345678');
    });

    test('rejects malformed numbers', () {
      expect(normalizeKrMobile('123'), isNull);
      expect(normalizeKrMobile('011-1234-5678'), isNull); // not 010
      expect(normalizeKrMobile('+1 415 555 1234'), isNull);
      expect(normalizeKrMobile('0101234567'), isNull); // too short
    });
  });

  group('SmsAuthClient.requestCode', () {
    test('rejects malformed phone before any network call', () async {
      final adapter = _FakeAdapter(statusCode: 200);
      final client = SmsAuthClient(_clientWith(adapter));

      final result = await client.requestCode('123');
      expect(result.isErr, isTrue);
      expect(
        result.fold((_) => null, (e) => e.failure),
        SmsFailure.invalid,
      );
      expect(adapter.lastOptions, isNull, reason: 'must not hit server');
    });

    test(
        '200 -> Ok with server TTL, correct endpoint + normalized body + '
        'Authorization header from session token', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        bodyJson: {'ok': true, 'ttlSeconds': 180},
      );
      final client = SmsAuthClient(_clientWith(adapter, token: 'jwt-req'));

      final result = await client.requestCode('010-1234-5678');
      expect(result.isOk, isTrue);
      expect(result.fold((v) => v.ttlSeconds, (_) => -1), 180);
      expect(adapter.lastOptions?.path, '/functions/v1/sms-request-code');
      expect(adapter.lastOptions?.data, {'phone': '+821012345678'});
      // requestCode now requires auth (server binds code to the user); the
      // shared ApiClient injects the Bearer header on every request.
      expect(adapter.lastOptions?.headers['Authorization'], 'Bearer jwt-req');
    });

    test('429 -> Err(rateLimited) carrying retryAfter', () async {
      final adapter = _FakeAdapter(
        statusCode: 429,
        bodyJson: {'ok': false, 'retryAfter': 42},
      );
      final client = SmsAuthClient(_clientWith(adapter));

      final result = await client.requestCode('01012345678');
      expect(result.isErr, isTrue);
      final err = result.fold((_) => null, (e) => e);
      expect(err?.failure, SmsFailure.rateLimited);
      expect(err?.retryAfterSeconds, 42);
      expect(err?.message, contains('42'));
    });
  });

  group('SmsAuthClient.verifyCode', () {
    test('sends Authorization header from the session token', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        bodyJson: {'verified': true},
      );
      final client = SmsAuthClient(_clientWith(adapter, token: 'jwt-abc'));

      final result = await client.verifyCode('01012345678', '123456');
      expect(result.isOk, isTrue);
      expect(result.fold((v) => v, (_) => false), isTrue);
      expect(adapter.lastOptions?.path, '/functions/v1/sms-verify-code');
      expect(adapter.lastOptions?.headers['Authorization'], 'Bearer jwt-abc');
      expect(
        adapter.lastOptions?.data,
        {'phone': '+821012345678', 'code': '123456'},
      );
    });

    test('rejects non-6-digit code pre-flight', () async {
      final adapter = _FakeAdapter(statusCode: 200);
      final client = SmsAuthClient(_clientWith(adapter, token: 'jwt'));

      final result = await client.verifyCode('01012345678', '12ab');
      expect(result.isErr, isTrue);
      expect(adapter.lastOptions, isNull);
    });

    test('400 invalid -> Err(invalid)', () async {
      final adapter = _FakeAdapter(
        statusCode: 400,
        bodyJson: {'verified': false, 'reason': 'invalid'},
      );
      final client = SmsAuthClient(_clientWith(adapter, token: 'jwt'));

      final result = await client.verifyCode('01012345678', '000000');
      expect(result.fold((_) => null, (e) => e.failure), SmsFailure.invalid);
    });

    test('400 expired -> Err(expired)', () async {
      final adapter = _FakeAdapter(
        statusCode: 400,
        bodyJson: {'verified': false, 'reason': 'expired'},
      );
      final client = SmsAuthClient(_clientWith(adapter, token: 'jwt'));

      final result = await client.verifyCode('01012345678', '000000');
      expect(result.fold((_) => null, (e) => e.failure), SmsFailure.expired);
    });

    test('400 too_many_attempts -> Err(tooManyAttempts)', () async {
      final adapter = _FakeAdapter(
        statusCode: 400,
        bodyJson: {'verified': false, 'reason': 'too_many_attempts'},
      );
      final client = SmsAuthClient(_clientWith(adapter, token: 'jwt'));

      final result = await client.verifyCode('01012345678', '000000');
      expect(
        result.fold((_) => null, (e) => e.failure),
        SmsFailure.tooManyAttempts,
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
      final client = SmsAuthClient(_clientWith(adapter, token: 'jwt'));

      final result = await client.verifyCode('01012345678', '123456');
      expect(result.fold((_) => null, (e) => e.failure), SmsFailure.transport);
    });
  });
}
