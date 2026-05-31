/// Full-screen Toss payment-widget host.
///
/// Renders the Toss `PaymentMethodWidget` + `AgreementWidget` (the only URLs
/// the embedded webview ever loads are Toss-issued HTML), a `DsAppBar` with a
/// back affordance, and a `DsButton` "결제하기" CTA.
///
/// Routing (§ P2 fullscreen policy): the app registers this screen on the ROOT
/// navigator (`parentNavigatorKey: rootKey`) with a chrome policy of
/// `showBottomNav: false`, so the shell bottom nav is not in the tree — a clean
/// full-screen payment surface.
///
/// This widget is the seam between the SDK-free orchestration ([PaymentService]
/// / [PaymentController]) and the live Toss widget: it owns the
/// [TossPaymentBackend] and feeds the controller a `render` callback. It is the
/// only app_kit widget that touches the Toss widget classes; like the other
/// wirings it is not exercised by unit tests (the logic is tested via the
/// service/controller fakes).
library;

// SDK-touching host; the testable logic lives in payment_service/controller.

import 'package:app_kit/src/payments/payment_backend.dart';
import 'package:app_kit/src/payments/payment_controller.dart';
import 'package:app_kit/src/payments/payment_service.dart';
import 'package:app_kit/src/payments/payment_wiring.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tosspayments_widget_sdk_flutter/payment_widget.dart';
import 'package:tosspayments_widget_sdk_flutter/widgets/agreement.dart';
import 'package:tosspayments_widget_sdk_flutter/widgets/payment_method.dart';

/// Selector ids for the in-tree Toss widgets (must be stable & unique).
const String _kMethodSelector = 'payment-methods';
const String _kAgreementSelector = 'agreement';

/// A full-screen payment screen.
///
/// Provide the [controllerProvider] (built via [paymentControllerProvider] from
/// the app's [PaymentService]), the **app-injected** Toss [clientKey], the
/// [customerKey], the domain [orderInput] for create-order, and a builder that
/// turns the server order into the Toss [PaymentRequest]. [onConfirmed] fires
/// after the server confirms; [appScheme] enables external-app return.
class PaymentWidgetHost extends ConsumerStatefulWidget {
  /// Creates a [PaymentWidgetHost].
  const PaymentWidgetHost({
    required this.controllerProvider,
    required this.clientKey,
    required this.customerKey,
    required this.orderInput,
    required this.buildRequest,
    this.title = '결제',
    this.appScheme,
    this.onConfirmed,
    super.key,
  });

  /// The app's payment controller provider.
  final NotifierProvider<PaymentController, PaymentState> controllerProvider;

  /// App-injected Toss **client (publishable) key** — never a secret key.
  final String clientKey;

  /// Stable, sufficiently-random per-customer id (or the anonymous sentinel
  /// [PaymentWidget.anonymous]).
  final String customerKey;

  /// Domain input forwarded to `payment-create-order`.
  final Map<String, Object?> orderInput;

  /// Builds the Toss request from the server order (amount comes from server).
  final PaymentRequest Function(PaymentOrder order) buildRequest;

  /// App bar title.
  final String title;

  /// App custom scheme for external bank/card-app return (e.g. `yipark://`).
  final String? appScheme;

  /// Invoked with the confirmed order id once the server confirms.
  final void Function(String orderId)? onConfirmed;

  @override
  ConsumerState<PaymentWidgetHost> createState() => _PaymentWidgetHostState();
}

class _PaymentWidgetHostState extends ConsumerState<PaymentWidgetHost> {
  late final PaymentWidget _paymentWidget;
  late final TossPaymentBackend _backend;
  PaymentOrder? _renderedOrder;

  @override
  void initState() {
    super.initState();
    _paymentWidget = PaymentWidget(
      clientKey: widget.clientKey,
      customerKey: widget.customerKey,
    );
    _backend = TossPaymentBackend(
      paymentWidget: _paymentWidget,
      methodSelector: _kMethodSelector,
      appScheme: widget.appScheme,
    );
  }

  Future<PaymentBackendResult> _render(
    PaymentOrder order,
    PaymentRequest request,
  ) async {
    // The server amount drives the Toss widget render; the widget is already in
    // the tree (built in [build]). We render the methods for the server amount,
    // then open the window. The amount shown here is display-only (§8-A).
    if (_renderedOrder?.orderId != order.orderId) {
      await _backend.renderPaymentMethods(
        amount: PaymentAmount(value: order.amount),
      );
      _renderedOrder = order;
    }
    return _backend.requestPayment(request: request);
  }

  Future<void> _onPay() async {
    final controller = ref.read(widget.controllerProvider.notifier);
    await controller.start(
      orderInput: widget.orderInput,
      buildRequest: widget.buildRequest,
      render: _render,
    );
    final state = ref.read(widget.controllerProvider);
    if (!mounted) return;
    if (state.phase == PaymentPhase.confirmed && state.orderId != null) {
      widget.onConfirmed?.call(state.orderId!);
    } else if (state.phase == PaymentPhase.failed) {
      showDsSnackbar(
        context: context,
        message: state.errorMessage ?? '결제에 실패했습니다.',
        tone: DsSnackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.controllerProvider);
    final c = context.c;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          DsAppBar(
            title: widget.title,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Toss method + agreement widgets. The embedded webview only
                  // loads Toss-issued HTML — no app-supplied URLs (§8-A).
                  PaymentMethodWidget(
                    paymentWidget: _paymentWidget,
                    selector: _kMethodSelector,
                  ),
                  AgreementWidget(
                    paymentWidget: _paymentWidget,
                    selector: _kAgreementSelector,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: DsButton(
                label: '결제하기',
                loading: state.isBusy,
                onPressed: state.isBusy ? null : _onPay,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
