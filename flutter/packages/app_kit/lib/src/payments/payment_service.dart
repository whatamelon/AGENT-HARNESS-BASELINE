/// Payment orchestration — the SDK-free, fully-testable core of Lane A.
///
/// Flow (§8-A amount-비신뢰 enforced at every step):
///   1. POST `payment-create-order` (Bearer JWT) ->
///      `{orderId, amount, orderName}`. **The server decides the amount**; the
///      client only displays it.
///   2. Render the Toss payment-method widget for the server amount and open
///      the payment window via the [PaymentBackend] port.
///   3. On Toss success, POST `payment-confirm` with **`{orderId, paymentKey}`
///      only** — the Toss-reported `amount` is deliberately dropped so the
///      server confirms against its own DB amount (single source of truth).
///   4. Normalize the confirm response (200 / 409 / 400) into a [core.Result]
///      with Korean user messages.
///
/// This file imports `core` (ApiClient/Result/logger) and the SDK-neutral
/// [PaymentBackend] port — never a Toss type — so it runs under unit tests with
/// a fake backend and a fake-adapter `ApiClient`.
library;

import 'package:app_kit/src/payments/payment_backend.dart';
import 'package:core/core.dart' as core;

/// Path of the create-order Edge Function (joined onto the ApiClient base URL).
const String kPaymentCreateOrderPath = '/functions/v1/payment-create-order';

/// Path of the confirm Edge Function.
const String kPaymentConfirmPath = '/functions/v1/payment-confirm';

/// A server-issued order: the only trusted source of the payable amount.
class PaymentOrder {
  /// Creates a [PaymentOrder].
  const PaymentOrder({
    required this.orderId,
    required this.amount,
    required this.orderName,
  });

  /// Server order id (SoT key for confirmation).
  final String orderId;

  /// Server-computed amount — for display only; never echoed back on confirm.
  final num amount;

  /// Server-provided order name shown in the Toss window.
  final String orderName;
}

/// Terminal payment failures, normalized to Korean user messages.
enum PaymentError {
  /// User cancelled or closed the Toss window.
  canceled,

  /// Toss reported a payment failure (declined card, etc.).
  paymentFailed,

  /// Server said the order is already confirmed (409 idempotent replay).
  alreadyConfirmed,

  /// Server detected an amount mismatch (409) — client amount tampering or
  /// stale order. The client never sends an amount, so this signals a
  /// server-side/SoT inconsistency to surface, not a client retry.
  amountMismatch,

  /// Order was not in a confirmable (pending) state (409).
  orderNotPending,

  /// Authentication/authorization failure (401/403).
  unauthorized,

  /// Network/timeout/server (5xx) or any other transport failure.
  network,

  /// Bad request (400) or a malformed/empty server response.
  invalid,
}

/// Maps a [PaymentError] to a Korean, user-facing message.
String paymentErrorMessage(PaymentError error) => switch (error) {
      PaymentError.canceled => '결제를 취소했습니다.',
      PaymentError.paymentFailed => '결제에 실패했습니다. 다시 시도해 주세요.',
      PaymentError.alreadyConfirmed => '이미 결제가 완료된 주문입니다.',
      PaymentError.amountMismatch => '결제 금액이 일치하지 않습니다. 다시 시도해 주세요.',
      PaymentError.orderNotPending => '결제할 수 없는 주문 상태입니다.',
      PaymentError.unauthorized => '로그인이 필요하거나 권한이 없습니다.',
      PaymentError.network => '네트워크 연결을 확인해 주세요.',
      PaymentError.invalid => '결제 요청이 올바르지 않습니다.',
    };

/// Successful confirmation outcome returned to the caller.
class PaymentConfirmation {
  /// Creates a [PaymentConfirmation].
  const PaymentConfirmation({required this.orderId});

  /// The confirmed order id.
  final String orderId;
}

/// Renders the payment widget and opens the Toss window. Implemented by the UI
/// host (`payment_widget_host.dart`) which owns the mounted widgets; the
/// service drives it without knowing about Flutter.
typedef RenderAndRequest = Future<PaymentBackendResult> Function(
  PaymentOrder order,
  PaymentRequest request,
);

/// Orchestrates a single PG payment end-to-end.
///
/// Pure of Flutter and Toss types: it talks to the server via [core.ApiClient]
/// and to the payment UI via the injected [RenderAndRequest] callback (which
/// the host backs with a [PaymentBackend]).
class PaymentService {
  /// Creates a [PaymentService].
  PaymentService({
    required core.ApiClient apiClient,
    core.AppLogger logger = const core.AppLogger(name: 'payments'),
  })  : _api = apiClient,
        _logger = logger;

  final core.ApiClient _api;
  final core.AppLogger _logger;

  /// Step 1 — asks the server to create an order. The request [body] is the
  /// domain input (e.g. `{productId, quantity}` or `{items}`); the server
  /// computes and returns the authoritative amount.
  Future<core.Result<PaymentOrder, PaymentError>> createOrder(
    Map<String, Object?> body,
  ) async {
    final result = await _api.post<Map<String, dynamic>>(
      kPaymentCreateOrderPath,
      body: body,
    );
    return result.fold(
      _parseOrder,
      (failure) => core.Err(_mapException(failure)),
    );
  }

