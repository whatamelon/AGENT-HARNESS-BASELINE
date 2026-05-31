import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reference_app/ds_showcase.dart';
import 'package:reference_app/screens/detail_screen.dart';
import 'package:reference_app/screens/home_screen.dart';
import 'package:reference_app/screens/settings_screen.dart';

/// Route paths for the reference app's three tab branches + the demo detail
/// route (pushed full-screen on the root navigator).
abstract final class AppRoutes {
  static const String home = '/home';
  static const String design = '/design';
  static const String settings = '/settings';
  static const String detail = '/detail';
}

/// App-owned route -> chrome policy registry. (Real apps like park/onyu own
/// their own mapping; this is the reference one.) Tab roots show app bar +
/// bottom nav; the full-screen detail route hides the bottom nav.
RouteChromePolicy referenceChromeResolver(String fullPath) {
  switch (fullPath) {
    case AppRoutes.home:
      return const RouteChromePolicy(appBarTitle: '홈');
    case AppRoutes.design:
      return const RouteChromePolicy(appBarTitle: '디자인');
    case AppRoutes.settings:
      return const RouteChromePolicy(appBarTitle: '설정');
    case AppRoutes.detail:
      return const RouteChromePolicy(
        appBarTitle: '상세',
        showBottomNav: false,
      );
    default:
      return const RouteChromePolicy();
  }
}

/// Shared chrome controller provider bound to the app's resolver. The shell and
/// every [ChromeScroll] read this same provider.
final NotifierProvider<ChromeController, ChromeState> appChromeProvider =
    chromeControllerProvider(referenceChromeResolver);

/// The three-tab shell branches (Material single icon set, Korean labels).
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
    path: AppRoutes.design,
    navItem: const DsNavItem(
      icon: Icons.palette_outlined,
      selectedIcon: Icons.palette,
      label: '디자인',
    ),
    builder: (context) => const DsShowcasePage(),
  ),
  ShellBranch(
    path: AppRoutes.settings,
    navItem: const DsNavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: '설정',
    ),
    builder: (context) => const SettingsScreen(),
  ),
];

/// The reference app router. Adds a full-screen `/detail` route on the root
/// navigator (so the bottom nav disappears) on top of the shell branches.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  return buildAppRouter(
    ref: ref,
    branches: appBranches,
    chromeProvider: appChromeProvider,
    restorationScopeId: 'app',
    extraRoutes: (rootKey) => [
      GoRoute(
        path: AppRoutes.detail,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const DetailScreen(),
      ),
    ],
  );
});

/// Root widget. Wires the ANDS [buildTheme] + go_router shell. Pinned to light
/// mode ([ThemeMode.light]).
class ReferenceApp extends ConsumerWidget {
  const ReferenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = AppConfig.current;
    return MaterialApp.router(
      title: 'Harness Reference (${flavor.label})',
      debugShowCheckedModeBanner: false,
      // Matches the router's restorationScopeId (§3.2).
      restorationScopeId: 'app',
      theme: buildTheme(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
