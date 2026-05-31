import 'package:app_kit/app_kit.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A scrollable branch screen with a counter so we can assert that tab state
/// (in-memory state) survives a tab swap via [StatefulShellRoute].
class _CounterScreen extends StatefulWidget {
  const _CounterScreen({required this.title, required this.chromeProvider});
  final String title;
  final NotifierProvider<ChromeController, ChromeState> chromeProvider;

  @override
  State<_CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<_CounterScreen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return ChromeScroll(
      controllerProvider: widget.chromeProvider,
      child: ListView(
        children: [
          Text(
            '${widget.title} count: $_count',
            key: Key('count-${widget.title}'),
          ),
          DsButton(
            key: Key('inc-${widget.title}'),
            label: '증가',
            onPressed: () => setState(() => _count++),
          ),
          for (var i = 0; i < 40; i++)
            SizedBox(height: 60, child: Text('${widget.title} row $i')),
        ],
      ),
    );
  }
}

RouteChromePolicy _resolver(String path) {
  if (path.startsWith('/home')) {
    return const RouteChromePolicy(appBarTitle: '홈');
  }
  return const RouteChromePolicy(appBarTitle: '디자인');
}

/// Builds the shell harness; the router is created inside a [Provider] so
/// [buildAppRouter] receives a genuine [Ref].
Widget _harness(
  NotifierProvider<ChromeController, ChromeState> chromeProvider,
) {
  final branches = <ShellBranch>[
    ShellBranch(
      path: '/home',
      navItem: const DsNavItem(icon: Icons.home_outlined, label: '홈'),
      builder: (context) =>
          _CounterScreen(title: '홈', chromeProvider: chromeProvider),
    ),
    ShellBranch(
      path: '/design',
      navItem: const DsNavItem(icon: Icons.palette_outlined, label: '디자인'),
      builder: (context) =>
          _CounterScreen(title: '디자인', chromeProvider: chromeProvider),
    ),
  ];

  final routerProvider = Provider<GoRouter>((ref) {
    return buildAppRouter(
      ref: ref,
      branches: branches,
      chromeProvider: chromeProvider,
    );
  });

  return ProviderScope(
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(
        theme: buildTheme(),
        routerConfig: ref.watch(routerProvider),
      ),
    ),
  );
}

void main() {
  testWidgets('renders shell with app bar + bottom nav tabs', (tester) async {
    final provider = chromeControllerProvider(_resolver);
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    expect(find.byType(DsBottomNav), findsOneWidget);
    expect(find.byType(DsAppBar), findsOneWidget);
    expect(find.text('홈'), findsWidgets);
    expect(find.text('디자인'), findsWidgets);
  });

  testWidgets('tab state (counter) is preserved across tab swaps',
      (tester) async {
    final provider = chromeControllerProvider(_resolver);
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inc-홈')));
    await tester.tap(find.byKey(const Key('inc-홈')));
    await tester.pump();
    expect(find.text('홈 count: 2'), findsOneWidget);

    await tester.tap(find.text('디자인').last);
    await tester.pumpAndSettle();
    expect(find.text('디자인 count: 0'), findsOneWidget);

    await tester.tap(find.text('홈').last);
    await tester.pumpAndSettle();
    expect(find.text('홈 count: 2'), findsOneWidget);
  });

  testWidgets('scrolling content down hides chrome (bottom nav collapses)',
      (tester) async {
    final provider = chromeControllerProvider(_resolver);
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DsBottomNav)),
    );
    expect(container.read(provider).visible, isTrue);

    // Drag the list content upward => scroll down => ScrollDirection.reverse.
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(container.read(provider).visible, isFalse);

    // Drag back down => scroll up => reveal.
    await tester.drag(find.byType(ListView).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(container.read(provider).visible, isTrue);
  });

  testWidgets('detail route on root navigator hides the bottom nav',
      (tester) async {
    final rootKey = GlobalKey<NavigatorState>();
    final provider = chromeControllerProvider(_resolver);
    final branches = <ShellBranch>[
      ShellBranch(
        path: '/home',
        navItem: const DsNavItem(icon: Icons.home_outlined, label: '홈'),
        builder: (context) =>
            _CounterScreen(title: '홈', chromeProvider: provider),
      ),
      ShellBranch(
        path: '/design',
        navItem: const DsNavItem(icon: Icons.palette_outlined, label: '디자인'),
        builder: (context) =>
            _CounterScreen(title: '디자인', chromeProvider: provider),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: buildTheme(),
          routerConfig: GoRouter(
            navigatorKey: rootKey,
            initialLocation: '/home',
            routes: [
              StatefulShellRoute.indexedStack(
                builder: (context, state, navigationShell) => AppShell(
                  navigationShell: navigationShell,
                  branches: branches,
                  controllerProvider: provider,
                  fullPath: state.fullPath ?? state.matchedLocation,
                ),
                branches: [
                  for (final b in branches)
                    StatefulShellBranch(
                      routes: [
                        GoRoute(path: b.path, builder: (c, s) => b.builder(c)),
                      ],
                    ),
                ],
              ),
              GoRoute(
                path: '/detail',
                parentNavigatorKey: rootKey,
                builder: (context, state) => const Scaffold(
                  appBar: DsAppBar(title: '상세'),
                  body: Center(child: Text('detail body')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DsBottomNav), findsOneWidget);

    rootKey.currentContext!.go('/detail');
    await tester.pumpAndSettle();

    expect(find.byType(DsBottomNav), findsNothing);
    expect(find.text('detail body'), findsOneWidget);
  });
}
