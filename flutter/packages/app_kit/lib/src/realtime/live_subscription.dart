/// Generic realtime/subscription substrate for the app_kit harness.
///
/// `LiveState` + `LiveSubscriptionController` (abstract Riverpod [Notifier])
/// cycle through `connecting → live → reconnecting` with exponential-backoff
/// retry. Refetch on every (re)connect; never shows a stale snapshot as
/// authoritative (§13.2 SSOT: stale-restore 금지).
///
/// Transport-agnostic: no Supabase import — the concrete subclass supplies
/// `subscribe` / `refetch`.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

// ---------------------------------------------------------------------------
// Connection state
// ---------------------------------------------------------------------------

/// Coarse connection state for a live subscription.
///
/// - [connecting]   — initial; first refetch + stream subscription in-flight.
/// - [live]         — stream is healthy and data is authoritative.
/// - [reconnecting] — stream error/done detected; exponential-backoff retry.
/// - [error]        — refetch failed with a non-retriable exception.
enum LiveConnectionState {
  connecting,
  live,
  reconnecting,
  error,
}

// ---------------------------------------------------------------------------
// State envelope
// ---------------------------------------------------------------------------

/// Immutable state envelope carried by [LiveSubscriptionController].
///
/// `data` is `null` during the initial `connecting` phase and while
/// `reconnecting` if no prior data exists.
///
/// `isStale` is `true` whenever `connection` is not `LiveConnectionState.live`.
/// Consumers MUST gate authoritative display on `!isStale`.
@immutable
final class LiveState<T> {
  /// Creates a [LiveState].
  const LiveState({
    this.data,
    this.connection = LiveConnectionState.connecting,
    this.error,
  });

  /// The most-recent authoritative data, or `null` if not yet received.
  final T? data;

  /// Current connection lifecycle phase.
  final LiveConnectionState connection;

  /// Non-null when [connection] is [LiveConnectionState.error].
  final Object? error;

  /// `true` when data must not be displayed as authoritative.
  ///
  /// Consumers should show a "재연결중" indicator while this is `true`.
  bool get isStale => connection != LiveConnectionState.live;

  /// Returns a copy with the provided overrides.
  LiveState<T> copyWith({
    T? data,
    LiveConnectionState? connection,
    Object? error,
  }) =>
      LiveState<T>(
        data: data ?? this.data,
        connection: connection ?? this.connection,
        error: error ?? this.error,
      );

  @override
  bool operator ==(Object other) =>
      other is LiveState<T> &&
      other.data == data &&
      other.connection == connection &&
      other.error == error;

  @override
  int get hashCode => Object.hash(data, connection, error);

  @override
  String toString() =>
      'LiveState<$T>(connection: $connection, '
      'hasData: ${data != null}, error: $error)';
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Abstract Riverpod [Notifier] that manages a live subscription lifecycle.
///
/// ### Subclass contract
///
/// ```dart
/// class FuneralStepsController
///     extends LiveSubscriptionController<List<Step>> {
///   @override
///   Stream<List<Step>> subscribe() =>
///       supabaseClient.from('funeral_steps').stream(primaryKey: ['id']);
///
///   @override
///   Future<List<Step>> refetch() async {
///     final rows = await supabaseClient.from('funeral_steps').select();
///     return rows.map(Step.fromJson).toList();
///   }
/// }
/// ```
///
/// ### Backoff seam
///
/// Override [backoffDuration] to inject a custom schedule in tests so they
/// never wait for real timers:
///
/// ```dart
/// @override
/// Duration backoffDuration(int attempt) => Duration.zero;
/// ```
///
/// ### Observability port
///
/// Override [onConnectionBreadcrumb] to forward state transitions to your
/// analytics/crash reporter. MUST NOT log payload data — connection state only.
abstract class LiveSubscriptionController<T> extends Notifier<LiveState<T>> {
  // -------------------------------------------------------------------------
  // Abstract interface — apps implement these two methods
  // -------------------------------------------------------------------------

  /// Returns a [Stream] of live events from the subscription transport.
  ///
  /// Called once per (re)connect cycle, after [refetch] seeds the state.
  /// If the stream emits an error or closes, the controller enters
  /// [LiveConnectionState.reconnecting] and retries with backoff.
  Stream<T> subscribe();

