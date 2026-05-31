import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-written fake [PaymentBackend] (no mockito/mocktail) — records the last
/// render amount + request, and returns a canned outcome.
class _FakeBackend implements PaymentBackend {
  _FakeBackend(this._outcome);

  final PaymentBackendResult _outcome;
  PaymentAmount? renderedAmount;
  PaymentRequest? lastRequest;

  @override
  Future<void> renderPaymentMethods({required PaymentAmount amount}) async {
    renderedAmount = amount;
  }

  @override
  Future<PaymentBackendResult> requestPayment({
    required PaymentRequest request,
  }) async {
    lastRequest = request;
    return _outcome;
  }
}

void main() {
  group('PaymentBackend fake flows', () {
    test('success carries paymentKey/orderId/amount', () async {
      final backend = _FakeBackend(
        const PaymentBackendSuccess(
          paymentKey: 'pk_1',
          orderId: 'ord_1',
          amount: 1000,
        ),
      );

      await backend.renderPaymentMethods(
        amount: const PaymentAmount(value: 1000),
      );
      final result = await backend.requestPayment(
        request: const PaymentRequest(orderId: 'ord_1', orderName: '계약'),
      );

      expect(backend.renderedAmount?.value, 1000);
      expect(backend.renderedAmount?.currency, PaymentCurrency.krw);
      expect(result, isA<PaymentBackendSuccess>());
      final success = result as PaymentBackendSuccess;
      expect(success.paymentKey, 'pk_1');
      expect(success.orderId, 'ord_1');
    });

    test('cancellation is a failure flagged isCanceled', () async {
      final backend = _FakeBackend(
        const PaymentBackendFailure(
          code: 'PAY_PROCESS_CANCELED',
          message: '취소',
          orderId: 'ord_2',
        ),
      );

      final result = await backend.requestPayment(
        request: const PaymentRequest(orderId: 'ord_2', orderName: '상조'),
      );

      expect(result, isA<PaymentBackendFailure>());
      expect((result as PaymentBackendFailure).isCanceled, isTrue);
    });

    test('non-cancel failure is not flagged isCanceled', () async {
      final backend = _FakeBackend(
        const PaymentBackendFailure(
          code: 'REJECT_CARD_COMPANY',
          message: '거절',
        ),
      );

      final result = await backend.requestPayment(
        request: const PaymentRequest(orderId: 'o', orderName: 'n'),
      );
      expect((result as PaymentBackendFailure).isCanceled, isFalse);
    });

    test('request forwards only identifiers (no amount in PaymentRequest)',
        () async {
      final backend = _FakeBackend(
        const PaymentBackendSuccess(
          paymentKey: 'k',
          orderId: 'o',
          amount: 1,
        ),
      );

      await backend.requestPayment(
        request: const PaymentRequest(
          orderId: 'ord_x',
          orderName: '주문',
          customerName: '홍길동',
        ),
      );

      // PaymentRequest has no amount field at all — structural §8-A guarantee.
      expect(backend.lastRequest?.orderId, 'ord_x');
      expect(backend.lastRequest?.orderName, '주문');
    });
  });
}
