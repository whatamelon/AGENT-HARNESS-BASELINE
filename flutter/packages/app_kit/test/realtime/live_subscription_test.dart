/// Tests for [LiveSubscriptionController] and [LiveState].
///
/// All tests use fake streams and zero-duration backoff so no real timers fire.
/// No Supabase or auth imports — transport is injected via fakes.
library;

import 'dart:async';

import 'package:app_kit/src/realtime/live_subscription.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Concrete [LiveSubscriptionController] driven by test-supplied callbacks.
///
/// [backoffDuration] always returns [Duration.zero] so retries are instant.
class _FakeController extends LiveSubscriptionController<String> {
  _FakeController({
    required this.subscribeStream,
    required this.fetchValue,
    this.onBreadcrumb,
  });

  /// The stream returned by [subscribe].  Replace before each test assertion
  /// by assigning a new controller.
  Stream<String> subscribeStream;

  /// The value (or error) returned by [refetch].
  Object fetchValue; // String | Exception

  int refetchCalls = 0;
  final void Function(String)? onBreadcrumb;

  @override
  Stream<String> subscribe() => subscribeStream;

  @override
  Future<String> refetch() async {
    refetchCalls++;
    final v = fetchValue;
    if (v is Exception) throw v;
    return v as String;
  }

  @override
  Duration backoffDuration(int attempt) => Duration.zero;

  @override
  void onConnectionBreadcrumb(String message) => onBreadcrumb?.call(message);
}

