import 'dart:async';

import 'package:app_kit/src/domain_state/reactive_collection.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StringCollectionController extends KeyedCollectionController<String> {
  @override
  Future<CollectionSnapshot<String>> build() async {
    return const CollectionSnapshot<String>(items: ['a'], revision: 1);
  }
}

final _controllerProvider = AsyncNotifierProvider<_StringCollectionController,
    CollectionSnapshot<String>>(_StringCollectionController.new);

void main() {
  group('CollectionSnapshot', () {
    test('equality is value-based over items and revision', () {
      const a = CollectionSnapshot<String>(items: ['x', 'y'], revision: 2);
      const b = CollectionSnapshot<String>(items: ['x', 'y'], revision: 2);
      const c = CollectionSnapshot<String>(items: ['x', 'y'], revision: 3);
      const d = CollectionSnapshot<String>(items: ['x', 'z'], revision: 2);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('withItems bumps revision by one', () {
      const a = CollectionSnapshot<String>(items: ['x'], revision: 5);
      final next = a.withItems(['x', 'y']);
      expect(next.items, ['x', 'y']);
      expect(next.revision, 6);
    });
  });

  group('KeyedCollectionController.applyOptimistic', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    Future<_StringCollectionController> ready() async {
      await container.read(_controllerProvider.future);
      return container.read(_controllerProvider.notifier);
    }

    test('optimistic apply then confirm reconciles to server truth', () async {
      final controller = await ready();

      final result = await controller.applyOptimistic<List<String>>(
        key: 'b',
        next: const CollectionSnapshot<String>(items: ['a', 'b'], revision: 2),
        commit: () async =>
            const Result<List<String>, AppException>.ok(['a', 'b', 'server']),
        reconcile: (prev, confirmed) => prev.withItems(confirmed),
      );

      expect(result.isOk, isTrue);
      final snapshot = container.read(_controllerProvider).requireValue;
      // Reconciled over the PREVIOUS snapshot (['a'], rev 1) -> rev 2.
      expect(snapshot.items, ['a', 'b', 'server']);
      expect(snapshot.revision, 2);
    });

    test('failure rolls back to the previous snapshot', () async {
      final controller = await ready();
      final before = container.read(_controllerProvider).requireValue;

      final result = await controller.applyOptimistic<List<String>>(
        key: 'b',
        next: const CollectionSnapshot<String>(items: ['a', 'b'], revision: 99),
        commit: () async => const Result<List<String>, AppException>.err(
          ServerException(statusCode: 500),
        ),
        reconcile: (prev, confirmed) => prev.withItems(confirmed),
      );

      expect(result.isErr, isTrue);
      final after = container.read(_controllerProvider).requireValue;
      expect(after, equals(before));
      expect(after.items, ['a']);
      expect(after.revision, 1);
    });

    test('in-flight guard rejects a concurrent same-key write', () async {
      final controller = await ready();
      final gate = Completer<void>();

      final first = controller.applyOptimistic<List<String>>(
        key: 'b',
        next: const CollectionSnapshot<String>(items: ['a', 'b'], revision: 2),
        commit: () async {
          await gate.future;
          return const Result<List<String>, AppException>.ok(['a', 'b']);
        },
        reconcile: (prev, confirmed) => prev.withItems(confirmed),
      );

      expect(controller.isInFlight('b'), isTrue);

      final second = await controller.applyOptimistic<List<String>>(
        key: 'b',
        next: const CollectionSnapshot<String>(
          items: ['a', 'b', 'c'],
          revision: 3,
        ),
        commit: () async =>
            const Result<List<String>, AppException>.ok(['a', 'b', 'c']),
        reconcile: (prev, confirmed) => prev.withItems(confirmed),
      );

      expect(second.isErr, isTrue);
      second.fold(
        (_) => fail('expected rejection'),
        (err) {
          expect(err, isA<ConflictException>());
          expect((err as ConflictException).status, kConcurrentWriteStatus);
        },
      );

      gate.complete();
      final firstResult = await first;
      expect(firstResult.isOk, isTrue);
      expect(controller.isInFlight('b'), isFalse);
    });

    test('a different key is allowed while another is in flight', () async {
      final controller = await ready();
      final gate = Completer<void>();

      final first = controller.applyOptimistic<List<String>>(
        key: 'b',
        next: const CollectionSnapshot<String>(items: ['a', 'b'], revision: 2),
        commit: () async {
          await gate.future;
          return const Result<List<String>, AppException>.ok(['a', 'b']);
        },
        reconcile: (prev, confirmed) => prev.withItems(confirmed),
      );

      final second = await controller.applyOptimistic<List<String>>(
        key: 'c',
        next: const CollectionSnapshot<String>(items: ['a', 'c'], revision: 2),
        commit: () async =>
            const Result<List<String>, AppException>.ok(['a', 'c']),
        reconcile: (prev, confirmed) => prev.withItems(confirmed),
      );

      expect(second.isOk, isTrue);
      gate.complete();
      expect((await first).isOk, isTrue);
    });
  });
}
