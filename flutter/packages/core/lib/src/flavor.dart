/// Build flavors the harness supports.
enum Flavor {
  dev,
  staging,
  prod;

  /// Human-readable label for UI / logs.
  String get label => switch (this) {
        Flavor.dev => 'Development',
        Flavor.staging => 'Staging',
        Flavor.prod => 'Production',
      };

  bool get isProd => this == Flavor.prod;
}

/// Holds the active [Flavor] for the running app.
///
/// Initialized exactly once at startup by the chosen entrypoint
/// (`main_dev.dart` / `main_staging.dart` / `main_prod.dart`) before
/// `runApp`. Reading [current] before [init] throws to surface wiring bugs.
abstract final class AppConfig {
  static Flavor? _flavor;

  /// Sets the active flavor. Idempotent only for the same value; calling with
  /// a different flavor after init throws to catch double-bootstrap mistakes.
  static void init(Flavor flavor) {
    final existing = _flavor;
    if (existing != null && existing != flavor) {
      throw StateError(
        'AppConfig already initialized as ${existing.name}, '
        'cannot re-init as ${flavor.name}.',
      );
    }
    _flavor = flavor;
  }

  /// The active flavor. Throws [StateError] if [init] has not run.
  static Flavor get current {
    final flavor = _flavor;
    if (flavor == null) {
      throw StateError('AppConfig.init(Flavor) must be called before current.');
    }
    return flavor;
  }

  /// Whether a flavor has been set. Useful for tests / guards.
  static bool get isInitialized => _flavor != null;

  /// Test-only reset hook.
  static void resetForTest() => _flavor = null;
}
