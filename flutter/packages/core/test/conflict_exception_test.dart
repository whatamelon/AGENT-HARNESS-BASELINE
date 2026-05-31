import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter returning a canned response (mirrors api_client_test's helper).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.response);

  final ResponseBody response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      response;

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

ApiClient _client(ResponseBody response) =>
    ApiClient(dio: Dio()..httpClientAdapter = _FakeAdapter(response));

AppException? _errOf(Result<Object?, AppException> r) =>
    r.fold((_) => null, (f) => f);

void main() {
  group('ApiClient 409 -> ConflictException', () {
    test('extracts the server status token from the 409 body', () async {
      final client =
          _client(_json('{"status":"amount_mismatch"}', 409));

      final result = await client.post<Map<String, dynamic>>('/confirm');
      expect(result.isErr, isTrue);
      final err = _errOf(result);
      expect(err, isA<ConflictException>());
      expect((err! as ConflictException).status, 'amount_mismatch');
    });

    test('maps already_confirmed and order_not_pending statuses', () async {
      final a =
          await _client(_json('{"status":"already_confirmed"}', 409))
              .post<Map<String, dynamic>>('/confirm');
      expect((_errOf(a)! as ConflictException).status, 'already_confirmed');

      final b =
          await _client(_json('{"status":"order_not_pending"}', 409))
              .post<Map<String, dynamic>>('/confirm');
      expect((_errOf(b)! as ConflictException).status, 'order_not_pending');
    });

    test('409 with no status body yields ConflictException(status: null)',
        () async {
      final client = _client(_json('{}', 409));

      final result = await client.post<Map<String, dynamic>>('/confirm');
      final err = _errOf(result);
      expect(err, isA<ConflictException>());
      expect((err! as ConflictException).status, isNull);
    });

    test('400 stays a generic failure (not a conflict)', () async {
      final client = _client(_json('{"error":"bad"}', 400));

      final result = await client.post<Map<String, dynamic>>('/confirm');
      expect(_errOf(result), isNot(isA<ConflictException>()));
    });
  });
}
