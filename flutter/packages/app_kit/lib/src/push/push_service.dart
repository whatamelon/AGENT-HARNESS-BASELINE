/// Push orchestration — SDK-free, fully unit-testable.
///
/// Wires the [PushBackend] (FCM port) and [LocalNotificationPort] together
/// with the §H-3 [RouteWhitelist]:
/// - foreground message  -> render via local notifications
/// - notification tap     -> resolve payload route through the whitelist, then
///                           navigate via the injected `onNavigate` sink
/// - background/terminated launch tap -> same whitelisted navigation
///
/// The OS permission request is gated behind a value-first **pre-prompt seam**
/// ([PrePromptGate]): the app shows a Korean value-explanation sheet (당근식)
/// BEFORE the OS dialog; only on user opt-in do we call the backend. The
/// widget is app-provided — this service only owns the control flow.
library;

import 'dart:async';

import 'package:app_kit/src/deeplink/route_whitelist.dart';
import 'package:app_kit/src/push/push_backend.dart';
import 'package:core/core.dart' as core;

/// Decides whether to show the OS permission dialog now.
///
/// The app implements this to render a value-first pre-prompt sheet and return
/// `true` only when the user opts in. Returning `false` defers the OS prompt
/// (no dialog shown), avoiding a cold permission ask.
typedef PrePromptGate = Future<bool> Function();

/// Navigation sink for a resolved (whitelisted) route. The app binds this to
/// its router (`context.go` / `GoRouter.go`).
typedef NavigateToRoute = void Function(ResolvedRoute route);

/// Foreground-display gate: returns `false` to suppress a local notification
/// for a given message (e.g. the user is already on the relevant screen).
/// Defaults to always-show when not provided.
typedef ForegroundDisplayGate = bool Function(PushMessage message);

/// Owns the push runtime control flow.
class PushService {
  /// Creates a [PushService].
  PushService({
    required PushBackend backend,
    required LocalNotificationPort localNotifications,
    required RouteWhitelist whitelist,
    required NavigateToRoute onNavigate,
    ForegroundDisplayGate? shouldDisplayForeground,
    core.AppLogger logger = const core.AppLogger(name: 'push'),
  })  : _backend = backend,
        _local = localNotifications,
        _whitelist = whitelist,
        _onNavigate = onNavigate,
        _shouldDisplayForeground = shouldDisplayForeground ?? _always,
        _logger = logger;

  final PushBackend _backend;
  final LocalNotificationPort _local;
  final RouteWhitelist _whitelist;
  final NavigateToRoute _onNavigate;
  final ForegroundDisplayGate _shouldDisplayForeground;
  final core.AppLogger _logger;

  final List<StreamSubscription<void>> _subs = <StreamSubscription<void>>[];
  int _localNotificationId = 0;

  static bool _always(PushMessage _) => true;

  /// Initializes local notifications and subscribes to foreground messages and
  /// background-tap opens. Call once after the router is ready. Does NOT
  /// request OS permission (that is gated by [maybeRequestPermission]).
  Future<void> start() async {
    await _local.initialize(onTapPayload: _onLocalTap);

    _subs
      ..add(_backend.onForegroundMessage.listen(_onForegroundMessage))
      ..add(_backend.onMessageOpenedApp.listen(_onMessageOpened));
  }

  /// Value-first permission flow: runs the app's [gate] (pre-prompt sheet);
  /// only if it returns `true` does the OS dialog appear. Returns the resulting
  /// [PushPermission] (or [PushPermission.notDetermined] when the user declined
  /// the pre-prompt, leaving the OS prompt unshown).
  Future<PushPermission> maybeRequestPermission(PrePromptGate gate) async {
    final optedIn = await gate();
    if (!optedIn) {
      _logger.info('push pre-prompt declined; OS dialog deferred');
      return PushPermission.notDetermined;
    }
    final result = await _backend.requestPermission();
    _logger.info('push permission result=${result.name}');
    return result;
  }

  /// Handles the cold-start launch message (terminated -> tap). Resolves
  /// through the whitelist and navigates. Safe to call once on startup.
  Future<void> handleInitialMessage() async {
    final message = await _backend.getInitialMessage();
    if (message == null) return;
    _navigateFromMessage(message, source: 'initial');
  }

  void _onForegroundMessage(PushMessage message) {
    if (!_shouldDisplayForeground(message)) return;
    // §8-A: only identifiers travel in the payload; the route is whitelisted on
    // tap, never trusted blindly. Body text shown here comes from the FCM
    // `notification` block (already user-facing), not from sensitive data.
    final resolved = _whitelist.resolvePath(
      message.route,
      referralCode: message.referralCode,
    );
    unawaited(
      _local.show(
        id: _nextId(),
        title: message.title,
        body: message.body,
        payload: _encodePayload(resolved),
      ),
    );
  }

  void _onMessageOpened(PushMessage message) =>
      _navigateFromMessage(message, source: 'opened');

  void _navigateFromMessage(PushMessage message, {required String source}) {
    final resolved = _whitelist.resolvePath(
      message.route,
      referralCode: message.referralCode,
    );
    if (!resolved.wasAllowed) {
      _logger.warn('push tap route rejected ($source) -> home fallback');
    }
    _onNavigate(resolved);
  }

  /// Local-notification tap: the payload is the encoded resolved route. Re-run
  /// it through the whitelist defensively (payloads must never bypass §H-3),
  /// then navigate.
  void _onLocalTap(String? payload) {
    final route = _decodePayloadRoute(payload);
    final resolved = _whitelist.resolvePath(route);
    if (!resolved.wasAllowed) {
      _logger.warn('local-noti tap route rejected -> home fallback');
    }
    _onNavigate(resolved);
  }

  int _nextId() => _localNotificationId++;

  // Payload is just the trusted route path (referral codes are NOT
  // round-tripped through the local notification — they are only honored on the
  // direct server-resolve path, never re-derived from a tapped notification).
  static String _encodePayload(ResolvedRoute route) => route.route;

  static String? _decodePayloadRoute(String? payload) =>
      (payload == null || payload.isEmpty) ? null : payload;

  /// Cancels all stream subscriptions.
  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }
}
