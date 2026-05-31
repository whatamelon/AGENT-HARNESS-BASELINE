import 'dart:async';

import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend implements PushBackend {
  PushPermission permissionResult = PushPermission.authorized;
  String? token = 'tok-1';
  PushMessage? initialMessage;

  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();
  final _tokenRefresh = StreamController<String>.broadcast();

  bool requestedPermission = false;

  void emitForeground(PushMessage m) => _foreground.add(m);
  void emitOpened(PushMessage m) => _opened.add(m);

  @override
  Future<PushPermission> requestPermission() async {
    requestedPermission = true;
    return permissionResult;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _tokenRefresh.stream;

  @override
  Stream<PushMessage> get onForegroundMessage => _foreground.stream;

  @override
  Future<PushMessage?> getInitialMessage() async => initialMessage;

  @override
  Stream<PushMessage> get onMessageOpenedApp => _opened.stream;

  Future<void> dispose() async {
    await _foreground.close();
    await _opened.close();
    await _tokenRefresh.close();
  }
}

class _RecordingLocalNotifications implements LocalNotificationPort {
  void Function(String? payload)? tapCallback;
  final List<({String? title, String? body, String? payload})> shown = [];

  @override
  Future<void> initialize({
    required void Function(String? payload) onTapPayload,
  }) async {
    tapCallback = onTapPayload;
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
  }) async {
    shown.add((title: title, body: body, payload: payload));
  }
}

RouteWhitelist _whitelist() => RouteWhitelist(
      allowedPrefixes: const {'/park/contract', '/onyu/guide'},
      homeFallback: '/park',
    );

void main() {
  group('PushService', () {
    late _FakeBackend backend;
    late _RecordingLocalNotifications local;
    late List<ResolvedRoute> navigations;
    late PushService service;

    setUp(() {
      backend = _FakeBackend();
      local = _RecordingLocalNotifications();
      navigations = [];
      service = PushService(
        backend: backend,
        localNotifications: local,
        whitelist: _whitelist(),
        onNavigate: navigations.add,
      );
    });

    tearDown(() async {
      await service.dispose();
      await backend.dispose();
    });

    test('foreground message renders a local notification', () async {
      await service.start();
      backend.emitForeground(
        const PushMessage(
          title: '예약 확인',
          body: '내일 방문 예약이 있습니다',
          data: {'route': '/park/contract/9'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(local.shown, hasLength(1));
      expect(local.shown.single.title, '예약 확인');
      expect(local.shown.single.payload, '/park/contract/9');
    });

    test('background-tap (onMessageOpenedApp) navigates a whitelisted route',
        () async {
      await service.start();
      backend.emitOpened(
        const PushMessage(data: {'route': '/onyu/guide/step2'}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(navigations, hasLength(1));
      expect(navigations.single.route, '/onyu/guide/step2');
      expect(navigations.single.wasAllowed, isTrue);
    });

    test('background-tap on a disallowed route falls back to home (§H-3)',
        () async {
      await service.start();
      backend.emitOpened(
        const PushMessage(data: {'route': '/admin/secret'}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(navigations.single.route, '/park');
      expect(navigations.single.wasAllowed, isFalse);
    });

    test('local-notification tap routes the payload through the whitelist',
        () async {
      await service.start();
      // Simulate the OS delivering a tap on a previously shown notification.
      local.tapCallback!('/park/contract/42');
      expect(navigations.single.route, '/park/contract/42');

      // A tampered payload pointing at a privileged route is rejected.
      navigations.clear();
      local.tapCallback!('/admin/root');
      expect(navigations.single.route, '/park');
      expect(navigations.single.wasAllowed, isFalse);
    });

    test('cold-start initial message navigates through the whitelist',
        () async {
      backend.initialMessage =
          const PushMessage(data: {'route': '/park/contract/seed'});
      await service.start();
      await service.handleInitialMessage();

      expect(navigations.single.route, '/park/contract/seed');
    });

    test('pre-prompt opt-in triggers the OS permission request', () async {
      final result =
          await service.maybeRequestPermission(() async => true);
      expect(backend.requestedPermission, isTrue);
      expect(result, PushPermission.authorized);
    });

    test('pre-prompt decline defers the OS dialog (no request)', () async {
      final result =
          await service.maybeRequestPermission(() async => false);
      expect(backend.requestedPermission, isFalse);
      expect(result, PushPermission.notDetermined);
    });

    test('foreground display gate can suppress a notification', () async {
      service = PushService(
        backend: backend,
        localNotifications: local,
        whitelist: _whitelist(),
        onNavigate: navigations.add,
        shouldDisplayForeground: (m) => false,
      );
      await service.start();
      backend.emitForeground(
        const PushMessage(data: {'route': '/park/contract/1'}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(local.shown, isEmpty);
    });
  });
}
