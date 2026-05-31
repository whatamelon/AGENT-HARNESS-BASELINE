import 'package:app_kit/src/domain_state/collection_repository.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCollectionRepository implements CollectionRepository<String> {
  _FakeCollectionRepository(this._items);

  final List<String> _items;
  bool failNext = false;

  @override
  Future<Result<List<String>, AppException>> fetch() async {
    if (failNext) {
      return const Result<List<String>, AppException>.err(NetworkException());
    }
    return Result<List<String>, AppException>.ok(List.unmodifiable(_items));
  }

  @override
  Future<Result<String, AppException>> upsert(String item) async {
    if (failNext) {
      return const Result<String, AppException>.err(
        ConflictException(status: 'already_in_cart'),
      );
    }
    return Result<String, AppException>.ok('confirmed:$item');
  }

  @override
  Future<Result<void, AppException>> remove(String key) async {
    if (failNext) {
      return const Result<void, AppException>.err(
        ServerException(statusCode: 500),
      );
    }
    return const Result<void, AppException>.ok(null);
  }
}

void main() {
  group('CollectionRepository contract', () {
    test('a fake impl satisfies the abstract port', () {
      final CollectionRepository<String> repo =
          _FakeCollectionRepository(['a', 'b']);
      expect(repo, isA<CollectionRepository<String>>());
    });

    test('fetch returns Ok list on success', () async {
      final repo = _FakeCollectionRepository(['a', 'b']);
      final result = await repo.fetch();
      expect(result.isOk, isTrue);
      expect(result.getOrElse((_) => const []), ['a', 'b']);
    });

    test('upsert returns server-confirmed value', () async {
      final repo = _FakeCollectionRepository([]);
      final result = await repo.upsert('x');
      expect(result.getOrElse((_) => ''), 'confirmed:x');
    });

    test('errors surface as AppException subtypes', () async {
      final repo = _FakeCollectionRepository(['a'])..failNext = true;
      final fetchRes = await repo.fetch();
      final upsertRes = await repo.upsert('x');
      final removeRes = await repo.remove('a');

      expect(fetchRes.isErr, isTrue);
      fetchRes.fold(
        (_) => fail('expected err'),
        (e) => expect(e, isA<NetworkException>()),
      );
      upsertRes.fold((_) => fail('expected err'), (e) {
        expect(e, isA<ConflictException>());
        expect((e as ConflictException).status, 'already_in_cart');
      });
      removeRes.fold(
        (_) => fail('expected err'),
        (e) => expect(e, isA<ServerException>()),
      );
    });
  });
}
