/// Production billing wiring — binds `BillingBackend` to the Toss
/// `tosspayments_widget_sdk_flutter` billing-method flow.
///
/// Like `payment_wiring.dart` / `auth_wiring.dart` / `push_wiring.dart` this is
/// the ONLY billing file that touches a Toss type, and it is excluded from unit
/// tests (which use the `BillingBackend` fake). Live key arrival / real billing
/// runtime is yipark's; the harness compiles + abstracts.
///
/// SDK GAP (honest boundary) — `tosspayments_widget_sdk_flutter` 2.2.0 exposes
/// only `PaymentWidget.requestPayment` (one-shot). It has NO first-class
/// `requestBillingAuth`. The billing-key `authKey` is produced by Toss's
/// billing authorization window, which yipark integrates via its own entrypoint
/// (Toss billing SDK / hosted billing-auth URL). To keep the seam honest rather
/// than fabricating a non-existent SDK call, this backend takes an
/// app-injected `authKeyFlow` callback that runs that yipark-owned flow and
/// returns the Toss outcome. The widget SDK type is referenced (the
/// `PaymentWidget` handle the host already owns is threaded through) so this
/// file stays the SDK-coupled wiring layer; the window itself is yipark's.
///
/// §8-A: the client key is app-injected (see `payment_wiring.dart`); no secret
/// key lives here. The `authKey` carries NO amount — the server exchanges it
/// for a billing key and owns every future charge.
library;

import 'package:app_kit/src/payments/billing_backend.dart';
import 'package:tosspayments_widget_sdk_flutter/model/tosspayments_result.dart'
    as toss_result;
import 'package:tosspayments_widget_sdk_flutter/payment_widget.dart';

/// Runs the app-owned Toss billing-authorization window for a
/// [BillingAuthRequest] and returns the raw Toss `Result`. yipark supplies this
/// (it owns the concrete billing-auth entrypoint the widget SDK 2.2.0 lacks).
typedef TossBillingAuthFlow = Future<toss_result.Result> Function(
  BillingAuthRequest request,
);

/// `BillingBackend` over the Toss billing-method flow.
///
/// `paymentWidget` is the same handle the UI host owns (threaded through so
/// this stays the SDK-coupled layer); `authKeyFlow` is the yipark-owned window
/// that actually yields the Toss billing `authKey`.
class TossBillingBackend implements BillingBackend {
  /// Creates a [TossBillingBackend].
  TossBillingBackend({
    required PaymentWidget paymentWidget,
    required TossBillingAuthFlow authKeyFlow,
  })  : _widget = paymentWidget,
        _authKeyFlow = authKeyFlow;

  // Retained so the host's widget lifecycle (redirect handling) stays bound to
  // this backend; the billing-auth window is driven via _authKeyFlow.
  // ignore: unused_field
  final PaymentWidget _widget;
  final TossBillingAuthFlow _authKeyFlow;

  @override
  Future<BillingAuthResult> requestBillingAuth({
    required BillingAuthRequest request,
  }) async {
    final result = await _authKeyFlow(request);
    return _normalize(result, customerKey: request.customerKey);
  }

  static BillingAuthResult _normalize(
    toss_result.Result result, {
    required String customerKey,
  }) {
    final success = result.success;
    if (success != null) {
      // Toss returns the billing authKey in `additionalParams['authKey']` for
      // the billing-auth flow; the paymentKey field is unused for billing.
      final authKey =
          success.additionalParams?['authKey'] ?? success.paymentKey;
      return BillingAuthSuccess(authKey: authKey, customerKey: customerKey);
    }
    final fail = result.fail;
    if (fail != null) {
      return BillingAuthFailure(
        code: fail.errorCode,
        message: fail.errorMessage,
      );
    }
    // Defensive: an empty Result should not occur, but never throw across the
    // seam — treat it as a generic failure.
    return const BillingAuthFailure(
      code: 'UNKNOWN',
      message: '결제수단 등록 결과를 확인할 수 없습니다.',
    );
  }
}
