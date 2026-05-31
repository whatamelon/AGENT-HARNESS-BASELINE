import 'dart:convert';

import 'package:app_kit/src/domain_state/guest_collection_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class _Item {
  const _Item(this.id, this.qty);

  factory _Item.fromJson(Map<String, Object?> json) =>
      _Item(json['id']! as String, json['qty']! as int);

  final String id;
  final int qty;

  Map<String, Object> toJson() => {'id': id, 'qty': qty};

  @override
  bool operator ==(Object other) =>
      other is _Item && other.id == id && other.qty == qty;

  @override
  int get hashCode => Object.hash(id, qty);
}

GuestCollectionStore<_Item> _makeStore(SharedPreferences prefs) {
  return GuestCollectionStore<_Item>(
    prefs,
    key: 'guest_cart',
    encode: (item) => jsonEncode(item.toJson()),
    decode: (raw) => _Item.fromJson(jsonDecode(raw) as Map<String, Object?>),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuestCollectionStore', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('load returns empty list when nothing stored', () async {
      final store = _makeStore(prefs);
      expect(await store.load(), isEmpty);
    });

    test('save then load round-trips items', () async {
      final store = _makeStore(prefs);
      final items = [const _Item('a', 1), const _Item('b', 2)];

      await store.save(items);
      final loaded = await store.load();

      expect(loaded, equals(items));
    });

    test('save replaces the previous value', () async {
      final store = _makeStore(prefs);
      await store.save([const _Item('a', 1)]);
      await store.save([const _Item('c', 9)]);

      expect(await store.load(), [const _Item('c', 9)]);
    });

    test('clear removes the persisted value', () async {
      final store = _makeStore(prefs);
      await store.save([const _Item('a', 1)]);
      await store.clear();

      expect(await store.load(), isEmpty);
    });
  });
}
