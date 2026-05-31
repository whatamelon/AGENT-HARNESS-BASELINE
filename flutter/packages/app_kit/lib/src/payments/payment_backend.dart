/// SDK-neutral payment port — decouples the orchestration/UI from the Toss
/// widget SDK, exactly mirroring the auth/push/deeplink seam convention.
///
/// Nothing in this file imports a Toss type. Production wires it to
/// `tosspayments_widget_sdk_flutter` (see `payment_wiring.dart`, excluded from
/// unit tests); tests supply a hand-written fake (no `mockito`/`mocktail`).
/// Keeping the boundary one-way makes the orchestration in the service
/// fully testable without a webview or live Toss keys (honest boundary).
///
/// STORE POLICY (§8-E) — this is the **PG / 실물·서비스 결제** rail: 용인공원
/// 계약·온유 상조 are physical goods / real-world services, which Apple/Google
/// explicitly allow to settle off-IAP via an external PG (Toss). **Digital
/// content** (in-app entitlements, unlockable digital goods) must instead route
/// through IAP — in Korea, the External Purchase Entitlement (≈26% fee), which
/// MUST NOT be mixed with this PG flow in the same product surface. This module
/// is the PG branch only; an IAP backend is a separate seam (a future
/// `IapPaymentBackend implements PaymentBackend` selected by product type), so
/// callers never accidentally send digital content through the PG rail.
library;

import 'package:meta/meta.dart';

/// Currencies the payment widget understands. Mirrors the Toss `Currency`
/// enum's KRW-first surface without importing the SDK type. KRW is the only
/// currency yipark uses (용인공원 계약 / 온유 상조); the rest exist so the seam
/// is forward-compatible.
enum PaymentCurrency {
  /// Korean won — the only currency in scope for yipark.
  krw,
}

/// The amount + currency + country a payment widget renders for.
///
/// SDK-neutral counterpart of Toss's `Amount`. The numeric [value] is the
/// **server-decided** display amount — the client never originates or mutates
/// it (§8-A 금액 비신뢰). It is shown to the user and handed to the widget for
/// rendering only; it is NOT what the server confirms against.
@immutable
class PaymentAmount {
  /// Creates a [PaymentAmount].
  const PaymentAmount({
    required this.value,
    this.currency = PaymentCurrency.krw,
    this.country = 'KR',
  });

  /// Server-decided display amount.
  final num value;

  /// Display currency (KRW for yipark).
  final PaymentCurrency currency;

  /// ISO country code for the widget.
  final String country;

  @override
  bool operator ==(Object other) =>
      other is PaymentAmount &&
      other.value == value &&
      other.currency == currency &&
      other.country == country;

  @override
  int get hashCode => Object.hash(value, currency, country);
}

/// Identifying inputs the widget needs to open the payment window.
///
/// Deliberately minimal: `orderId`/`orderName` come from the server's
/// `payment-create-order` response; the rest are optional display niceties. No
/// secret or amount-trust path lives here.
@immutable
class PaymentRequest {
  /// Creates a [PaymentRequest].
  const PaymentRequest({
    required this.orderId,
    required this.orderName,
    this.customerName,
    this.customerEmail,
  });

  /// Server-issued order id (the SoT key for confirmation).
  final String orderId;

  /// Human-readable order name shown in the Toss window.
  final String orderName;

  /// Optional customer display name (no PII is logged).
  final String? customerName;

  /// Optional customer email (no PII is logged).
  final String? customerEmail;
}

/// Outcome of a `requestPayment` call, normalized away from the SDK's
/// `Result(success?, fail?, pending?)` shape into a sealed hierarchy so the
/// service layer can pattern-match exhaustively.
@immutable
sealed class PaymentBackendResult {
  const PaymentBackendResult();
}

/// Toss reported the payment authorized. Carries only the fields the server
/// confirm step needs — and crucially, [amount] is **echoed for logging only**;
/// the service never forwards it to the server (§8-A 금액 비신뢰).
@immutable
final class PaymentBackendSuccess extends PaymentBackendResult {
  /// Creates a [PaymentBackendSuccess].
  const PaymentBackendSuccess({
    required this.paymentKey,
    required this.orderId,
    required this.amount,
  });

  /// Toss payment key — confirmed server-side; never trusted as final here.
  final String paymentKey;

  /// Order id echoed back by Toss; must equal the requested order id.
  final String orderId;

  /// Toss-reported amount. Informational only — NOT sent to the server.
  final num amount;
}

/// Toss reported a failure or the user cancelled (Toss surfaces cancellation as
/// a `Fail` with code `PAY_PROCESS_CANCELED`).
@immutable
final class PaymentBackendFailure extends PaymentBackendResult {
  /// Creates a [PaymentBackendFailure].
  const PaymentBackendFailure({
    required this.code,
    required this.message,
    this.orderId,
  });

  /// Toss error code (e.g. `PAY_PROCESS_CANCELED`).
  final String code;

  /// Raw Toss message (mapped to a Korean user message by the service).
  final String message;

  /// Order id when Toss provided one.
  final String? orderId;

  /// Whether this failure is a user-initiated cancellation.
  bool get isCanceled => code == 'PAY_PROCESS_CANCELED';
}

/// Asynchronous easy-pay style pending state (e.g. international). Treated as a
/// non-terminal failure by the service for the v1 PG scope (no pending UI yet).
@immutable
final class PaymentBackendPending extends PaymentBackendResult {
  /// Creates a [PaymentBackendPending].
  const PaymentBackendPending({
    required this.paymentKey,
    required this.orderId,
    required this.amount,
  });

  /// Toss payment key for the pending payment.
  final String paymentKey;

  /// Order id of the pending payment.
  final String orderId;

  /// Toss-reported amount (informational only).
  final num amount;
}

/// Port over the subset of the Toss `PaymentWidget` the orchestration uses.
///
/// Production: `TossPaymentBackend` (wraps `PaymentWidget`).
/// Tests: a fake returning canned [PaymentBackendResult]s and recording the
/// [PaymentRequest] it was asked to pay (so the §8-A amount-trust assertion can
/// inspect what crossed the boundary).
abstract class PaymentBackend {
  /// Renders the payment-method UI for [amount]. Must be called before
  /// [requestPayment]. The widget host guarantees the method/agreement widgets
  /// are mounted before this runs.
  Future<void> renderPaymentMethods({required PaymentAmount amount});

  /// Opens the Toss payment window for [request] and resolves with the
  /// normalized outcome. The client passes only identifiers — never an amount
  /// it expects the server to trust.
  Future<PaymentBackendResult> requestPayment({
    required PaymentRequest request,
  });
}
