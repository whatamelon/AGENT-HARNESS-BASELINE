import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    setUp(AppConfig.resetForTest);
    tearDown(AppConfig.resetForTest);

    test('current throws before init', () {
      expect(() => AppConfig.current, throwsStateError);
      expect(AppConfig.isInitialized, isFalse);
    });

    test('init sets current flavor', () {
      AppConfig.init(Flavor.staging);
      expect(AppConfig.current, Flavor.staging);
      expect(AppConfig.isInitialized, isTrue);
    });

    test('re-init with same flavor is idempotent', () {
      AppConfig.init(Flavor.dev);
      AppConfig.init(Flavor.dev);
      expect(AppConfig.current, Flavor.dev);
    });

    test('re-init with different flavor throws', () {
      AppConfig.init(Flavor.dev);
      expect(() => AppConfig.init(Flavor.prod), throwsStateError);
    });
  });

  group('Flavor', () {
    test('labels are human readable', () {
      expect(Flavor.dev.label, 'Development');
      expect(Flavor.staging.label, 'Staging');
      expect(Flavor.prod.label, 'Production');
    });

    test('isProd only true for prod', () {
      expect(Flavor.prod.isProd, isTrue);
      expect(Flavor.dev.isProd, isFalse);
      expect(Flavor.staging.isProd, isFalse);
    });
  });
}
