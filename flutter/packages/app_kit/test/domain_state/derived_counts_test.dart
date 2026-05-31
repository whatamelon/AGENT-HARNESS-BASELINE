import 'dart:async';

import 'package:app_kit/src/domain_state/derived_counts.dart';
import 'package:app_kit/src/domain_state/reactive_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Item {
  const _Item(this.key, this.qty);
  final String key;
  final int qty;
}

/// A controller whose [build] resolves only after [gate] completes, so
/// tests can observe the loading state, then transition to data.
class _GatedController extends KeyedCollectionController<_Item> {
  static Completer<void> gate = Completer<void>();
  static CollectionSnapshot<_Item> initial =
      const CollectionSnapshot<_Item>(items: []);

  @override
  Future<CollectionSnapshot<_Item>> build() async {
    await gate.future;
    return initial;
  }
}

final _sourceProvider =
    AsyncNotifierProvider<_GatedController, CollectionSnapshot<_Item>>(
  _GatedController.new,
);

void main() {
  group('derived counts', () {
    setUp(() {
      _GatedController.gate = Completer<void>();
      _GatedController.initial =
          const CollectionSnapshot<_Item>(items: []);
    });

    test('count returns whenAbsent (0) while loading', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final countProvider = collectionCountProvider(_sourceProvider);

      // build() is gated -> still loading.
      expect(container.read(_sourceProvider).isLoading, isTrue);
      expect(container.read(countProvider), 0);
    });

    test('count reflects source data and reacts to changes', () async {
      _GatedController.initial = const CollectionSnapshot<_Item>(
        items: [_Item('a', 1), _Item('b', 2)],
        revision: 1,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final countProvider = collectionCountProvider(_sourceProvider);

      _GatedController.gate.complete();
      await container.read(_sourceProvider.future);

      expect(container.read(countProvider), 2);

      // Mutate the source snapshot via the notifier; count must follow.
      const grown = AsyncValue<CollectionSnapshot<_Item>>.data(
        CollectionSnapshot<_Item>(
          items: [_Item('a', 1), _Item('b', 2), _Item('c', 3)],
          revision: 2,
        ),
      );
      container.read(_sourceProvider.notifier).state = grown;
      expect(container.read(countProvider), 3);
    });

    test('distinct count dedupes by key', () async {
      _GatedController.initial = const CollectionSnapshot<_Item>(
        items: [_Item('a', 1), _Item('a', 9), _Item('b', 2)],
        revision: 1,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final distinct = collectionDistinctCountProvider(
        _sourceProvider,
        keyOf: (item) => item.key,
      );

      _GatedController.gate.complete();
      await container.read(_sourceProvider.future);

      expect(container.read(distinct), 2);
    });

    test('reduce sums a non-money quantity and falls back when absent',
        () async {
      _GatedController.initial = const CollectionSnapshot<_Item>(
        items: [_Item('a', 1), _Item('b', 4)],
        revision: 1,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final totalQty = collectionReduceProvider<_GatedController, _Item, int>(
        _sourceProvider,
        initial: 0,
        reducer: (acc, item) => acc + item.qty,
        whenAbsent: 0,
      );

      // Loading first.
      expect(container.read(totalQty), 0);

      _GatedController.gate.complete();
      await container.read(_sourceProvider.future);

      expect(container.read(totalQty), 5);
    });
  });
}
