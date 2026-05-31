import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:example_app/features/screens.dart';

/// Route paths for 예시앱's tab branches.
abstract final class AppRoutes {

  static const String home = '/home';

  static const String services = '/services';

  static const String mypage = '/mypage';

}

/// App-owned route -> chrome policy registry. Tab roots show the app bar +
/// bottom nav; full-screen sub-routes (pushed on the root navigator) own their
/// own [DsAppBar] with a back affordance.
RouteChromePolicy exampleAppChromeResolver(String fullPath) {
  switch (fullPath) {

    case AppRoutes.home:
      return const RouteChromePolicy(appBarTitle: '홈');

    case AppRoutes.services:
      return const RouteChromePolicy(appBarTitle: '서비스');

    case AppRoutes.mypage:
      return const RouteChromePolicy(appBarTitle: '마이');

    default:
      return const RouteChromePolicy();
  }
}

/// Shared chrome controller provider bound to the app's resolver. The shell and
/// every [ChromeScroll] read this same provider.
final NotifierProvider<ChromeController, ChromeState> appChromeProvider =
    chromeControllerProvider(exampleAppChromeResolver);

/// §H-3 route whitelist: untrusted inbound deep links / push payloads are mapped
/// through this allow-set before navigation. Only tab roots are allowed here;
/// extend the prefixes as real sub-routes ship.
final RouteWhitelist appRouteWhitelist = RouteWhitelist(
  allowedPrefixes: const <String>{

    AppRoutes.home,

    AppRoutes.services,

    AppRoutes.mypage,

  },
  homeFallback: AppRoutes.home,
);

/// The tab shell branches (Material single icon set, Korean labels).
final List<ShellBranch> appBranches = <ShellBranch>[

  ShellBranch(
    path: AppRoutes.home,
    navItem: const DsNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '홈',
    ),
    builder: (context) => const HomeScreen(),
  ),

  ShellBranch(
    path: AppRoutes.services,
    navItem: const DsNavItem(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view,
      label: '서비스',
    ),
    builder: (context) => const ServicesScreen(),
  ),

  ShellBranch(
    path: AppRoutes.mypage,
    navItem: const DsNavItem(
      icon: Icons.person_outlined,
      selectedIcon: Icons.person,
      label: '마이',
    ),
    builder: (context) => const MypageScreen(),
  ),

];

/// The app router (StatefulShellRoute over [appBranches]).
///
/// `restorationScopeId: 'app'` enables go_router cross-session state
/// restoration (§3.2); it must match the [MaterialApp.router]
/// `restorationScopeId`. A `routePolicy:` seam is left unset (apps supply it).
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  return buildAppRouter(
    ref: ref,
    branches: appBranches,
    chromeProvider: appChromeProvider,
    restorationScopeId: 'app',
  );
});

/// Root widget. Wires the ANDS [buildTheme] (brand seed 0xFF3B82F6) +
/// go_router shell. Pinned to light mode ([ThemeMode.light]).
class ExampleAppApp extends ConsumerWidget {
  const ExampleAppApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = AppConfig.current;
    return MaterialApp.router(
      title: '예시앱 (${flavor.label})',
      debugShowCheckedModeBanner: false,
      // Matches the router's restorationScopeId (§3.2).
      restorationScopeId: 'app',
      theme: buildTheme(seed: const Color(0xFF3B82F6)),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
