import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod Notifier for the orders feature (presentation-only slice).
///
/// Holds a simple counter as placeholder view state; replace with the real
/// feature state and wire a repository (regenerate with `--with_domain true`
/// to scaffold the data/domain layers).
class OrdersController extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state = state + 1;
}

/// Provider for the orders controller.
final NotifierProvider<OrdersController, int>
    ordersControllerProvider =
    NotifierProvider<OrdersController, int>(
  OrdersController.new,
);
