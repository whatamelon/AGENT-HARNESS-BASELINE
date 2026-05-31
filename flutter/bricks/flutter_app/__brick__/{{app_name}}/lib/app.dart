import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:{{app_name}}/features/screens.dart';

/// Route paths for {{app_title}}'s tab branches.
abstract final class AppRoutes {
{{#tabs}}
  static const String {{key.camelCase()}} = '/{{key}}';
{{/tabs}}
}

/// App-owned route -> chrome policy registry. Tab roots show the app bar +
/// bottom nav; full-screen sub-routes (pushed on the root navigator) own their
/// own [DsAppBar] with a back affordance.
RouteChromePolicy {{app_name.camelCase()}}ChromeResolver(String fullPath) {
  switch (fullPath) {
{{#tabs}}
    case AppRoutes.{{key.camelCase()}}:
      return const RouteChromePolicy(appBarTitle: '{{label}}');
{{/tabs}}
    default:
      return const RouteChromePolicy();
  }
}

/// Shared chrome controller provider bound to the app's resolver. The shell and
/// every [ChromeScroll] read this same provider.
final NotifierProvider<ChromeController, ChromeState> appChromeProvider =
    chromeControllerProvider({{app_name.camelCase()}}ChromeResolver);

/// §H-3 route whitelist: untrusted inbound deep links / push payloads are mapped
/// through this allow-set before navigation. Only tab roots are allowed here;
/// extend the prefixes as real sub-routes ship.
final RouteWhitelist appRouteWhitelist = RouteWhitelist(
  allowedPrefixes: const <String>{
{{#tabs}}
    AppRoutes.{{key.camelCase()}},
{{/tabs}}
  },
  homeFallback: AppRoutes.{{home_key.camelCase()}},
);

/// The tab shell branches (Material single icon set, Korean labels).
final List<ShellBranch> appBranches = <ShellBranch>[
{{#tabs}}
  ShellBranch(
    path: AppRoutes.{{key.camelCase()}},
    navItem: const DsNavItem(
      icon: Icons.{{icon}}_outlined,
      selectedIcon: Icons.{{icon}},
      label: '{{label}}',
    ),
    builder: (context) => const {{key.pascalCase()}}Screen(),
  ),
{{/tabs}}
];

/// The app router (StatefulShellRoute over [appBranches]).
///
/// `restorationScopeId: 'app'` enables go_router cross-session state restoration
/// (§3.2) so list filters/scroll-anchor and the active tab survive a process
/// death + restart. It must match the [MaterialApp.router] `restorationScopeId`.
///
/// Selective auth gate seam (§5.5): pass `routePolicy:` to gate routes. This
/// brick leaves it unset (no app-wide policy invented here). Apps supply their
/// own, e.g.:
/// ```dart
/// routePolicy: RouteAuthPolicy(
///   // park: protected by default (memorial-park contractor app)
///   levelFor: (p) => RouteAuthLevel.protected,
///   // onyu: guest-first — emergency/funeral-guide/notices stay public
///   //   levelFor: (p) => _publicOnyuPrefixes.any(p.startsWith)
///   //       ? RouteAuthLevel.public : RouteAuthLevel.protected,
/// ),
/// ```
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  return buildAppRouter(
    ref: ref,
    branches: appBranches,
    chromeProvider: appChromeProvider,
    restorationScopeId: 'app',
  );
});

/// Root widget. Wires the ANDS [buildTheme] (brand seed {{brand_seed}}) +
/// go_router shell. Pinned to light mode ([ThemeMode.light]).
class {{app_name.pascalCase()}}App extends ConsumerWidget {
  const {{app_name.pascalCase()}}App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = AppConfig.current;
    return MaterialApp.router(
      title: '{{app_title}} (${flavor.label})',
      debugShowCheckedModeBanner: false,
      // Matches the router's restorationScopeId so cross-session restoration is
      // actually enabled end-to-end (§3.2).
      restorationScopeId: 'app',
      theme: buildTheme(seed: const Color({{brand_seed}})),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
