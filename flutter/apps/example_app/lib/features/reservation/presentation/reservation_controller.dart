import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:example_app/features/reservation/data/reservation_repository.dart';
import 'package:example_app/features/reservation/domain/reservation.dart';

/// View state for the reservation feature.
@immutable
class ReservationState {
  const ReservationState({
    this.items = const <Reservation>[],
    this.isLoading = false,
    this.error,
  });

  final List<Reservation> items;
  final bool isLoading;
  final String? error;

  ReservationState copyWith({
    List<Reservation>? items,
    bool? isLoading,
    String? error,
  }) {
    return ReservationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Riverpod Notifier for the reservation feature.
///
/// Loads through the repository (which talks to ApiClient/Supabase). The repo
/// is injected via `reservationRepositoryProvider` so tests can
/// override it with a fake.
class ReservationController
    extends Notifier<ReservationState> {
  @override
  ReservationState build() => const ReservationState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final result = await ref
        .read(reservationRepositoryProvider)
        .fetchAll();
    state = switch (result) {
      Ok(value: final items) =>
        state.copyWith(items: items, isLoading: false),
      Err(failure: final f) =>
        state.copyWith(isLoading: false, error: f.toString()),
    };
  }
}

/// Provider for the reservation controller.
final NotifierProvider<ReservationController,
        ReservationState>
    reservationControllerProvider =
    NotifierProvider<ReservationController,
        ReservationState>(
  ReservationController.new,
);
