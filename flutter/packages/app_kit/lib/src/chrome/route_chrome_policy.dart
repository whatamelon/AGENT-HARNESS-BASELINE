import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:meta/meta.dart';

/// Visual styling hint for the shell app bar.
///
/// `ds`'s `DsAppBar` does not yet expose a style axis; this enum is the
/// forward-looking seam so a policy can request a future appearance without
/// app_kit inventing rendering. The shell ignores it for now (only the title +
/// visibility are wired) and an app's resolver may set it for P3+.
enum DsAppBarStyle {
  /// Default sub-screen app bar appearance.
  standard,

  /// A visually lighter / transparent variant (reserved for later).
  transparent,
}

/// Declarative chrome (app bar + bottom nav) policy for a route.
///
/// One immutable value per logical route, produced by the app-injected
/// resolver. The single `ChromeController` owns the active instance; widgets
/// never construct policies directly during rendering.
@immutable
class RouteChromePolicy {
  /// Creates a chrome policy. All fields default to the common shell case
  /// (both app bar and bottom nav visible, standard styling).
  const RouteChromePolicy({
    this.showAppBar = true,
    this.appBarTitle,
    this.showBottomNav = true,
    this.appBarStyle = DsAppBarStyle.standard,
    this.statusBarStyle,
  });

  /// Whether the shell renders the app bar for this route.
  final bool showAppBar;

  /// Title shown in the app bar (`null` keeps it empty).
  final String? appBarTitle;

  /// Whether the shell renders the bottom navigation for this route. Full
  /// screen detail routes (pushed on the root navigator) set this `false`.
  final bool showBottomNav;

  /// Forward-looking app bar style hint (see [DsAppBarStyle]).
  final DsAppBarStyle? appBarStyle;

  /// Optional status bar overlay style (`null` keeps the platform default).
  final SystemUiOverlayStyle? statusBarStyle;

  /// Returns a copy with the provided overrides.
  RouteChromePolicy copyWith({
    bool? showAppBar,
    String? appBarTitle,
    bool? showBottomNav,
    DsAppBarStyle? appBarStyle,
    SystemUiOverlayStyle? statusBarStyle,
  }) {
    return RouteChromePolicy(
      showAppBar: showAppBar ?? this.showAppBar,
      appBarTitle: appBarTitle ?? this.appBarTitle,
      showBottomNav: showBottomNav ?? this.showBottomNav,
      appBarStyle: appBarStyle ?? this.appBarStyle,
      statusBarStyle: statusBarStyle ?? this.statusBarStyle,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RouteChromePolicy &&
      other.showAppBar == showAppBar &&
      other.appBarTitle == appBarTitle &&
      other.showBottomNav == showBottomNav &&
      other.appBarStyle == appBarStyle &&
      other.statusBarStyle == statusBarStyle;

  @override
  int get hashCode => Object.hash(
        showAppBar,
        appBarTitle,
        showBottomNav,
        appBarStyle,
        statusBarStyle,
      );
}

/// Signature for the app-injected route -> policy resolver.
///
/// Apps own the registry (park != onyu), so the package never hardcodes route
/// titles or chrome rules. Given a router `fullPath`, return the policy. See
/// [defaultChromePolicyResolver] for the package fallback.
typedef ChromePolicyResolver = RouteChromePolicy Function(String fullPath);

/// Package default resolver: every route gets the default [RouteChromePolicy]
/// (app bar + bottom nav visible, standard style). Apps override this to map
/// specific paths (e.g. detail routes -> `showBottomNav: false`).
RouteChromePolicy defaultChromePolicyResolver(String fullPath) =>
    const RouteChromePolicy();
