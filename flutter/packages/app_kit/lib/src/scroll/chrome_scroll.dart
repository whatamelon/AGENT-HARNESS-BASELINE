import 'package:app_kit/src/chrome/chrome_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps a scrollable [child] and forwards user scroll direction to the
/// `ChromeController` so the shell hides chrome on scroll-down and reveals it
/// on scroll-up.
///
/// Pass the same [controllerProvider] the shell uses. Listens to
/// [UserScrollNotification] (user-initiated scrolls only, so programmatic
/// jumps don't toggle chrome). Respects reduced-motion: the controller drives a
/// state flag and the shell animates with `Motion` tokens, which honor the
/// platform `disableAnimations` setting via Flutter's implicit animations.
class ChromeScroll extends ConsumerWidget {
  /// Creates a [ChromeScroll].
  const ChromeScroll({
    required this.controllerProvider,
    required this.child,
    super.key,
  });

  /// The chrome controller provider shared with the shell.
  final NotifierProvider<ChromeController, ChromeState> controllerProvider;

  /// The scrollable subtree to observe.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        // Only react to the primary vertical scroll axis.
        if (notification.metrics.axis != Axis.vertical) return false;
        ref
            .read(controllerProvider.notifier)
            .onScroll(notification.direction);
        return false;
      },
      child: child,
    );
  }
}
