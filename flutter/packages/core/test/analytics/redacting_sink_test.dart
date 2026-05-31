import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-written recording fake (no mockito/mocktail, per harness convention).
class _RecordingSink implements AnalyticsSink {
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];
  final List<String> screens = <String>[];
  final List<String?> userIds = <String?>[];

  @override
  Future<void> logEvent(AnalyticsEvent event) async => events.add(event);

  @override
  Future<void> setScreen(String name) async => screens.add(name);

  @override
  Future<void> setUserId(String? id) async => userIds.add(id);
}

void main() {
  group('RedactingSink', () {
    late _RecordingSink inner;
    late RedactingSink sink;

    setUp(() {
      inner = _RecordingSink();
      sink = RedactingSink(inner);
    });

    test('drops every blocked PII key (case-insensitive)', () async {
      await sink.logEvent(
        const AnalyticsEvent(
          AnalyticsEvent.parkContractStarted,
          params: <String, Object?>{
            'deceased_name': '홍길동',
            'Mourner_Name': '김상주',
            'contract_no': 'C-2026-001',
            'amount': 1500000,
            'phone': '010-1234-5678',
            'email': 'a@b.com',
            'rrn': '900101-1234567',
            'address': '서울시 강남구',
            'plot_section': 'A-12',
          },
        ),
      );

      expect(inner.events, hasLength(1));
      final params = inner.events.single.params;
      for (final blocked in RedactingSink.blockedKeys) {
        expect(params.containsKey(blocked), isFalse, reason: blocked);
      }
      expect(params.containsKey('Mourner_Name'), isFalse);
      // Non-PII key survives.
      expect(params['plot_section'], 'A-12');
    });

    test('masks PII embedded in surviving string values', () async {
      await sink.logEvent(
        const AnalyticsEvent(
          'park_note',
          params: <String, Object?>{
            'note': 'call user@example.com or 010-1234-5678',
            'count': 3,
          },
        ),
      );

      final params = inner.events.single.params;
      final note = params['note']! as String;
      expect(note.contains('user@example.com'), isFalse);
      expect(note.contains('010-1234-5678'), isFalse);
      // Non-string values pass through untouched.
      expect(params['count'], 3);
    });

    test('preserves the event name', () async {
      await sink.logEvent(
        const AnalyticsEvent(AnalyticsEvent.onyuReferralSent),
      );
      expect(inner.events.single.name, AnalyticsEvent.onyuReferralSent);
    });

    test('delegates setScreen and setUserId unchanged', () async {
      await sink.setScreen('/park/contract');
      await sink.setUserId('hashed-abc123');
      await sink.setUserId(null);

      expect(inner.screens, <String>['/park/contract']);
      expect(inner.userIds, <String?>['hashed-abc123', null]);
    });
  });

  group('NoopSink', () {
    test('every call is a no-op and never throws', () async {
      const sink = NoopSink();
      await sink.logEvent(const AnalyticsEvent('x'));
      await sink.setScreen('home');
      await sink.setUserId('id');
      await sink.setUserId(null);
    });
  });

  group('LoggerSink', () {
    test('logs without throwing', () async {
      const sink = LoggerSink();
      await sink.logEvent(
        const AnalyticsEvent(
          AnalyticsEvent.parkPaymentCompleted,
          params: <String, Object?>{'method': 'card'},
        ),
      );
      await sink.setScreen('/park/payment');
      await sink.setUserId('hashed-1');
      await sink.setUserId(null);
    });
  });
}
