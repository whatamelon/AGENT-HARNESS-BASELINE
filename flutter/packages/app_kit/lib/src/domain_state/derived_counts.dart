/// Factories deriving reactive scalar values from a `CollectionSnapshot`
/// source provider (e.g. a badge count over a cart/wishlist).
///
/// Generic and app-agnostic: the source is an `AsyncNotifierProvider` whose
/// value is a `CollectionSnapshot` (typically a `KeyedCollectionController`).
/// The derived providers update reactively when the source snapshot changes
/// and return the supplied fallback while the source is loading or in error.
library;

import 'package:app_kit/src/domain_state/reactive_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Creates a [Provider] yielding the item count of [source].
///
/// Returns [whenAbsent] (default `0`) while the source is loading or errored.
Provider<int>
    collectionCountProvider<N extends AsyncNotifier<CollectionSnapshot<T>>, T>(
  AsyncNotifierProvider<N, CollectionSnapshot<T>> source, {
  int whenAbsent = 0,
}) {
  return Provider<int>((ref) {
    final snapshot = ref.watch(source);
    return snapshot.maybeWhen(
      data: (data) => data.length,
      orElse: () => whenAbsent,
    );
  });
}

/// Creates a [Provider] yielding the count of DISTINCT items in [source].
///
/// Distinctness is determined by [keyOf]. Returns [whenAbsent] (default `0`)
/// while the source is loading or errored.
Provider<int> collectionDistinctCountProvider<
    N extends AsyncNotifier<CollectionSnapshot<T>>, T>(
  AsyncNotifierProvider<N, CollectionSnapshot<T>> source, {
  required String Function(T item) keyOf,
  int whenAbsent = 0,
}) {
  return Provider<int>((ref) {
    final snapshot = ref.watch(source);
    return snapshot.maybeWhen(
      data: (data) => data.items.map(keyOf).toSet().length,
      orElse: () => whenAbsent,
    );
  });
}

/// Creates a [Provider] that reduces [source]'s items into a single value [R].
///
/// Folds [reducer] over the items starting from [initial]. Returns [whenAbsent]
/// while the source is loading or errored. Useful for derived sums of NON-money
/// quantities (e.g. total item count). Authoritative monetary totals must be
/// computed server-side, not here.
Provider<R> collectionReduceProvider<
    N extends AsyncNotifier<CollectionSnapshot<T>>, T, R>(
  AsyncNotifierProvider<N, CollectionSnapshot<T>> source, {
  required R initial,
  required R Function(R acc, T item) reducer,
  required R whenAbsent,
}) {
  return Provider<R>((ref) {
    final snapshot = ref.watch(source);
    return snapshot.maybeWhen(
      data: (data) => data.items.fold<R>(initial, reducer),
      orElse: () => whenAbsent,
    );
  });
}
