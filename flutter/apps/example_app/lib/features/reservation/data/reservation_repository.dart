import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:example_app/features/reservation/domain/reservation.dart';

/// Repository for the reservation feature. Returns a `Result` so the
/// controller handles failure without throwing.
///
/// The skeleton ships an in-memory stub so the slice compiles and runs offline;
/// `fetchAll` returns an empty list (drives the empty state). Subclass and
/// override `fetchAll` with a real `ApiClient` / Supabase query, then swap the
/// implementation in via `reservationRepositoryProvider`.
class ReservationRepository {
  const ReservationRepository();

  Future<Result<List<Reservation>, AppException>>
      fetchAll() async {
    return const Result.ok(<Reservation>[]);
  }
}

/// Provider for the reservation repository. Override in tests / when the
/// real data source is wired.
final Provider<ReservationRepository>
    reservationRepositoryProvider =
    Provider<ReservationRepository>(
  (ref) => const ReservationRepository(),
);
