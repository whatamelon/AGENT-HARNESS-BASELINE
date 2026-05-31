import 'dart:convert';
import 'dart:typed_data';

import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart' as core;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records each request and returns a canned response keyed by path.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._byPath);

  final Map<String, ResponseBody Function()> _byPath;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final builder = _byPath[options.path];
    if (builder == null) {
      return ResponseBody.fromString('{}', 404);
    }
    return builder();
  }

  @override
  void close({bool force = false}) {}

  Map<String, dynamic> bodyFor(String path) {
    final req = requests.firstWhere((r) => r.path == path);
    final data = req.data;
    if (data is String) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return Map<String, dynamic>.from(data as Map);
  }
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

BillingService _service(_RecordingAdapter adapter) => BillingService(
      apiClient: core.ApiClient(dio: Dio()..httpClientAdapter = adapter),
    );

const _authRequest = BillingAuthRequest(customerKey: 'cust_1');

void main() {
  group('BillingService.register — §8-A amount 비신뢰', () {
    test('sends ONLY {authKey, customerKey} (no amount) on register', () async {
      final adapter = _RecordingAdapter({
        kBillingRegisterPath: () =>
            _json('{"billingId":"bm_1"}', 200),
      });

      final result = await _service(adapter).register(
        authRequest: _authRequest,
        request: (req) async => const BillingAuthSuccess(
          authKey: 'authkey_abc',
          customerKey: 'cust_1',
        ),
      );

      expect(result.isOk, isTrue);
      expect(result.fold((m) => m.billingId, (_) => null), 'bm_1');
      final body = adapter.bodyFor(kBillingRegisterPath);
      expect(body.keys.toSet(), {'authKey', 'customerKey'});
      expect(body.containsKey('amount'), isFalse);
      expect(body['authKey'], 'authkey_abc');
      expect(body['customerKey'], 'cust_1');
    });

    test('user cancel -> BillingError.canceled, no register call', () async {
      final adapter = _RecordingAdapter({});

      final result = await _service(adapter).register(
        authRequest: _authRequest,
        request: (req) async => const BillingAuthFailure(
          code: 'PAY_PROCESS_CANCELED',
          message: '취소',
        ),
      );

      expect(result.fold((_) => null, (e) => e), BillingError.canceled);
      expect(
        adapter.requests.any((r) => r.path == kBillingRegisterPath),
        isFalse,
      );
    });

    test('auth failure -> BillingError.authFailed', () async {
      final adapter = _RecordingAdapter({});

      final result = await _service(adapter).register(
        authRequest: _authRequest,
        request: (req) async => const BillingAuthFailure(
          code: 'INVALID_CARD',
          message: '카드 오류',
        ),
      );

      expect(result.fold((_) => null, (e) => e), BillingError.authFailed);
    });

    test('malformed register response -> BillingError.invalid', () async {
      final adapter = _RecordingAdapter({
        kBillingRegisterPath: () => _json('{"billingId":""}', 200),
      });

      final result = await _service(adapter).register(
        authRequest: _authRequest,
        request: (req) async => const BillingAuthSuccess(
          authKey: 'k',
          customerKey: 'cust_1',
        ),
      );

      expect(result.fold((_) => null, (e) => e), BillingError.invalid);
    });

    test('409 already_exists -> BillingError.alreadyExists', () async {
      final adapter = _RecordingAdapter({
        kBillingRegisterPath: () => _json('{"status":"already_exists"}', 409),
      });

      final result = await _service(adapter).register(
        authRequest: _authRequest,
        request: (req) async => const BillingAuthSuccess(
          authKey: 'k',
          customerKey: 'cust_1',
        ),
      );

      expect(result.fold((_) => null, (e) => e), BillingError.alreadyExists);
    });

    test('401 -> BillingError.unauthorized', () async {
      final adapter = _RecordingAdapter({
        kBillingRegisterPath: () => _json('{}', 401),
      });

      final result = await _service(adapter).register(
        authRequest: _authRequest,
        request: (req) async => const BillingAuthSuccess(
          authKey: 'k',
          customerKey: 'cust_1',
        ),
      );

      expect(result.fold((_) => null, (e) => e), BillingError.unauthorized);
    });
  });

  group('BillingService.cancel', () {
    test('200 canceled -> Ok, sends only {billingId}', () async {
      final adapter = _RecordingAdapter({
        kBillingCancelPath: () => _json('{"status":"canceled"}', 200),
      });

      final result = await _service(adapter).cancel(billingId: 'bm_9');

      expect(result.isOk, isTrue);
      final body = adapter.bodyFor(kBillingCancelPath);
      expect(body.keys.toSet(), {'billingId'});
      expect(body['billingId'], 'bm_9');
    });

    test('200 already_canceled -> Ok (idempotent)', () async {
      final adapter = _RecordingAdapter({
        kBillingCancelPath: () => _json('{"status":"already_canceled"}', 200),
      });

      final result = await _service(adapter).cancel(billingId: 'bm_9');
      expect(result.isOk, isTrue);
    });

    test('409 not_found -> BillingError.notFound', () async {
      final adapter = _RecordingAdapter({
        kBillingCancelPath: () => _json('{"status":"not_found"}', 409),
      });

      final result = await _service(adapter).cancel(billingId: 'bm_x');
      expect(result.fold((_) => null, (e) => e), BillingError.notFound);
    });

    test('network failure -> BillingError.network', () async {
      final adapter = _RecordingAdapter({});
      // No path registered -> 404 -> UnknownException -> invalid; use a real
      // transport error instead for the network branch.
      final client = core.ApiClient(
        dio: Dio()
          ..httpClientAdapter = _RecordingAdapter({
            kBillingCancelPath: () => throw DioException(
                  requestOptions: RequestOptions(path: kBillingCancelPath),
                  type: DioExceptionType.connectionError,
                ),
          }),
      );
      final service = BillingService(apiClient: client);

      final result = await service.cancel(billingId: 'bm_x');
      expect(result.fold((_) => null, (e) => e), BillingError.network);
      expect(adapter.requests, isEmpty);
    });

    test('Korean error messages are populated', () {
      expect(billingErrorMessage(BillingError.canceled), contains('취소'));
      expect(billingErrorMessage(BillingError.notFound), contains('찾을 수 없'));
    });
  });
}
