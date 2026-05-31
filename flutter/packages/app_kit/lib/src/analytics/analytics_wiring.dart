/// Production analytics wiring — binds `core`'s SDK-neutral [AnalyticsSink] to
/// `firebase_analytics` (GA4).
///
/// Like `payment_wiring.dart` / `push_wiring.dart`, this is the ONLY analytics
/// file that imports the SDK and it is excluded from unit tests (the harness
/// tests the `core` sinks — `NoopSink`/`RedactingSink` — with fakes). It
/// compiles under `dart analyze` but is never executed by the test suite.
///
/// PII GATE — MUST be wrapped in `RedactingSink`. NEVER inject a raw
/// [FirebaseAnalyticsSink] into the app: 추모/상조 PII (고인명·계약번호·금액·전화·
/// 이메일) reaching GA4 is a PIPA(개인정보보호법) violation. The required wiring is:
///
/// ```dart
/// // `analyticsEnabled` is an app-owned flag (e.g. a build-time env check),
/// // mirroring how `core` gates Sentry on `AppEnv.hasSentry`.
/// final AnalyticsSink sink = analyticsEnabled
///     ? RedactingSink(FirebaseAnalyticsSink())  // gate, then forward
///     : const NoopSink();                        // disabled -> safe no-op
/// ```
///
/// This mirrors `core`'s `hasSentry` discipline (`initObservability` no-ops
/// when no DSN): with analytics disabled the app falls back to `NoopSink`
/// rather than crashing or silently leaking. The actual toggle lives in the
/// app's wiring (`core` exposes `NoopSink`/`RedactingSink`; this package
/// supplies the Firebase adapter the app composes).
library;

import 'package:core/core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// [AnalyticsSink] over `FirebaseAnalytics` (GA4).
///
/// All methods are best-effort and never throw (the [AnalyticsSink] contract):
/// a Firebase error is swallowed so analytics can never break a calling flow.
/// Do NOT use directly — compose as `RedactingSink(FirebaseAnalyticsSink())`.
class FirebaseAnalyticsSink implements AnalyticsSink {
  /// Creates a [FirebaseAnalyticsSink].
  FirebaseAnalyticsSink([FirebaseAnalytics? analytics])
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    try {
      await _analytics.logEvent(
        name: event.name,
        parameters: _toFirebaseParams(event.params),
      );
    } on Object {
      // Best-effort: analytics must never break the calling flow.
    }
  }

  @override
  Future<void> setScreen(String name) async {
    try {
      await _analytics.logScreenView(screenName: name);
    } on Object {
      // Best-effort.
    }
  }

  @override
  Future<void> setUserId(String? id) async {
    try {
      await _analytics.setUserId(id: id);
    } on Object {
      // Best-effort.
    }
  }

  /// GA4 `logEvent` only accepts `String`/`num` parameter values. Drop nulls
  /// and stringify anything that is neither (the `RedactingSink` upstream has
  /// already removed/masked PII before this runs).
  static Map<String, Object>? _toFirebaseParams(Map<String, Object?> params) {
    if (params.isEmpty) return null;
    final out = <String, Object>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value == null) continue;
      out[entry.key] = (value is num || value is String) ? value : '$value';
    }
    return out.isEmpty ? null : out;
  }
}
