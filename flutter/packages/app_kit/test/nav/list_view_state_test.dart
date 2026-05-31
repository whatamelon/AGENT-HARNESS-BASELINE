import 'package:app_kit/src/nav/list_view_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListViewState value semantics', () {
    test('defaults are empty/neutral', () {
      const s = ListViewState();
      expect(s.filters, isEmpty);
      expect(s.sort, '');
      expect(s.query, '');
      expect(s.scrollAnchor, isNull);
    });

    test('copyWith is immutable and overrides only given fields', () {
      const base = ListViewState(filters: {'a': '1'}, sort: 'price');
      final next = base.copyWith(query: '국화');
      expect(base.query, '');
      expect(next.query, '국화');
      expect(next.filters, {'a': '1'});
      expect(next.sort, 'price');
      // base unchanged (no mutation).
      expect(base.filters, {'a': '1'});
    });

    test('clearScrollAnchor resets the anchor to null', () {
      const base = ListViewState(scrollAnchor: 'item-42');
      final cleared = base.copyWith(clearScrollAnchor: true);
      expect(cleared.scrollAnchor, isNull);
      // plain copyWith keeps the anchor.
      expect(base.copyWith(query: 'x').scrollAnchor, 'item-42');
    });

    test('equality uses mapEquals (order-independent value equality)', () {
      const a = ListViewState(filters: {'x': '1', 'y': '2'});
      const b = ListViewState(filters: {'y': '2', 'x': '1'});
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      const c = ListViewState(filters: {'x': '1'});
      expect(a, isNot(equals(c)));
    });
  });

  group('ListViewStateNotifier (route-scoped, immutable mutations)', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('setFilter accumulates and survives across reads', () {
      final notifier =
          container.read(listViewStateProvider('/park/shop').notifier)
            ..setFilter('category', 'urn')
            ..setFilter('sort', 'low');

      final read = container.read(listViewStateProvider('/park/shop'));
      expect(read.filters, {'category': 'urn', 'sort': 'low'});
      // The same family arg returns the same slice.
      expect(read, same(notifier.state));
    });

    test('clearFilters keeps other intent fields', () {
      final notifier =
          container.read(listViewStateProvider('/k').notifier)
            ..setFilter('a', '1')
            ..setQuery('hello')
            ..setSort('newest')
            ..clearFilters();
      final s = container.read(listViewStateProvider('/k'));
      expect(s.filters, isEmpty);
      expect(s.query, 'hello');
      expect(s.sort, 'newest');
      expect(notifier.state.filters, isEmpty);
    });

    test('removeFilter drops only the given key', () {
      container.read(listViewStateProvider('/k').notifier)
        ..setFilter('a', '1')
        ..setFilter('b', '2')
        ..removeFilter('a');
      expect(container.read(listViewStateProvider('/k')).filters, {'b': '2'});
    });

    test('rememberAnchor sets and clears the semantic anchor', () {
      final n = container.read(listViewStateProvider('/k').notifier)
        ..rememberAnchor('item-7');
      expect(container.read(listViewStateProvider('/k')).scrollAnchor, 'item-7');
      n.rememberAnchor(null);
      expect(container.read(listViewStateProvider('/k')).scrollAnchor, isNull);
    });

    test('different route keys are independent slices', () {
      container.read(listViewStateProvider('/a').notifier).setQuery('aaa');
      container.read(listViewStateProvider('/b').notifier).setQuery('bbb');
      expect(container.read(listViewStateProvider('/a')).query, 'aaa');
      expect(container.read(listViewStateProvider('/b')).query, 'bbb');
    });
  });
}
