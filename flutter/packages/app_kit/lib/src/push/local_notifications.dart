/// Production [LocalNotificationPort] over `flutter_local_notifications` 21.x.
///
/// SDK-touching wiring — excluded from unit tests (tests fake the port).
/// Renders foreground FCM pushes as OS notifications and routes a tap's payload
/// back to the push pipeline (which re-checks §H-3 before navigating).
library;

import 'package:app_kit/src/push/push_backend.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Default Android channel id/name for app notifications. The app may override
/// via the constructor to match its own channel configuration.
const String kDefaultChannelId = 'app_default';

/// Wraps `FlutterLocalNotificationsPlugin` as a [LocalNotificationPort].
class LocalNotifications implements LocalNotificationPort {
  /// Creates a [LocalNotifications].
  LocalNotifications({
    FlutterLocalNotificationsPlugin? plugin,
    this.androidIcon = '@mipmap/ic_launcher',
    this.channelId = kDefaultChannelId,
    this.channelName = 'Notifications',
    this.channelDescription = 'App notifications',
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Android small-icon drawable/mipmap resource name.
  final String androidIcon;

  /// Android notification channel id.
  final String channelId;

  /// Android notification channel display name.
  final String channelName;

  /// Android notification channel description.
  final String channelDescription;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTapPayload,
  }) async {
    final settings = InitializationSettings(
      android: AndroidInitializationSettings(androidIcon),
      // Permissions are requested via FCM's pre-prompt flow, not here.
      iOS: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) =>
          onTapPayload(response.payload),
    );
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
