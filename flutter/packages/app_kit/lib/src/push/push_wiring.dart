/// Production push wiring — binds the ports to `firebase_messaging` and
/// Supabase. SDK-touching; excluded from unit tests (tests use port fakes).
///
/// Firebase initialization is an **app-injected options seam**: the app passes
/// its own `FirebaseOptions` (from its generated `firebase_options.dart`) to
/// [initFirebaseMessaging]. This package never embeds project config, keeping
/// it app-agnostic and secret-free (§8-A).
library;

// The `@pragma('vm:entry-point')` background handler makes the analyzer treat
// this library as having an entry point; the public wiring symbols are reached
// via the `app_kit` barrel + app entrypoint, not from a `main` here.
// ignore_for_file: unreachable_from_main

import 'package:app_kit/src/push/device_token_registrar.dart';
import 'package:app_kit/src/push/push_backend.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Background message handler. MUST be a top-level (or static) function and
/// annotated `@pragma('vm:entry-point')` so it survives tree-shaking and runs
/// in the background isolate. The app registers it via
/// `FirebaseMessaging.onBackgroundMessage` in its entrypoint, after
/// `Firebase.initializeApp(options: <app firebase_options>)`.
///
/// Kept intentionally minimal: data-only handling/analytics may go here. Do NOT
/// navigate from here (no UI isolate); navigation happens on tap via
/// `onMessageOpenedApp`/`getInitialMessage` in `PushService`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The app injects Firebase options in its entrypoint; the background isolate
  // re-initializes with the same app-provided options before any Firebase use.
  // No-op by default (display handled by the OS for notification messages).
}

/// Initializes Firebase Core with **app-provided** [options].
///
/// The app supplies `DefaultFirebaseOptions.currentPlatform` from its generated
/// `firebase_options.dart`. Passing `null` defers to native config files
/// (google-services.json / GoogleService-Info.plist) when present.
Future<void> initFirebaseMessaging({FirebaseOptions? options}) async {
  await Firebase.initializeApp(options: options);
}

/// [PushBackend] over `FirebaseMessaging.instance`.
class FirebasePushBackend implements PushBackend {
  /// Creates a [FirebasePushBackend].
  FirebasePushBackend([FirebaseMessaging? messaging])
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<PushPermission> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => PushPermission.authorized,
      AuthorizationStatus.provisional => PushPermission.provisional,
      AuthorizationStatus.denied => PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
    };
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(_toPushMessage);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toPushMessage(message);
  }

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_toPushMessage);

  static PushMessage _toPushMessage(RemoteMessage message) => PushMessage(
        data: message.data.map(
          (key, value) => MapEntry(key, '$value'),
        ),
        title: message.notification?.title,
        body: message.notification?.body,
        messageId: message.messageId,
      );
}

/// Supabase-backed [DeviceTokenStore].
///
/// Table and column names are configurable so apps with different schemas reuse
/// this (yipark maps to `member_devices` with `member_id`/`expo_push_token`).
/// Defaults follow the §M3 contract: `device_tokens(user_id, token, platform)`.
class SupabaseDeviceTokenStore implements DeviceTokenStore {
  /// Creates a [SupabaseDeviceTokenStore].
  SupabaseDeviceTokenStore(
    this._client, {
    this.table = 'device_tokens',
    this.userIdColumn = 'user_id',
    this.tokenColumn = 'token',
    this.platformColumn = 'platform',
    Map<String, Object?> extraColumns = const <String, Object?>{},
  }) : _extraColumns = extraColumns;

  final sb.SupabaseClient _client;

  /// Target table name.
  final String table;

  /// Column holding the owning user id.
  final String userIdColumn;

  /// Column holding the device token.
  final String tokenColumn;

  /// Column holding the platform string.
  final String platformColumn;

  /// Constant columns merged into every upsert (e.g. `organization_id`).
  final Map<String, Object?> _extraColumns;

  @override
  Future<void> upsert({
    required String userId,
    required String token,
    required String platform,
  }) async {
    await _client.from(table).upsert(
      <String, Object?>{
        userIdColumn: userId,
        tokenColumn: token,
        platformColumn: platform,
        ..._extraColumns,
      },
      onConflict: '$userIdColumn,$tokenColumn',
    );
  }

  @override
  Future<void> deleteToken({required String userId, String? token}) async {
    final query = _client.from(table).delete().eq(userIdColumn, userId);
    if (token != null && token.isNotEmpty) {
      await query.eq(tokenColumn, token);
    } else {
      await query;
    }
  }
}
