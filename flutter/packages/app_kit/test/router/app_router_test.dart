import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Auth controller that emits a fixed [AuthState] for redirect tests.
///
/// Extends [AuthController] so it can override [authStateProvider] (which is
/// typed `NotifierProvider<AuthController, AuthState>`).
class _FixedAuth extends AuthController {
  _FixedAuth(this._value);
  final AuthState _value;
  @override
  AuthState build() => _value;
}

RouteChromePolicy _chrome(String path) => const RouteChromePolicy();

RouteAuthLevel _levelFor(String path) {
  if (path.startsWith('/public')) return RouteAuthLevel.public;
  if (path.startsWith('/secret')) return RouteAuthLevel.protected;
  return RouteAuthLevel.public;
}

/// Pumps the router with [auth] overriding [authStateProvider] and an optional
/// [policy], starting at [initialLocation]. Returns the GoRouter so tests can
/// read the settled location.
Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required AuthState auth,
  RouteAuthPolicy? policy,
  String initialLocation = '/home',
}) async {
  final chromeProvider = chromeControllerProvider(_chrome);
  final branches = <ShellBranch>[
    ShellBranch(
      path: '/home',
      navItem: const DsNavItem(icon: Icons.home_outlined, label: '홈'),
      builder: (context) => const Text('home screen'),
    ),
    ShellBranch(
      path: '/secret',
      navItem: const DsNavItem(icon: Icons.lock_outline, label: '보호'),
      builder: (context) => const Text('secret screen'),
    ),
    ShellBranch(
      path: '/public',
      navItem: const DsNavItem(icon: Icons.public, label: '공개'),
      builder: (context) => const Text('public screen'),
    ),
  ];

  final builtRouters = <GoRouter>[];
  final routerProvider = Provider<GoRouter>((ref) {
    final router = buildAppRouter(
      ref: ref,
      branches: branches,
      chromeProvider: chromeProvider,
      loginPath: '/login',
      routePolicy: policy,
      extraRoutes: (rootKey) => [
        GoRoute(
          path: '/login',
          parentNavigatorKey: rootKey,
          builder: (c, s) => const Scaffold(body: Text('login screen')),
        ),
        GoRoute(
          path: '/splash',
          parentNavigatorKey: rootKey,
          builder: (c, s) => const SplashScreen(),
        ),
      ],
    );
    builtRouters.add(router);
    return router;
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authStateProvider.overrideWith(() => _FixedAuth(auth))],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: buildTheme(),
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ),
  );

  // Navigate after the ProviderScope (and its auth override) is fully mounted,
  // so the redirect reads the overridden auth state — not the root default.
  final router = builtRouters.single..go(initialLocation);
  // Bounded pumps (not pumpAndSettle): SplashScreen's progress indicator
  // animates forever, so settling would time out on the splash path.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  const policy = RouteAuthPolicy(levelFor: _levelFor);

  testWidgets('no policy: permissive (unauthenticated reaches a branch)',
      (tester) async {
    final router = await _pumpRouter(
      tester,
      auth: AuthState.unauthenticated,
      initialLocation: '/secret',
    );
    expect(_location(router), '/secret');
    expect(find.text('secret screen'), findsOneWidget);
  });

  testWidgets('unknown auth holds on splash', (tester) async {
    final router = await _pumpRouter(
      tester,
      auth: AuthState.unknown,
      policy: policy,
      initialLocation: '/secret',
    );
    expect(_location(router), '/splash');
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('public route passes for unauthenticated', (tester) async {
    final router = await _pumpRouter(
      tester,
      auth: AuthState.unauthenticated,
      policy: policy,
      initialLocation: '/public',
    );
    expect(_location(router), '/public');
    expect(find.text('public screen'), findsOneWidget);
  });

  testWidgets('protected route gates unauthenticated to login?redirect',
      (tester) async {
    final router = await _pumpRouter(
      tester,
      auth: AuthState.unauthenticated,
      policy: policy,
      initialLocation: '/secret',
    );
    expect(_location(router), '/login?redirect=%2Fsecret');
    expect(find.text('login screen'), findsOneWidget);
  });

  testWidgets('authenticated on login decodes redirect', (tester) async {
    final router = await _pumpRouter(
      tester,
      auth: AuthState.authenticated('u1'),
      policy: policy,
      initialLocation: '/login?redirect=%2Fsecret',
    );
    expect(_location(router), '/secret');
    expect(find.text('secret screen'), findsOneWidget);
  });

  testWidgets('authenticated reaches protected route directly', (tester) async {
    final router = await _pumpRouter(
      tester,
      auth: AuthState.authenticated('u1'),
      policy: policy,
      initialLocation: '/secret',
    );
    expect(_location(router), '/secret');
  });
}
