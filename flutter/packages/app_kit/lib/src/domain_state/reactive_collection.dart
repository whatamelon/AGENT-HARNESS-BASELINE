/// Generic, app-agnostic substrate for keyed reactive collections (cart,
/// wishlist, etc). The harness ships the MECHANISM only; concrete domain
/// types (products, cart lines) are supplied later by apps via
/// `ProviderScope` overrides. No cart/product/auth types appear here.
///
/// Mirrors `payment_controller.dart` (Notifier + injected service +
/// `result.fold`)
/// and builds on core's `Result` / `AppException`.
library;

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// An immutable snapshot of a keyed collection.
///
/// Generic: [T] is the app's domain item type. [revision] increments on every
/// committed change so derived listeners (badge counts) react and so snapshots
/// compare unequal when semantically newer even if [items] is structurally
/// identical.
///
/// Money-safety: a [CollectionSnapshot] is a DISPLAY-ONLY projection. It must
/// never be treated as an authoritative source of totals, prices, or checkout
/// amounts — authoritative monetary computation is server-side only (Supabase /
/// BFF). This generic mechanism exposes no money fields and computes no money.
@immutable
class CollectionSnapshot<T> {
  /// Creates a [CollectionSnapshot].
  const CollectionSnapshot({
    this.items = const [],
    this.revision = 0,
  });

  /// The current items. Copy-on-write: never mutated in place.
  final List<T> items;

  /// Monotonic revision, incremented on every committed mutation.
  final int revision;

  /// Number of items in the snapshot.
  int get length => items.length;

  /// Whether the snapshot holds no items.
  bool get isEmpty => items.isEmpty;

  /// Whether the snapshot holds at least one item.
  bool get isNotEmpty => items.isNotEmpty;

  /// Returns a copy with the given overrides.
  CollectionSnapshot<T> copyWith({
    List<T>? items,
    int? revision,
  }) {
    return CollectionSnapshot<T>(
      items: items ?? this.items,
      revision: revision ?? this.revision,
    );
  }

  /// Returns a copy with [items] replaced and [revision] bumped by one.
  CollectionSnapshot<T> withItems(List<T> next) {
    return CollectionSnapshot<T>(items: next, revision: revision + 1);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CollectionSnapshot<T>) return false;
    if (other.runtimeType != runtimeType) return false;
    if (other.revision != revision) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(runtimeType, revision, Object.hashAll(items));
}

/// Stable conflict status returned when a same-key write is already in flight.
///
/// The simple per-key single-flight guard (architecture §13.5) rejects a second
/// concurrent write for the same key rather than coalescing it (the LWW
/// trailing-write coalescer is deferred as over-engineering for the target
/// demographic). The rejection is surfaced as a core [ConflictException] (which
/// cannot be subclassed here as `AppException` is sealed) carrying this
/// status, so
/// callers branch on it without a new error type. Its Korean message is
/// reassuring for the 50-70대 demographic.
const String kConcurrentWriteStatus = 'concurrent_write';

/// Builds the [ConflictException] used to reject an in-flight same-key write.
ConflictException concurrentWriteConflict() =>
    const ConflictException(status: kConcurrentWriteStatus);

/// Abstract base for a keyed, optimistically-mutated reactive collection.
///
/// Mirrors the `PaymentController` shape: an [AsyncNotifier] that delegates
/// to an injected service/repository and folds [Result] values into [state].
/// Subclasses implement [build] to load the initial snapshot.
///
/// Generic and app-agnostic: carries no cart/product types and imports no
/// auth. A concrete app cart MAY later watch core's read-only
/// `authStateProvider`, but the generic mechanism here must not.
///
/// Concurrency (architecture §13.5 — SIMPLE per-key single-flight): while a
/// write for a given item key is in flight, a second concurrent write for the
/// SAME key is rejected with a [ConflictException] whose status is
/// [kConcurrentWriteStatus]. Deliberately not a last-write-wins coalescer.
abstract class KeyedCollectionController<T>
    extends AsyncNotifier<CollectionSnapshot<T>> {
  final Set<String> _inFlight = <String>{};

  /// Item keys currently being written. Exposed for guard inspection/tests.
  @visibleForTesting
  Set<String> get inFlightKeys => Set<String>.unmodifiable(_inFlight);

  /// Whether a write for [key] is currently in flight.
  bool isInFlight(String key) => _inFlight.contains(key);

  /// Applies an optimistic snapshot, runs [commit], then reconciles or rolls
  /// back. The flow:
  ///
  /// 1. Reject if a write for [key] is already in flight (single-flight guard).
  /// 2. Capture the previous [state] for rollback.
  /// 3. Set [state] to an optimistic `AsyncData` of [next] immediately.
  /// 4. Await [commit].
  /// 5. On success, set [state] to [reconcile]'s result (server-confirmed truth
  ///    folded over the previous snapshot).
  /// 6. On failure, restore the captured previous [state] and surface the
  ///    error.
  ///
  /// Uses MANUAL rollback (capture prev, restore on failure) rather than
  /// `AsyncValue.guard` — guard discards the prev value rollback needs.
  ///
  /// [reconcile] receives the snapshot from BEFORE the optimistic apply and
  /// the server-confirmed payload [C], returning the authoritative snapshot.
  Future<Result<CollectionSnapshot<T>, AppException>> applyOptimistic<C>({
    required String key,
    required CollectionSnapshot<T> next,
    required Future<Result<C, AppException>> Function() commit,
    required CollectionSnapshot<T> Function(
      CollectionSnapshot<T> prev,
      C confirmed,
    ) reconcile,
  }) async {
    if (_inFlight.contains(key)) {
      return Result<CollectionSnapshot<T>, AppException>.err(
        concurrentWriteConflict(),
      );
    }
    _inFlight.add(key);

    final previous = state;
    final prevSnapshot = previous.value ?? CollectionSnapshot<T>();

    state = AsyncValue<CollectionSnapshot<T>>.data(next);

    try {
      final result = await commit();
      return result.fold(
        (confirmed) {
          final reconciled = reconcile(prevSnapshot, confirmed);
          state = AsyncValue<CollectionSnapshot<T>>.data(reconciled);
          return Result<CollectionSnapshot<T>, AppException>.ok(reconciled);
        },
        (error) {
          state = previous;
          return Result<CollectionSnapshot<T>, AppException>.err(error);
        },
      );
    } finally {
      _inFlight.remove(key);
    }
  }
}
