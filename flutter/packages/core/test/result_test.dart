import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Ok reports isOk / isErr correctly', () {
      const Result<int, String> r = Ok(1);
      expect(r.isOk, isTrue);
      expect(r.isErr, isFalse);
    });

    test('Err reports isOk / isErr correctly', () {
      const Result<int, String> r = Err('boom');
      expect(r.isErr, isTrue);
      expect(r.isOk, isFalse);
    });

    test('fold collapses both branches', () {
      const Result<int, String> ok = Ok(2);
      const Result<int, String> err = Err('e');
      expect(ok.fold((v) => 'v$v', (f) => 'f$f'), 'v2');
      expect(err.fold((v) => 'v$v', (f) => 'f$f'), 'fe');
    });

    test('when is an alias for fold', () {
      const Result<int, String> ok = Ok(3);
      final result = ok.when(ok: (v) => v * 2, err: (_) => -1);
      expect(result, 6);
    });

    test('map transforms only the success value', () {
      const Result<int, String> ok = Ok(4);
      const Result<int, String> err = Err('x');
      expect(ok.map((v) => v + 1), const Ok<int, String>(5));
      expect(err.map((v) => v + 1), const Err<int, String>('x'));
    });

    test('mapErr transforms only the failure value', () {
      const Result<int, String> ok = Ok(5);
      const Result<int, String> err = Err('x');
      expect(ok.mapErr((f) => '$f!'), const Ok<int, String>(5));
      expect(err.mapErr((f) => '$f!'), const Err<int, String>('x!'));
    });

    test('map does not mutate the original (immutability)', () {
      const Result<int, String> original = Ok(10);
      final mapped = original.map((v) => v + 100);
      expect(original, const Ok<int, String>(10));
      expect(mapped, const Ok<int, String>(110));
      expect(identical(original, mapped), isFalse);
    });

    test('getOrElse returns value or fallback', () {
      const Result<int, String> ok = Ok(7);
      const Result<int, String> err = Err('e');
      expect(ok.getOrElse((_) => 0), 7);
      expect(err.getOrElse((f) => f.length), 1);
    });

    test('equality and hashCode hold for same branch + payload', () {
      expect(const Ok<int, String>(1), const Ok<int, String>(1));
      expect(const Err<int, String>('a'), const Err<int, String>('a'));
      expect(
        const Ok<int, String>(1).hashCode,
        const Ok<int, String>(1).hashCode,
      );
    });
  });
}
