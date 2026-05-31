import 'package:ds/ds.dart' show DsNavItem;
import 'package:flutter/widgets.dart';

/// One tab branch of the `StatefulShellRoute`: its route subtree path, the
/// widget builder for the branch root, and the [DsNavItem] shown in the
/// bottom nav.
///
/// Apps declare a list of these and pass them to `buildAppRouter` / `AppShell`;
/// the package itself ships no branches (park != onyu).
@immutable
class ShellBranch {
  /// Creates a [ShellBranch].
  const ShellBranch({
    required this.path,
    required this.navItem,
    required this.builder,
  });

  /// Route path for this branch root (e.g. `/home`). Must start with `/`.
  final String path;

  /// The bottom-nav destination for this branch.
  final DsNavItem navItem;

  /// Builds the branch root screen.
  final WidgetBuilder builder;
}