  /// Performs a full authoritative fetch from the server.
  ///
  /// Called on every (re)connect before resuming the stream so that no
  /// restored snapshot is ever shown as authoritative.
  Future<T> refetch();

  // -------------------------------------------------------------------------
  // Injectable seams
  // -------------------------------------------------------------------------

  /// Returns the backoff [Duration] for the given [attempt] (0-based).
  ///
  /// Default: exponential 1 s → 2 s → 4 s → 8 s → 16 s → 30 s cap.
  /// Override in tests to return [Duration.zero] for instant retries.
  Duration backoffDuration(int attempt) {
    const caps = <int>[1, 2, 4, 8, 16, 30];
    final seconds = caps[attempt.clamp(0, caps.length - 1)];
    return Duration(seconds: seconds);
  }

  /// Called on every connection-state transition for observability breadcrumbs.
  ///
  /// Default implementation is a no-op. Override to forward to Sentry /
  /// Firebase Analytics. NEVER log [LiveState.data] payload here.
  void onConnectionBreadcrumb(String message) {}

  // -------------------------------------------------------------------------
  // Internal state
  // -------------------------------------------------------------------------

  StreamSubscription<T>? _streamSub;
  Timer? _retryTimer;
  bool _disposed = false;
  int _attempt = 0;

  // -------------------------------------------------------------------------
  // Notifier build
  // -------------------------------------------------------------------------

  @override
  LiveState<T> build() {
    ref.onDispose(_dispose);
    // Kick off the first connect cycle asynchronously so build() is sync.
    unawaited(Future<void>.microtask(_connect));
    return const LiveState();
  }

  // -------------------------------------------------------------------------
  // Connect cycle
  // -------------------------------------------------------------------------

  Future<void> _connect() async {
    if (_disposed) return;

    _breadcrumb('connecting (attempt: $_attempt)');
    state = state.copyWith(connection: LiveConnectionState.connecting);

    T fresh;
    try {
      fresh = await refetch();
    } on Exception catch (e) {
      if (_disposed) return;
      _breadcrumb('refetch error: ${e.runtimeType} — scheduling retry');
      _scheduleReconnect();
      return;
    }

    if (_disposed) return;

    // Flip to live only after refetch succeeds — never show a restored stale
    // snapshot as authoritative.
    state = LiveState<T>(
      data: fresh,
      connection: LiveConnectionState.live,
    );
    _attempt = 0;
    _breadcrumb('live — data seeded from refetch');

    // Subscribe to the stream for incremental updates.
    unawaited(_streamSub?.cancel());
    _streamSub = subscribe().listen(
      _onEvent,
      onError: _onStreamError,
      onDone: _onStreamDone,
      cancelOnError: false,
    );
  }

  // -------------------------------------------------------------------------
  // Stream event handling
  // -------------------------------------------------------------------------

  void _onEvent(T data) {
    if (_disposed) return;
    state = LiveState<T>(data: data, connection: LiveConnectionState.live);
  }

  void _onStreamError(Object error, StackTrace stack) {
    if (_disposed) return;
    _breadcrumb('stream error: ${error.runtimeType} — reconnecting');
    _enterReconnecting();
  }

  void _onStreamDone() {
    if (_disposed) return;
    _breadcrumb('stream done — reconnecting');
    _enterReconnecting();
  }

  // -------------------------------------------------------------------------
  // Reconnect / backoff
  // -------------------------------------------------------------------------

  void _enterReconnecting() {
    unawaited(_streamSub?.cancel());
    _streamSub = null;
    // Retain last-known data for the "재연결중" UI hint; consumers gate on
    // isStale to suppress authoritative display.
    state = state.copyWith(connection: LiveConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _retryTimer?.cancel();
    final delay = backoffDuration(_attempt);
    _attempt++;
    _breadcrumb('retry in ${delay.inMilliseconds} ms (attempt: $_attempt)');
    _retryTimer = Timer(delay, _onRetryTimer);
  }

  void _onRetryTimer() {
    _retryTimer = null;
    unawaited(_connect());
  }

  // -------------------------------------------------------------------------
  // Disposal
  // -------------------------------------------------------------------------

  void _dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    unawaited(_streamSub?.cancel());
    _streamSub = null;
    _breadcrumb('disposed');
  }

  void _breadcrumb(String message) =>
      onConnectionBreadcrumb('[LiveSubscription<$T>] $message');
}
