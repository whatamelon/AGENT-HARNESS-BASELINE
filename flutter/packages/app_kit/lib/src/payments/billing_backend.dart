/// SDK-neutral billing-key (정기결제/자동납부) port — the recurring-payment
/// sibling of `payment_backend.dart`.
///
/// A one-shot PG payment (`payment_backend.dart`) authorizes a single amount
/// now. **Billing** is a different state machine: the client obtains a Toss
/// `authKey` for a payment method, the SERVER exchanges it for a long-lived
/// `billingKey`, and subsequent charges are server-initiated against that key
/// (no further user interaction). Issuance and revocation therefore need their
/// own seam — they do not fit the single-confirm shape.
///
/// Nothing in this file imports a Toss type. Production wires it to
/// `tosspayments_widget_sdk_flutter` (see `billing_wiring.dart`, excluded from
/// unit tests); tests supply a hand-written fake (no `mockito`/`mocktail`).
///
/// §8-A AMOUNT TRUST BOUNDARY — the client NEVER originates or transmits a
/// charge amount. The client only obtains the `authKey` (a method-binding
/// token) and hands it + the `customerKey` to the server, which issues the
/// `billingKey` and decides every future charge amount. Recurring charges are a
/// server concern; this port has no "charge now with amount X" method.
///
/// STORE POLICY (§8-E) — same rail as `payment_backend.dart`: 실물·서비스
/// (용인공원 계약 / 온유 상조) settle off-IAP via the external PG. Digital content
/// must NOT use this rail.
library;

// `BillingBackend` is a single-method DI seam (faked in unit tests, wired to
// Toss in production); intentionally not folded into a top-level function.
// ignore_for_file: one_member_abstracts

import 'package:meta/meta.dart';

/// Identifying inputs to start a billing-key authorization.
///
/// Deliberately amount-free: registering a billing method binds a payment
/// instrument, it does not charge. The server later charges against the issued
/// key with a server-decided amount (§8-A).
@immutable
class BillingAuthRequest {
  /// Creates a [BillingAuthRequest].
  const BillingAuthRequest({
    required this.customerKey,
    this.customerName,
    this.customerEmail,
  });

  /// Stable, sufficiently-random per-customer id the billing key is bound to.
  final String customerKey;

  /// Optional customer display name (no PII is logged).
  final String? customerName;

  /// Optional customer email (no PII is logged).
  final String? customerEmail;
}

/// Outcome of a `requestBillingAuth` call, normalized away from the SDK's
/// `Result(success?, fail?)` shape into a sealed hierarchy so the service layer
/// can pattern-match exhaustively. Mirrors `PaymentBackendResult` in
/// `payment_backend.dart`.
@immutable
sealed class BillingAuthResult {
  const BillingAuthResult();
}

/// Toss returned an `authKey` for the selected payment method.
///
/// The [authKey] is exchanged for a `billingKey` SERVER-SIDE — it is NOT a
/// charge token and carries no amount. [customerKey] echoes the request so the
/// server can bind the issued key.
@immutable
final class BillingAuthSuccess extends BillingAuthResult {
  /// Creates a [BillingAuthSuccess].
  const BillingAuthSuccess({
    required this.authKey,
    required this.customerKey,
  });

  /// Toss auth key — exchanged for a billing key server-side; never a charge.
  final String authKey;

  /// Customer key the method is bound to (echoed for server-side binding).
  final String customerKey;
}

/// Toss reported a failure or the user cancelled the method-registration window
/// (surfaced as a `Fail` with code `PAY_PROCESS_CANCELED`).
@immutable
final class BillingAuthFailure extends BillingAuthResult {
  /// Creates a [BillingAuthFailure].
  const BillingAuthFailure({
    required this.code,
    required this.message,
  });

  /// Toss error code (e.g. `PAY_PROCESS_CANCELED`).
  final String code;

  /// Raw Toss message (mapped to a Korean user message by the service).
  final String message;

  /// Whether this failure is a user-initiated cancellation.
  bool get isCanceled => code == 'PAY_PROCESS_CANCELED';
}

/// Port over the subset of the Toss billing widget the orchestration uses.
///
/// Production: `TossBillingBackend` (wraps the Toss billing `PaymentWidget`
/// `requestBillingAuth`). Tests: a fake returning canned [BillingAuthResult]s.
abstract class BillingBackend {
  /// Opens the Toss billing-method registration window for [request] and
  /// resolves with the normalized outcome. The client receives only an
  /// `authKey` — never a charge amount it expects the server to trust.
  Future<BillingAuthResult> requestBillingAuth({
    required BillingAuthRequest request,
  });
}
