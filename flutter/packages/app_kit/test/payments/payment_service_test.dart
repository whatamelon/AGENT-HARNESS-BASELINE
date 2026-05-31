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
    // dio keeps the request body as the original object (a Map here) on
    // RequestOptions.data; only the wire encoding turns it into JSON.
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

PaymentService _service(_RecordingAdapter adapter) => PaymentService(
      apiClient: core.ApiClient(dio: Dio()..httpClientAdapter = adapter),
    );

void main() {
  group('PaymentService.createOrder', () {
    test('parses {orderId, amount, orderName} from the server', () async {
      final adapter = _RecordingAdapter({
        kPaymentCreateOrderPath: () => _json(
              '{"orderId":"ord_1","amount":120000,"orderName":"용인공원 계약"}',
              200,
            ),
      });

      final result = await _service(adapter).createOrder({'productId': 'p1'});

      expect(result.isOk, isTrue);
      final order = result.fold((o) => o, (_) => null)!;
      expect(order.orderId, 'ord_1');
      expect(order.amount, 120000);
      expect(order.orderName, '용인공원 계약');
    });

    test('malformed response -> PaymentError.invalid', () async {
      final adapter = _RecordingAdapter({
        kPaymentCreateOrderPath: () => _json('{"orderId":""}', 200),
      });

      final result = await _service(adapter).createOrder({'productId': 'p1'});
      expect(result.fold((_) => null, (e) => e), PaymentError.invalid);
    });

    test('401 -> PaymentError.unauthorized', () async {
      final adapter = _RecordingAdapter({
        kPaymentCreateOrderPath: () => _json('{}', 401),
      });

      final result = await _service(adapter).createOrder({'productId': 'p1'});
      expect(result.fold((_) => null, (e) => e), PaymentError.unauthorized);
    });
  });

  group('PaymentService.confirm — §8-A amount 비신뢰', () {
    test('sends ONLY {orderId, paymentKey} (no amount) on confirm', () async {
      final adapter = _RecordingAdapter({
        kPaymentConfirmPath: () =>
            _json('{"status":"confirmed","orderId":"ord_1"}', 200),
      });

      final result = await _service(adapter).confirm(
        orderId: 'ord_1',
        paymentKey: 'pk_live_abcd',
      );

      expect(result.isOk, isTrue);
      final body = adapter.bodyFor(kPaymentConfirmPath);
      expect(body.keys.toSet(), {'orderId', 'paymentKey'});
      expect(body['orderId'], 'ord_1');
      expect(body['paymentKey'], 'pk_live_abcd');
      // The Toss-reported amount must NEVER appear in the confirm body.
      expect(body.containsKey('amount'), isFalse);
    });

    test('409 already_confirmed -> PaymentError.alreadyConfirmed', () async {
      final adapter = _RecordingAdapter({
        kPaymentConfirmPath: () => _json('{"status":"already_confirmed"}', 409),
      });

      final result =
          await _service(adapter).confirm(orderId: 'o', paymentKey: 'k');
      expect(
        result.fold((_) => null, (e) => e),
        PaymentError.alreadyConfirmed,
      );
    });

    test('409 amount_mismatch -> PaymentError.amountMismatch', () async {
      final adapter = _RecordingAdapter({
        kPaymentConfirmPath: () => _json('{"status":"amount_mismatch"}', 409),
      });

      final result =
          await _service(adapter).confirm(orderId: 'o', paymentKey: 'k');
      expect(result.fold((_) => null, (e) => e), PaymentError.amountMismatch);
    });

    test('409 order_not_pending -> PaymentError.orderNotPending', () async {
      final adapter = _RecordingAdapter({
        kPaymentConfirmPath: () => _json('{"status":"order_not_pending"}', 409),
      });

      final result =
          await _service(adapter).confirm(orderId: 'o', paymentKey: 'k');
      expect(result.fold((_) => null, (e) => e), PaymentError.orderNotPending);
    });

    test('400 -> PaymentError.invalid', () async {
      final adapter = _RecordingAdapter({
        kPaymentConfirmPath: () => _json('{"error":"bad"}', 400),
      });

      final result =
          await _service(adapter).confirm(orderId: 'o', paymentKey: 'k');
      expect(result.fold((_) => null, (e) => e), PaymentError.invalid);
    });
  });

  group('PaymentService.pay — end to end', () {
    test('Toss success amount is NOT forwarded to confirm (§8-A)', () async {
      final adapter = _RecordingAdapter({
        kPaymentCreateOrderPath: () => _json(
              '{"orderId":"ord_9","amount":50000,"orderName":"상조"}',
              200,
            ),
        kPaymentConfirmPath: () =>
            _json('{"status":"confirmed","orderId":"ord_9"}', 200),
      });

      // The fake "render" reports a DIFFERENT amount than the server order to
      // prove the client never trusts/forwards the Toss-reported amount.
      final result = await _service(adapter).pay(
        orderInput: {'productId': 'p9'},
        buildRequest: (order) => PaymentRequest(
          orderId: order.orderId,
          orderName: order.orderName,
        ),
        render: (order, request) async => const PaymentBackendSuccess(
          paymentKey: 'pk_xyz',
          orderId: 'ord_9',
          amount: 999999, // tampered/attacker amount — must be ignored
        ),
      );

      expect(result.isOk, isTrue);
      final confirmBody = adapter.bodyFor(kPaymentConfirmPath);
      expect(confirmBody.containsKey('amount'), isFalse);
      expect(confirmBody['orderId'], 'ord_9');
      expect(confirmBody['paymentKey'], 'pk_xyz');
    });

    test('user cancel -> PaymentError.canceled, no confirm call', () async {
      final adapter = _RecordingAdapter({
        kPaymentCreateOrderPath: () => _json(
              '{"orderId":"ord_c","amount":1000,"orderName":"x"}',
              200,
            ),
      });

      final result = await _service(adapter).pay(
        orderInput: {'p': 1},
        buildRequest: (o) =>
            PaymentRequest(orderId: o.orderId, orderName: o.orderName),
        render: (o, r) async => const PaymentBackendFailure(
          code: 'PAY_PROCESS_CANCELED',
          message: '취소',
          orderId: 'ord_c',
        ),
      );

      expect(result.fold((_) => null, (e) => e), PaymentError.canceled);
      expect(
        adapter.requests.any((r) => r.path == kPaymentConfirmPath),
        isFalse,
      );
    });

    test('Toss failure -> PaymentError.paymentFailed', () async {
      final adapter = _RecordingAdapter({
        kPaymentCreateOrderPath: () => _json(
              '{"orderId":"ord_f","amount":1000,"orderName":"x"}',
              200,
            ),
      });

      final result = await _service(adapter).pay(
        orderInput: {'p': 1},
        buildRequest: (o) =>
            PaymentRequest(orderId: o.orderId, orderName: o.orderName),
        render: (o, r) async => const PaymentBackendFailure(
          code: 'REJECT_CARD_COMPANY',
          message: '카드사 거절',
          orderId: 'ord_f',
        ),
      );

      expect(result.fold((_) => null, (e) => e), PaymentError.paymentFailed);
    });

    test('create-order failure short-circuits before render', () async {
      final adapter = _RecordingAdapter({
        kPaymentCreateOrderPath: () => _json('{}', 401),
      });
      var rendered = false;

      final result = await _service(adapter).pay(
        orderInput: {'p': 1},
        buildRequest: (o) =>
            PaymentRequest(orderId: o.orderId, orderName: o.orderName),
        render: (o, r) async {
          rendered = true;
          return const PaymentBackendSuccess(
            paymentKey: 'k',
            orderId: 'o',
            amount: 1,
          );
        },
      );

      expect(result.fold((_) => null, (e) => e), PaymentError.unauthorized);
      expect(rendered, isFalse);
    });
  });
}
