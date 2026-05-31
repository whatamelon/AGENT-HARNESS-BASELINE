/// PII gate for analytics — the boundary that keeps 추모/상조 PII out of any
/// external analytics SDK.
///
/// A decorator over another [AnalyticsSink]. Before forwarding an event it:
///   (a) **drops** any param whose key is in the blocked-key set (deceased
///       name, mourner name, contract number, amount, phone, email, RRN,
///       address) — these never leave the device under any form, and
///   (b) **masks** every remaining value through `redactSensitive` so a phone
///       or email embedded in an otherwise-allowed value is still scrubbed.
///
/// Why this matters: if 고인명/계약번호/금액 reach an external analytics SDK it is
/// a PIPA(개인정보보호법) violation. This sink is the single chokepoint, so wrap
/// the real provider sink in `RedactingSink` at wiring time.
library;

import 'package:core/src/analytics/analytics_event.dart';
import 'package:core/src/analytics/analytics_sink.dart';
import 'package:core/src/network/log_redaction.dart';

/// An [AnalyticsSink] decorator that strips/masks PII before delegating.
class RedactingSink implements AnalyticsSink {
  /// Wraps an inner sink so all forwarded events pass the PII gate first.
  const RedactingSink(this._inner);

  final AnalyticsSink _inner;

  /// Param keys that must never reach an analytics provider, in any form.
  ///
  /// Matched case-insensitively. Dropped entirely (not masked) — the safest
  /// outcome for direct-identifier fields.
  static const Set<String> blockedKeys = <String>{
    'deceased_name',
    'mourner_name',
    'contract_no',
    'amount',
    'phone',
    'email',
    'rrn',
    'address',
  };

  @override
  Future<void> logEvent(AnalyticsEvent event) {
    final sanitized = <String, Object?>{};
    for (final entry in event.params.entries) {
      if (blockedKeys.contains(entry.key.toLowerCase())) continue;
      sanitized[entry.key] = _maskValue(entry.value);
    }
    return _inner.logEvent(AnalyticsEvent(event.name, params: sanitized));
  }

  @override
  Future<void> setScreen(String name) => _inner.setScreen(name);

  @override
  Future<void> setUserId(String? id) => _inner.setUserId(id);

  /// Masks string values via [redactSensitive]; passes through non-strings.
  static Object? _maskValue(Object? value) =>
      value is String ? redactSensitive(value) : value;
}
