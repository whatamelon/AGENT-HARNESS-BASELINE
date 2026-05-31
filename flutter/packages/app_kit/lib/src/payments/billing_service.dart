/// Billing-key (정기결제/자동납부) orchestration — the SDK-free, fully-testable
/// recurring-payment sibling of `payment_service.dart`.
///
/// Flow (§8-A amount-비신뢰 enforced):
///   1. Open the Toss billing-method window via the [BillingBackend] port to
///      obtain an `authKey` (binds a payment instrument; carries NO amount).
///   2. POST `billing-register` with `{authKey, customerKey}` only — the SERVER
///      exchanges the `authKey` for a long-lived `billingKey` and stores it.
///      The client never sees the secret billing key.
///   3. Later charges are SERVER-initiated against the stored billing key; the
///      client has no "charge with amount X" path (the amount is the server's).
///   4. `cancel` revokes a previously registered mandate by its server-issued
///      `billingId` (NOT the raw billing key — the client never holds it).
///
/// This file imports `core` (ApiClient/Result/logger) and the SDK-neutral
/// [BillingBackend] port — never a Toss type — so it runs under unit tests with
/// a fake backend and a fake-adapter `ApiClient`.
///
/// The Edge Functions named below are the CLIENT-SIDE CONTRACT only; the server
/// implementations live in Lane B and may not exist yet — this seam pins the
/// paths so the server and client agree.
library;

import 'package:app_kit/src/payments/billing_backend.dart';
import 'package:core/core.dart' as core;

/// Path of the register-billing-key Edge Function (joined onto the base URL).
/// The server exchanges the client `authKey` for a stored `billingKey`.
const String kBillingRegisterPath = '/functions/v1/billing-register';

/// Path of the cancel-billing-key (mandate revocation) Edge Function.
const String kBillingCancelPath = '/functions/v1/billing-cancel';

/// Terminal billing failures, normalized to Korean user messages.
enum BillingError {
  /// User cancelled or closed the Toss billing-method window.
  canceled,

  /// Toss reported a method-registration failure.
  authFailed,

  /// Server said the mandate is already registered/cancelled (409 idempotent).
  alreadyExists,

  /// The referenced mandate was not found (404/409 on cancel).
  notFound,

  /// Authentication/authorization failure (401/403).
  unauthorized,

  /// Network/timeout/server (5xx) or any other transport failure.
  network,

  /// Bad request (400) or a malformed/empty server response.
  invalid,
}

/// Maps a [BillingError] to a Korean, user-facing message.
String billingErrorMessage(BillingError error) => switch (error) {
      BillingError.canceled => '정기결제 등록을 취소했습니다.',
      BillingError.authFailed => '결제수단 등록에 실패했습니다. 다시 시도해 주세요.',
      BillingError.alreadyExists => '이미 등록된 자동납부 수단입니다.',
      BillingError.notFound => '해지할 자동납부 정보를 찾을 수 없습니다.',
      BillingError.unauthorized => '로그인이 필요하거나 권한이 없습니다.',
      BillingError.network => '네트워크 연결을 확인해 주세요.',
      BillingError.invalid => '요청이 올바르지 않습니다.',
    };

/// A server-registered billing mandate. The client holds only the opaque,
/// server-issued [billingId] — never the secret billing key.
class BillingMandate {
  /// Creates a [BillingMandate].
  const BillingMandate({required this.billingId});

  /// Server-issued mandate id (the SoT key for charges/cancellation).
  final String billingId;
}

/// Opens the Toss billing-method window. Implemented by the UI host which owns
/// the mounted widget; the service drives it without knowing about Flutter.
typedef RequestBillingAuth = Future<BillingAuthResult> Function(
  BillingAuthRequest request,
);

