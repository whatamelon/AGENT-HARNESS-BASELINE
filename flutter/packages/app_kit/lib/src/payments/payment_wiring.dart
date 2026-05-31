/// Production payment wiring — binds [PaymentBackend] to the Toss
/// `tosspayments_widget_sdk_flutter` `PaymentWidget`.
///
/// This is the ONLY file that imports a Toss type; like `auth_wiring.dart` /
/// `push_wiring.dart` it is excluded from unit tests (which use the
/// [PaymentBackend] fake). Live key arrival / real payment runtime is yipark's;
/// the harness compiles + abstracts.
///
/// §8-A H-4: the **client key is app-injected** (yipark supplies it to the
/// `TossPaymentBackend` constructor). No Toss secret key, no successUrl
/// secret — only the publishable client key + Supabase anon live in the
/// client. The secretKey-based `payment-confirm` runs server-side (Lane B).
library;

import 'package:app_kit/src/payments/payment_backend.dart';
import 'package:tosspayments_widget_sdk_flutter/model/payment_info.dart';
import 'package:tosspayments_widget_sdk_flutter/model/payment_widget_options.dart'
    as toss_opts;
import 'package:tosspayments_widget_sdk_flutter/model/tosspayments_result.dart'
    as toss_result;
import 'package:tosspayments_widget_sdk_flutter/payment_widget.dart';

/// Creates a Toss [PaymentWidget] from an **app-injected** client key.
///
/// [clientKey] is yipark's publishable Toss client key — never a secret key.
/// [customerKey] must be a sufficiently random, stable per-customer id (use
/// [PaymentWidget.anonymous] for guest/one-off flows).
PaymentWidget buildTossPaymentWidget({
  required String clientKey,
  required String customerKey,
}) =>
    PaymentWidget(clientKey: clientKey, customerKey: customerKey);

/// [PaymentBackend] over a live Toss [PaymentWidget].
///
/// The `paymentWidget` is created by the UI host (it also mounts the
/// `PaymentMethodWidget`/`AgreementWidget` that this backend renders into).
/// [appScheme] is the app's custom URL scheme Toss uses to return from external
/// bank/card apps; the host's deep-link handler forwards the redirect back via
/// `PaymentWidget.handlePaymentRedirect`.
class TossPaymentBackend implements PaymentBackend {
  /// Creates a [TossPaymentBackend].
  TossPaymentBackend({
    required PaymentWidget paymentWidget,
    required String methodSelector,
    this.appScheme,
  })  : _widget = paymentWidget,
        _methodSelector = methodSelector;

  final PaymentWidget _widget;
  final String _methodSelector;

  /// App custom scheme for external-app return (e.g. `yipark://`).
  final String? appScheme;

  @override
  Future<void> renderPaymentMethods({required PaymentAmount amount}) async {
    await _widget.renderPaymentMethods(
      selector: _methodSelector,
      amount: toss_opts.Amount(
        value: amount.value,
        currency: _toCurrency(amount.currency),
        country: amount.country,
      ),
    );
  }

  @override
  Future<PaymentBackendResult> requestPayment({
    required PaymentRequest request,
  }) async {
    final result = await _widget.requestPayment(
      paymentInfo: PaymentInfo(
        orderId: request.orderId,
        orderName: request.orderName,
        customerName: request.customerName,
        customerEmail: request.customerEmail,
        appScheme: appScheme,
      ),
    );
    return _normalize(result, fallbackOrderId: request.orderId);
  }

  static toss_opts.Currency _toCurrency(PaymentCurrency currency) =>
      switch (currency) {
        PaymentCurrency.krw => toss_opts.Currency.KRW,
      };

  static PaymentBackendResult _normalize(
    toss_result.Result result, {
    required String fallbackOrderId,
  }) {
    final success = result.success;
    if (success != null) {
      return PaymentBackendSuccess(
        paymentKey: success.paymentKey,
        orderId: success.orderId,
        amount: success.amount,
      );
    }
    final pending = result.pending;
    if (pending != null) {
      return PaymentBackendPending(
        paymentKey: pending.paymentKey,
        orderId: pending.orderId,
        amount: pending.amount,
      );
    }
    final fail = result.fail;
    if (fail != null) {
      return PaymentBackendFailure(
        code: fail.errorCode,
        message: fail.errorMessage,
        orderId: fail.orderId,
      );
    }
    // Defensive: an empty Result should not occur, but never throw across the
    // seam — treat it as a generic failure.
    return PaymentBackendFailure(
      code: 'UNKNOWN',
      message: '결제 결과를 확인할 수 없습니다.',
      orderId: fallbackOrderId,
    );
  }
}
