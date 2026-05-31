/// Riverpod state for the payment flow: idle -> creating -> rendering ->
/// processing -> confirmed | failed.
///
/// Holds no Toss/Flutter-render concerns — it only tracks the phase and the
/// terminal outcome so the host UI can drive the button/loading/error states.
/// The host wires it to [PaymentService] + a [PaymentBackend]; this notifier
/// stays SDK-free and unit-testable.
library;

import 'package:app_kit/src/payments/payment_backend.dart';
import 'package:app_kit/src/payments/payment_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Lifecycle phase of a single payment attempt.
enum PaymentPhase {
  /// No payment in progress.
  idle,

  /// Calling `payment-create-order`.
  creating,

  /// Toss method widget mounted; awaiting user action in the widget.
  rendering,

  /// Toss window returned success; calling `payment-confirm`.
  processing,

  /// Server confirmed the payment.
  confirmed,

  /// Terminal failure (see [PaymentState.error]).
  failed,
}

/// Immutable payment UI state.
@immutable
class PaymentState {
  /// Creates a [PaymentState].
  const PaymentState({
    this.phase = PaymentPhase.idle,
    this.error,
    this.orderId,
  });

  /// Current lifecycle phase.
  final PaymentPhase phase;

  /// Terminal error when [phase] is [PaymentPhase.failed], else `null`.
  final PaymentError? error;

  /// Confirmed order id when [phase] is [PaymentPhase.confirmed].
  final String? orderId;

  /// Whether a CTA should show a spinner / be disabled.
  bool get isBusy =>
      phase == PaymentPhase.creating ||
      phase == PaymentPhase.processing;

  /// Korean user message for the current error, or `null`.
  String? get errorMessage =>
      error == null ? null : paymentErrorMessage(error!);

  /// Returns a copy with the given overrides. [clearError]/[clearOrderId] force
  /// the field to `null` (since `null` can't be passed positionally).
  PaymentState copyWith({
    PaymentPhase? phase,
    PaymentError? error,
    String? orderId,
    bool clearError = false,
    bool clearOrderId = false,
  }) {
    return PaymentState(
      phase: phase ?? this.phase,
      error: clearError ? null : (error ?? this.error),
      orderId: clearOrderId ? null : (orderId ?? this.orderId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PaymentState &&
      other.phase == phase &&
      other.error == error &&
      other.orderId == orderId;

  @override
  int get hashCode => Object.hash(phase, error, orderId);
}

/// Drives a payment attempt and publishes [PaymentState] transitions.
///
/// The host supplies the [PaymentService] and the `render` callback (which
/// renders the Toss widget + opens the window). The notifier owns only the
/// phase transitions, keeping the host thin.
class PaymentController extends Notifier<PaymentState> {
  /// Creates a [PaymentController] bound to a [PaymentService].
  PaymentController(this._service);

  final PaymentService _service;

  @override
  PaymentState build() => const PaymentState();

  /// Runs the full create -> render -> confirm flow, transitioning state at
  /// each phase. Safe to call once per attempt; re-entrancy is guarded by the
  /// busy/rendering phases.
  ///
  /// [render] is supplied by the host: it renders the (already-mounted) Toss
  /// method widget for the server amount and opens the payment window, then
  /// returns the normalized [PaymentBackendResult].
  Future<void> start({
    required Map<String, Object?> orderInput,
    required PaymentRequest Function(PaymentOrder order) buildRequest,
    required RenderAndRequest render,
  }) async {
    if (state.isBusy || state.phase == PaymentPhase.rendering) return;
    state = const PaymentState(phase: PaymentPhase.creating);

    Future<PaymentBackendResult> wrappedRender(
      PaymentOrder order,
      PaymentRequest request,
    ) async {
      state = state.copyWith(
        phase: PaymentPhase.rendering,
        orderId: order.orderId,
      );
      final outcome = await render(order, request);
      // Entering confirm: the service performs the network call; reflect it.
      state = state.copyWith(phase: PaymentPhase.processing);
      return outcome;
    }

    final result = await _service.pay(
      orderInput: orderInput,
      buildRequest: buildRequest,
      render: wrappedRender,
    );

    state = result.fold(
      (confirmation) => PaymentState(
        phase: PaymentPhase.confirmed,
        orderId: confirmation.orderId,
      ),
      (error) => PaymentState(phase: PaymentPhase.failed, error: error),
    );
  }

  /// Resets to idle (e.g. when the user retries after a failure).
  void reset() => state = const PaymentState();
}

/// Builds a [PaymentController] provider bound to a [PaymentService].
///
/// Apps create one provider with their configured service (base URL + token
/// provider) and read it from the payment host.
NotifierProvider<PaymentController, PaymentState> paymentControllerProvider(
  PaymentService service,
) {
  return NotifierProvider<PaymentController, PaymentState>(
    () => PaymentController(service),
  );
}