  core.Result<PaymentOrder, PaymentError> _parseOrder(
    Map<String, dynamic> body,
  ) {
    final orderId = body['orderId'];
    final amount = body['amount'];
    final orderName = body['orderName'];
    if (orderId is! String ||
        orderId.isEmpty ||
        amount is! num ||
        orderName is! String ||
        orderName.isEmpty) {
      _logger.warn('create-order: malformed response');
      return const core.Err(PaymentError.invalid);
    }
    return core.Ok(
      PaymentOrder(orderId: orderId, amount: amount, orderName: orderName),
    );
  }

  /// Step 3 — confirms a Toss-authorized payment with the server.
  ///
  /// **Sends `{orderId, paymentKey}` only.** The Toss-reported amount is never
  /// included; the server confirms against its own stored amount (§8-A). The
  /// `paymentKey`/`orderId` are masked in logs (PII/secret redaction).
  Future<core.Result<PaymentConfirmation, PaymentError>> confirm({
    required String orderId,
    required String paymentKey,
  }) async {
    _logger.info(
      'confirm order=${_mask(orderId)} paymentKey=${_mask(paymentKey)}',
    );
    final result = await _api.post<Map<String, dynamic>>(
      kPaymentConfirmPath,
      // NOTE: amount intentionally absent — server is the amount SoT.
      body: <String, Object?>{'orderId': orderId, 'paymentKey': paymentKey},
    );
    return result.fold(
      (body) => _parseConfirm(orderId, body),
      (failure) => core.Err(_mapConfirmException(failure)),
    );
  }

  core.Result<PaymentConfirmation, PaymentError> _parseConfirm(
    String orderId,
    Map<String, dynamic> body,
  ) {
    final status = body['status'];
    if (status == 'confirmed') {
      final confirmedId = body['orderId'];
      return core.Ok(
        PaymentConfirmation(
          orderId: confirmedId is String && confirmedId.isNotEmpty
              ? confirmedId
              : orderId,
        ),
      );
    }
    // A 200 carrying a non-confirmed status is treated as the matching error.
    return core.Err(_mapConfirmStatus(status));
  }

  /// End-to-end orchestration: create order -> render+request via [render] ->
  /// confirm. Returns the confirmation or the first terminal error.
  Future<core.Result<PaymentConfirmation, PaymentError>> pay({
    required Map<String, Object?> orderInput,
    required PaymentRequest Function(PaymentOrder order) buildRequest,
    required RenderAndRequest render,
  }) async {
    final orderResult = await createOrder(orderInput);
    return switch (orderResult) {
      core.Err(:final failure) => core.Err(failure),
      core.Ok(:final value) => await _renderAndConfirm(
          value,
          buildRequest(value),
          render,
        ),
    };
  }

  Future<core.Result<PaymentConfirmation, PaymentError>> _renderAndConfirm(
    PaymentOrder order,
    PaymentRequest request,
    RenderAndRequest render,
  ) async {
    final outcome = await render(order, request);
    switch (outcome) {
      case PaymentBackendSuccess(:final paymentKey, :final orderId):
        // §8-A: only orderId + paymentKey cross to the server. The Toss
        // `amount` on `outcome` is deliberately ignored here.
        return confirm(orderId: orderId, paymentKey: paymentKey);
      case PaymentBackendFailure(:final isCanceled):
        return core.Err(
          isCanceled ? PaymentError.canceled : PaymentError.paymentFailed,
        );
      case PaymentBackendPending():
        // No pending UI in the v1 PG scope; surface as a recoverable failure.
        return const core.Err(PaymentError.paymentFailed);
    }
  }

  PaymentError _mapConfirmStatus(Object? status) => switch (status) {
        'already_confirmed' => PaymentError.alreadyConfirmed,
        'amount_mismatch' => PaymentError.amountMismatch,
        'order_not_pending' => PaymentError.orderNotPending,
        _ => PaymentError.invalid,
      };

  PaymentError _mapException(core.AppException e) => switch (e) {
        core.UnauthorizedException() => PaymentError.unauthorized,
        core.ConflictException() => _mapConfirmStatus(e.status),
        core.NetworkException() ||
        core.TimeoutException() ||
        core.ServerException() =>
          PaymentError.network,
        core.UnknownException() => PaymentError.invalid,
      };

  /// Confirm shares the generic mapping: a 409 is normalized by `ApiClient`
  /// into a [core.ConflictException] carrying the server's `status` token
  /// (`already_confirmed` | `amount_mismatch` | `order_not_pending`), which
  /// [_mapException] routes through [_mapConfirmStatus]. A 400 / malformed body
  /// becomes [PaymentError.invalid]; 401/403 -> unauthorized; 5xx/timeout/
  /// network -> network.
  PaymentError _mapConfirmException(core.AppException e) => _mapException(e);

  /// Masks all but the last 4 chars of a sensitive identifier for logging.
  static String _mask(String value) {
    if (value.length <= 4) return '****';
    return '****${value.substring(value.length - 4)}';
  }
}
