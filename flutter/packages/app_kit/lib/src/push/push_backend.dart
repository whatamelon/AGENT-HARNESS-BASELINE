/// Thin port interfaces that decouple the push pipeline from FCM and the local
/// notification SDK.
///
/// Mirrors the auth `auth_ports.dart` convention: production wires these to
/// `firebase_messaging` / `flutter_local_notifications` (see `push_wiring.dart`,
/// excluded from unit tests); tests supply hand-written fakes (no
/// `mockito`/`mocktail`). Nothing here imports an SDK type — the harness keeps
/// the boundary one-way and the testable logic SDK-free.
library;

import 'package:meta/meta.dart';

/// SDK-neutral push message (an FCM `RemoteMessage` mapped to harness types).
///
/// Carries only what the pipeline needs: the opaque [data] map (where the
/// trusted-but-still-whitelisted `route` lives), the optional display [title]/
/// [body], and a [messageId] for de-duplication/logging. Never carries a raw
/// SDK object so the service layer stays testable.
@immutable
class PushMessage {
  /// Creates a [PushMessage].
  const PushMessage({
    this.data = const <String, String>{},
    this.title,
    this.body,
    this.messageId,
  });

  /// Opaque data payload. Identifiers only — never sensitive content in clear
  /// text (the body is fetched after auth; see `push_service.dart`).
  final Map<String, String> data;

  /// Notification title for foreground display, if any.
  final String? title;

  /// Notification body for foreground display, if any.
  final String? body;

  /// Provider message id (for logging/de-dup), if any.
  final String? messageId;

  /// The inbound route the message wants to open, read from [data]'s `route`
  /// key. Untrusted — must pass the §H-3 whitelist before navigation.
  String? get route => data['route'];

  /// Server-trusted referral code from [data], if present.
  String? get referralCode => data['referral_code'];
}

/// Coarse push permission outcome (SDK-neutral).
enum PushPermission {
  /// User granted notifications.
  authorized,

  /// Provisional (iOS quiet) authorization.
  provisional,

  /// User denied notifications.
  denied,

  /// Not yet determined.
  notDetermined,
}

/// Port over the subset of FCM the pipeline uses.
///
/// Production: `FirebasePushBackend` (wraps `FirebaseMessaging.instance`).
/// Tests: a fake with controllable streams and a canned token.
abstract class PushBackend {
  /// Requests OS notification permission and returns the coarse outcome.
  Future<PushPermission> requestPermission();

  /// The current device push token, or `null` if unavailable.
  Future<String?> getToken();

  /// Emits whenever the device token rotates.
  Stream<String> get onTokenRefresh;

  /// Emits foreground messages (app in view).
  Stream<PushMessage> get onForegroundMessage;

  /// The message that launched the app from a terminated state, or `null`.
  Future<PushMessage?> getInitialMessage();

  /// Emits when a background notification is tapped and opens the app.
  Stream<PushMessage> get onMessageOpenedApp;
}

/// Port over the local-notification surface used to render foreground pushes.
///
/// Production: `LocalNotifications` (wraps `flutter_local_notifications`).
/// Tests: a fake recording `show` calls and driving the tap callback.
abstract class LocalNotificationPort {
  /// Initializes the channel/categories. [onTapPayload] receives the payload
  /// string of a tapped notification (the route, per §H-3).
  Future<void> initialize({
    required void Function(String? payload) onTapPayload,
  });

  /// Displays a notification carrying [payload] (used as the tap route).
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
  });
}
