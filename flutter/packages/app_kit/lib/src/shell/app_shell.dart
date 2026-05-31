import 'package:app_kit/src/chrome/chrome_controller.dart';
import 'package:app_kit/src/shell/shell_branch.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The persistent app shell: [DsAppBar] (top), the active branch body, and
/// [DsBottomNav] (bottom). Chrome visibility is driven entirely by the single
/// [ChromeController] — both the route policy (showAppBar / showBottomNav) and
/// the scroll show/hide flag come from [ChromeState].
///
/// The shell is rendered by `StatefulShellRoute.indexedStack`'s builder, which
/// hands it [navigationShell] (tab index + branch state) and the active
/// [fullPath]. The shell notifies the controller of the route after the frame
/// (never during build) so go_router and Riverpod stay decoupled.
class AppShell extends ConsumerStatefulWidget {
  /// Creates an [AppShell].
  const AppShell({
    required this.navigationShell,
    required this.branches,
    required this.controllerProvider,
    required this.fullPath,
    super.key,
  });

  /// The shell navigation state from `StatefulShellRoute.indexedStack`.
  final StatefulNavigationShell navigationShell;

  /// Tab branch definitions (drive the bottom nav items).
  final List<ShellBranch> branches;

  /// The chrome controller provider (shared with `ChromeScroll`).
  final NotifierProvider<ChromeController, ChromeState> controllerProvider;

  /// The active router full path, used to resolve the chrome policy.
  final String fullPath;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    _notifyRoute();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullPath != widget.fullPath) _notifyRoute();
  }

  /// Push the current route into the controller after the current frame, so we
  /// never mutate provider state synchronously during the router/shell build
  /// (which would trigger a build-during-build assertion).
  void _notifyRoute() {
    final path = widget.fullPath;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(widget.controllerProvider.notifier).onRouteChanged(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final chrome = ref.watch(widget.controllerProvider);
    final policy = chrome.policy;

    final showAppBar = policy.showAppBar && chrome.visible;
    final showBottomNav = policy.showBottomNav && chrome.visible;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _ChromeReveal(
            visible: showAppBar,
            axisAlignment: -1,
            child: DsAppBar(
              title: policy.appBarTitle ?? '',
              // Tab roots have no back button (global rule); detail routes are
              // pushed on the root navigator and own their own DsAppBar.
            ),
          ),
          Expanded(child: widget.navigationShell),
          _ChromeReveal(
            visible: showBottomNav,
            axisAlignment: 1,
            child: DsBottomNav(
              items: [for (final b in widget.branches) b.navItem],
              selectedIndex: widget.navigationShell.currentIndex,
              onTap: _onTabTap,
            ),
          ),
        ],
      ),
    );
  }

  void _onTabTap(int index) {
    // `initialLocation: true` only when re-tapping the active tab returns it to
    // its branch root; matches the standard go_router shell idiom.
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}

/// Animates chrome in/out by collapsing its height with the [Motion] tokens.
/// Honors reduced-motion automatically (Flutter shortens implicit animations
/// when the platform requests `disableAnimations`).
class _ChromeReveal extends StatelessWidget {
  const _ChromeReveal({
    required this.visible,
    required this.child,
    required this.axisAlignment,
  });

  final bool visible;
  final Widget child;
  final double axisAlignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.baseDuration,
      curve: Motion.baseCurve,
      alignment: axisAlignment < 0
          ? Alignment.bottomCenter
          : Alignment.topCenter,
      child: ClipRect(
        child: Align(
          alignment: axisAlignment < 0
              ? Alignment.bottomCenter
              : Alignment.topCenter,
          heightFactor: visible ? 1 : 0,
          child: child,
        ),
      ),
    );
  }
}