/// Builds a [ProviderContainer] with a [_FakeController] bound to a fresh
/// [NotifierProvider].
({
  ProviderContainer container,
  _FakeController controller,
  NotifierProvider<_FakeController, LiveState<String>> provider,
}) _setup({
  StreamController<String>? streamCtrl,
  String fetchValue = 'initial',
  void Function(String)? onBreadcrumb,
}) {
  final sc = streamCtrl ?? StreamController<String>.broadcast();
  final ctrl = _FakeController(
    subscribeStream: sc.stream,
    fetchValue: fetchValue,
    onBreadcrumb: onBreadcrumb,
  );
  final provider =
      NotifierProvider<_FakeController, LiveState<String>>(() => ctrl);
  final container = ProviderContainer();
  return (container: container, controller: ctrl, provider: provider);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LiveState', () {
    test('isStale is false only when connection == live', () {
      expect(
        const LiveState<String>(
          connection: LiveConnectionState.live,
        ).isStale,
        isFalse,
      );
      expect(
        const LiveState<String>().isStale,
        isTrue,
      );
      expect(
        const LiveState<String>(
          connection: LiveConnectionState.reconnecting,
        ).isStale,
        isTrue,
      );
      expect(
        const LiveState<String>(
          connection: LiveConnectionState.error,
        ).isStale,
        isTrue,
      );
    });

    test('copyWith overrides only provided fields', () {
      const base = LiveState<String>(
        data: 'a',
        connection: LiveConnectionState.live,
      );
      final next = base.copyWith(connection: LiveConnectionState.reconnecting);
      expect(next.data, 'a');
      expect(next.connection, LiveConnectionState.reconnecting);
      expect(next.error, isNull);
    });

    test('value equality and hashCode', () {
      const a = LiveState<int>(data: 1, connection: LiveConnectionState.live);
      // ignore: prefer_const_constructors — intentional separate instance
      final b = LiveState<int>(data: 1, connection: LiveConnectionState.live);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      const c = LiveState<int>(
        data: 1,
        connection: LiveConnectionState.reconnecting,
      );
      expect(a, isNot(equals(c)));
    });
  });

  group('LiveSubscriptionController — happy path', () {
    test('initial state is connecting', () {
      final sc = StreamController<String>.broadcast();
      addTearDown(sc.close);
      final (:container, :controller, :provider) =
          _setup(streamCtrl: sc, fetchValue: 'hello');
      addTearDown(container.dispose);

      // Read synchronously before any microtask completes.
      final state = container.read(provider);
      expect(state.connection, LiveConnectionState.connecting);
      expect(state.data, isNull);
    });

    test('connecting → live on first refetch + stream event', () async {
      final sc = StreamController<String>.broadcast();
      addTearDown(sc.close);
      final (:container, :controller, :provider) =
          _setup(streamCtrl: sc, fetchValue: 'seeded');
      addTearDown(container.dispose);

      // Listen so the provider stays alive.
      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);

      // Allow microtask (_connect) to run.
      await Future<void>.delayed(Duration.zero);

      // After refetch completes, state should be live with seeded data.
      final state = container.read(provider);
      expect(state.connection, LiveConnectionState.live);
      expect(state.data, 'seeded');
      expect(state.isStale, isFalse);
      expect(controller.refetchCalls, 1);
    });

    test('stream event updates data while staying live', () async {
      final sc = StreamController<String>.broadcast();
      addTearDown(sc.close);
      final (:container, :controller, :provider) =
          _setup(streamCtrl: sc, fetchValue: 'seed');
      addTearDown(container.dispose);

      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).connection, LiveConnectionState.live);

      sc.add('event-1');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(provider);
      expect(state.data, 'event-1');
      expect(state.connection, LiveConnectionState.live);
    });
  });

  group('LiveSubscriptionController — reconnect / backoff', () {
    test('stream error → reconnecting → refetch called → live again', () async {
      final sc = StreamController<String>.broadcast();
      final (:container, :controller, :provider) =
          _setup(streamCtrl: sc, fetchValue: 'v1');
      addTearDown(container.dispose);

      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);

      // Initial connect.
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).connection, LiveConnectionState.live);
      expect(controller.refetchCalls, 1);

      // Trigger a stream error.
      sc.addError(Exception('transport failure'));
      await Future<void>.delayed(Duration.zero);

      // Should enter reconnecting immediately.
      expect(
        container.read(provider).connection,
        LiveConnectionState.reconnecting,
      );
      expect(container.read(provider).isStale, isTrue);

      // Backoff is zero → reconnect happens in a microtask/timer tick.
      // Allow the Timer(Duration.zero) to fire.
      await Future<void>.delayed(Duration.zero);

      // After reconnect, refetch is called again and state becomes live.
      expect(container.read(provider).connection, LiveConnectionState.live);
      expect(container.read(provider).data, 'v1');
      expect(controller.refetchCalls, 2);

      await sc.close();
    });

    test('stream done → reconnect → live after retry', () async {
      final sc = StreamController<String>.broadcast();
      final (:container, :controller, :provider) =
          _setup(streamCtrl: sc, fetchValue: 'data');
      addTearDown(container.dispose);

      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).connection, LiveConnectionState.live);

      // Hand the controller a FRESH open stream for the upcoming reconnect.
      // Real transport returns a new live channel on each subscribe(); reusing
      // the about-to-close `sc.stream` would make the reconnect re-subscribe
      // to an already-done stream that immediately re-fires onDone, looping
      // forever in `reconnecting`. (The error-path sibling keeps `sc` open
      // because addError with cancelOnError:false does not close the stream.)
      final reconnectSc = StreamController<String>.broadcast();
      addTearDown(reconnectSc.close);
      controller.subscribeStream = reconnectSc.stream;

      // Close the original stream (onDone). With zero backoff the full
      // onDone → reconnecting → refetch → live cycle collapses into a single
      // settled state, so we assert the END state (live) and that exactly one
      // extra refetch ran. The transient `reconnecting` snapshot is covered
      // observably by the dedicated `isStale is true while reconnecting` test
      // below; asserting it here would race the instantaneous reconnect.
      await sc.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(container.read(provider).connection, LiveConnectionState.live);
      expect(controller.refetchCalls, 2);
    });

    test('isStale is true while reconnecting', () async {
      final sc = StreamController<String>.broadcast();
      final (:container, :controller, :provider) =
          _setup(streamCtrl: sc, fetchValue: 'v');
      addTearDown(container.dispose);

      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).isStale, isFalse);

      // Use a separate controller to verify reconnecting state is visible
      // immediately after the stream errors (before backoff timer fires).
      final pauseSc = StreamController<String>.broadcast();
      final pauseCtrl = _FakeController(
        subscribeStream: pauseSc.stream,
        fetchValue: 'p',
      );
      final pauseProvider =
          NotifierProvider<_FakeController, LiveState<String>>(
        () => pauseCtrl,
      );
      final pauseContainer = ProviderContainer();
      addTearDown(pauseContainer.dispose);
      addTearDown(pauseSc.close);

      final pauseSub = pauseContainer.listen(pauseProvider, (_, __) {});
      addTearDown(pauseSub.close);

      await Future<void>.delayed(Duration.zero);
      expect(
        pauseContainer.read(pauseProvider).connection,
        LiveConnectionState.live,
      );

      pauseSc.addError(Exception('err'));
      await Future<void>.delayed(Duration.zero);

      // Immediately after the stream error the state is reconnecting.
      expect(pauseContainer.read(pauseProvider).isStale, isTrue);
      expect(
        pauseContainer.read(pauseProvider).connection,
        LiveConnectionState.reconnecting,
      );
    });
  });

  group('LiveSubscriptionController — no stale snapshot after resume', () {
    test(
        'on reconnect, data is shown only after fresh refetch, '
        'not from prior snapshot', () async {
      final sc = StreamController<String>.broadcast();
      final (:container, :controller, :provider) =
          _setup(streamCtrl: sc, fetchValue: 'v1');
      addTearDown(container.dispose);

      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).data, 'v1');
      expect(container.read(provider).connection, LiveConnectionState.live);

      // Simulate resume: error the stream, then update fetch to return v2.
      controller.fetchValue = 'v2';
      sc.addError(Exception('resume'));
      await Future<void>.delayed(Duration.zero);

      // Reconnecting state: connection is reconnecting (isStale=true).
      // Data field may still hold 'v1' as the last-seen value, but it is
      // gated by isStale — consumers MUST NOT show it as authoritative.
      expect(
        container.read(provider).connection,
        LiveConnectionState.reconnecting,
      );
      expect(container.read(provider).isStale, isTrue);

      // After backoff fires → reconnect → refetch returns 'v2'.
      await Future<void>.delayed(Duration.zero);

      expect(container.read(provider).connection, LiveConnectionState.live);
      expect(container.read(provider).data, 'v2'); // fresh value
      expect(container.read(provider).isStale, isFalse);
      expect(controller.refetchCalls, 2);

      await sc.close();
    });
  });

  group('LiveSubscriptionController — dispose', () {
    test('dispose cancels subscription — no events processed after dispose',
        () async {
      final sc = StreamController<String>.broadcast();
      addTearDown(sc.close);
      final (:container, :controller, :provider) =
          _setup(streamCtrl: sc, fetchValue: 'seed');

      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).data, 'seed');

      // Dispose the container (triggers onDispose on the notifier).
      container.dispose();

      // Emit an event after dispose.
      sc.add('post-dispose');
      await Future<void>.delayed(Duration.zero);

      // The container is disposed; any attempt to read would throw. We verify
      // no crash and the stream add did not cause any side effect by checking
      // the controller's refetchCalls did not increase beyond initial 1.
      expect(
        controller.refetchCalls,
        1,
        reason: 'no reconnect should trigger after dispose',
      );
    });

    test('dispose cancels pending retry timer', () async {
      late _FakeController ctrl;
      late NotifierProvider<_FakeController, LiveState<String>> prov;
      final localSc = StreamController<String>.broadcast();
      ctrl = _FakeController(
        subscribeStream: localSc.stream,
        fetchValue: 'v',
      );
      prov = NotifierProvider<_FakeController, LiveState<String>>(() => ctrl);
      final c2 = ProviderContainer();

      final s2 = c2.listen(prov, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      expect(c2.read(prov).connection, LiveConnectionState.live);

      // Trigger reconnect.
      localSc.addError(Exception('e'));
      await Future<void>.delayed(Duration.zero);
      expect(c2.read(prov).connection, LiveConnectionState.reconnecting);

      // Dispose before the timer fires — should not throw or reconnect.
      s2.close();
      c2.dispose();

      // Allow any pending microtasks to drain — no crash expected.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await localSc.close();
      // Test passes if no exception is thrown.
    });
  });

  group('LiveSubscriptionController — observability port', () {
    test('breadcrumbs include connection transitions, no payload', () async {
      final crumbs = <String>[];
      final sc = StreamController<String>.broadcast();
      addTearDown(sc.close);
      final (:container, :controller, :provider) = _setup(
        streamCtrl: sc,
        fetchValue: 'x',
        onBreadcrumb: crumbs.add,
      );
      addTearDown(container.dispose);

      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);

      // At least a connecting and a live breadcrumb should have been emitted.
      expect(crumbs.any((c) => c.contains('connecting')), isTrue);
      expect(crumbs.any((c) => c.contains('live')), isTrue);

      // No breadcrumb should contain the actual data value.
      for (final crumb in crumbs) {
        expect(
          crumb,
          isNot(contains('x')),
          reason: 'payload must not appear in breadcrumbs',
        );
      }
    });
  });
}
