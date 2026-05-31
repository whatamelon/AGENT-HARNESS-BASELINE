/// Port over a product-analytics provider (GA4 / Amplitude / Mixpanel / ...).
///
/// Mirrors the `push_backend.dart` / `auth_ports.dart` convention: nothing here
/// imports an analytics SDK, so the boundary stays one-way and the wiring stays
/// testable. Production binds this to a concrete SDK adapter; the harness ships
/// `NoopSink` (default), `LoggerSink` (dev), and `RedactingSink` (PII gate).
library;

import 'package:core/src/analytics/analytics_event.dart';

/// SDK-neutral analytics sink. Implementations forward events to a provider.
///
/// All methods are async to match SDK shapes but must never throw — analytics
/// is best-effort and must not break the calling flow.
abstract class AnalyticsSink {
  /// Records a single [event].
  Future<void> logEvent(AnalyticsEvent event);

  /// Sets the current screen/route [name] for screen-view attribution.
  Future<void> setScreen(String name);

  /// Associates subsequent events with a user identity.
  ///
  /// Only a **hashed/pseudonymous** id may be passed — never a raw email,
  /// phone, RRN, or name. Pass `null` to clear identity (e.g. on sign-out).
  Future<void> setUserId(String? id);
}
