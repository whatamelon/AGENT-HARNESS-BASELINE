import 'dart:typed_data';

import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart' as core;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this._byPath);
  final Map<String, ResponseBody Function()> _byPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      (_byPath[options.path] ?? () => ResponseBody.fromString('{}', 404))();

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

PaymentService _service(Map<String, ResponseBody Function()> routes) =>
    PaymentService(
      apiClient: core.ApiClient(
        dio: Dio()..httpClientAdapter = _Adapter(routes),
      ),
    );

PaymentRequest _build(PaymentOrder o) =>
    PaymentRequest(orderId: o.orderId, orderName: o.orderName);

void main() {
  group('PaymentController phases', () {
    test('idle -> confirmed on a successful flow', () async {
      final provider = paymentControllerProvider(
        _service({
          kPaymentCreateOrderPath: () =>
              _json('{"orderId":"o1","amount":1000,"orderName":"n"}', 200),
          kPaymentConfirmPath: () =>
              _json('{"status":"confirmed","orderId":"o1"}', 200),
        }),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(provider).phase, PaymentPhase.idle);

      await container.read(provider.notifier).start(
            orderInput: {'p': 1},
            buildRequest: _build,
            render: (o, r) async => const PaymentBackendSuccess(
              paymentKey: 'k',
              orderId: 'o1',
              amount: 1000,
            ),
          );

      final state = container.read(provider);
      expect(state.phase, PaymentPhase.confirmed);
      expect(state.orderId, 'o1');
      expect(state.errorMessage, isNull);
    });

    test('failed flow exposes a Korean error message', () async {
      final provider = paymentControllerProvider(
        _service({
          kPaymentCreateOrderPath: () =>
              _json('{"orderId":"o2","amount":1000,"orderName":"n"}', 200),
        }),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(provider.notifier).start(
            orderInput: {'p': 1},
            buildRequest: _build,
            render: (o, r) async => const PaymentBackendFailure(
              code: 'PAY_PROCESS_CANCELED',
              message: '취소',
              orderId: 'o2',
            ),
          );

      final state = container.read(provider);
      expect(state.phase, PaymentPhase.failed);
      expect(state.error, PaymentError.canceled);
      expect(state.errorMessage, '결제를 취소했습니다.');
    });

    test('render observes the rendering phase before request', () async {
      final provider = paymentControllerProvider(
        _service({
          kPaymentCreateOrderPath: () =>
              _json('{"orderId":"o3","amount":1000,"orderName":"n"}', 200),
          kPaymentConfirmPath: () =>
              _json('{"status":"confirmed","orderId":"o3"}', 200),
        }),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      PaymentPhase? phaseDuringRender;
      await container.read(provider.notifier).start(
            orderInput: {'p': 1},
            buildRequest: _build,
            render: (o, r) async {
              phaseDuringRender = container.read(provider).phase;
              return const PaymentBackendSuccess(
                paymentKey: 'k',
                orderId: 'o3',
                amount: 1000,
              );
            },
          );

      expect(phaseDuringRender, PaymentPhase.rendering);
      expect(container.read(provider).phase, PaymentPhase.confirmed);
    });

    test('reset returns to idle', () async {
      final provider = paymentControllerProvider(
        _service({kPaymentCreateOrderPath: () => _json('{}', 401)}),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(provider.notifier).start(
            orderInput: {'p': 1},
            buildRequest: _build,
            render: (o, r) async => const PaymentBackendSuccess(
              paymentKey: 'k',
              orderId: 'o',
              amount: 1,
            ),
          );
      expect(container.read(provider).phase, PaymentPhase.failed);

      container.read(provider.notifier).reset();
      expect(container.read(provider).phase, PaymentPhase.idle);
    });
  });
}