/// Orchestrates billing-key registration and revocation end-to-end.
///
/// Pure of Flutter and Toss types: it talks to the server via [core.ApiClient]
/// and to the billing UI via the injected [RequestBillingAuth] callback (which
/// the host backs with a [BillingBackend]).
class BillingService {
  /// Creates a [BillingService].
  BillingService({
    required core.ApiClient apiClient,
    core.AppLogger logger = const core.AppLogger(name: 'billing'),
  })  : _api = apiClient,
        _logger = logger;

  final core.ApiClient _api;
  final core.AppLogger _logger;

  /// Registers a recurring-payment mandate.
  ///
  /// Opens the billing-method window via [request], then POSTs **only**
  /// `{authKey, customerKey}` to the server (§8-A: no amount). The server
  /// exchanges the `authKey` for a `billingKey` and returns a [BillingMandate].
  Future<core.Result<BillingMandate, BillingError>> register({
    required BillingAuthRequest authRequest,
    required RequestBillingAuth request,
  }) async {
    final outcome = await request(authRequest);
    switch (outcome) {
      case BillingAuthSuccess(:final authKey, :final customerKey):
        return _register(authKey: authKey, customerKey: customerKey);
      case BillingAuthFailure(:final isCanceled):
        return core.Err(
          isCanceled ? BillingError.canceled : BillingError.authFailed,
        );
    }
  }

  Future<core.Result<BillingMandate, BillingError>> _register({
    required String authKey,
    required String customerKey,
  }) async {
    _logger.info(
      'register billing customer=${_mask(customerKey)} '
      'authKey=${_mask(authKey)}',
    );
    final result = await _api.post<Map<String, dynamic>>(
      kBillingRegisterPath,
      // NOTE: amount intentionally absent — server owns every future charge.
      body: <String, Object?>{'authKey': authKey, 'customerKey': customerKey},
    );
    return result.fold(
      _parseMandate,
      (failure) => core.Err(_mapException(failure)),
    );
  }

  core.Result<BillingMandate, BillingError> _parseMandate(
    Map<String, dynamic> body,
  ) {
    final billingId = body['billingId'];
    if (billingId is! String || billingId.isEmpty) {
      _logger.warn('billing-register: malformed response');
      return const core.Err(BillingError.invalid);
    }
    return core.Ok(BillingMandate(billingId: billingId));
  }

  /// Revokes a previously registered mandate by its server-issued [billingId].
  ///
  /// Sends only the opaque mandate id; the server resolves and deletes the
  /// stored billing key. Mirrors `payment_service.confirm` shape.
  Future<core.Result<void, BillingError>> cancel({
    required String billingId,
  }) async {
    _logger.info('cancel billing mandate=${_mask(billingId)}');
    final result = await _api.post<Map<String, dynamic>>(
      kBillingCancelPath,
      body: <String, Object?>{'billingId': billingId},
    );
    return result.fold(
      _parseCancel,
      (failure) => core.Err(_mapException(failure)),
    );
  }

  core.Result<void, BillingError> _parseCancel(Map<String, dynamic> body) {
    final status = body['status'];
    if (status == 'canceled' || status == 'already_canceled') {
      return const core.Ok(null);
    }
    return core.Err(_mapBillingStatus(status));
  }

  BillingError _mapBillingStatus(Object? status) => switch (status) {
        'already_exists' => BillingError.alreadyExists,
        'already_canceled' => BillingError.alreadyExists,
        'not_found' => BillingError.notFound,
        _ => BillingError.invalid,
      };

  BillingError _mapException(core.AppException e) => switch (e) {
        core.UnauthorizedException() => BillingError.unauthorized,
        core.ConflictException() => _mapBillingStatus(e.status),
        core.NetworkException() ||
        core.TimeoutException() ||
        core.ServerException() =>
          BillingError.network,
        core.UnknownException() => BillingError.invalid,
      };

  /// Masks all but the last 4 chars of a sensitive identifier for logging.
  static String _mask(String value) {
    if (value.length <= 4) return '****';
    return '****${value.substring(value.length - 4)}';
  }
}
