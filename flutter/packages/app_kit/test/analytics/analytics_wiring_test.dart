import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// `FirebaseAnalyticsSink` is SDK-coupled (firebase_analytics) and is excluded
/// from execution-level unit tests — instantiating it would require a live
/// Firebase binding. This test only asserts the **PII-gate composition** the
/// docs mandate compiles and types correctly: a `FirebaseAnalyticsSink` must be
/// wrappable in a `RedactingSink` and be usable as a `core.AnalyticsSink`.
///
/// The functions below are never invoked; the compiler enforces the contract.
AnalyticsSink _requiredComposition(FirebaseAnalyticsSink raw) =>
    RedactingSink(raw);

AnalyticsSink _disabledFallback() => const NoopSink();

void main() {
  test('FirebaseAnalyticsSink composes into RedactingSink (compile-only)', () {
    // Reference the closures so the analyzer keeps them in scope (they assert
    // the type relationships at compile time without touching the SDK).
    expect(_requiredComposition, isNotNull);
    expect(_disabledFallback(), isA<AnalyticsSink>());
  });
}
