/// SDK-neutral product-analytics event model and domain taxonomy.
///
/// No analytics SDK is imported here — `AnalyticsEvent` is a plain value
/// object carried across the `AnalyticsSink` port. The constants below are the
/// canonical event-name taxonomy for the 추모공원(park)/상조(onyu) domains and
/// double as a naming convention guide: `{domain}_{object}_{action}`.
library;

import 'package:meta/meta.dart';

/// A single analytics event: a stable [name] plus structured [params].
///
/// [params] values must be JSON-friendly scalars/maps. Never put PII in the
/// clear here — the `RedactingSink` decorator is the boundary that drops/masks
/// sensitive keys before forwarding to a real SDK, but callers should still
/// pass identifiers (e.g. hashed ids) rather than raw names/contract numbers.
@immutable
class AnalyticsEvent {
  /// Creates an [AnalyticsEvent] with a stable [name] and optional [params].
  const AnalyticsEvent(this.name, {this.params = const <String, Object?>{}});

  /// Stable event name. Prefer the `{domain}_{object}_{action}` taxonomy
  /// constants on this class so dashboards stay consistent across releases.
  final String name;

  /// Structured, JSON-friendly event parameters. Sensitive keys are dropped by
  /// `RedactingSink`; other values are masked via `redactSensitive`.
  final Map<String, Object?> params;

  // --- Domain taxonomy (examples + convention guide) -----------------------
  // Naming: {domain}_{object}_{action}. park_* = 용인공원(추모공원),
  // onyu_* = 온유상조. Extend per feature; keep the prefix discipline.

  /// 용인공원 — 안치/추모 계약 작성 시작.
  static const String parkContractStarted = 'park_contract_started';

  /// 용인공원 — 계약 결제 완료.
  static const String parkPaymentCompleted = 'park_payment_completed';

  /// 용인공원 — 방문(성묘) 예약 생성.
  static const String parkReservationCreated = 'park_reservation_created';

  /// 온유상조 — 상조 계약 작성 시작.
  static const String onyuContractStarted = 'onyu_contract_started';

  /// 온유상조 — 지인 추천 전송.
  static const String onyuReferralSent = 'onyu_referral_sent';

  /// 온유상조 — 장례 진행 단계 전환.
  static const String onyuFuneralStageAdvanced = 'onyu_funeral_stage_advanced';
}
