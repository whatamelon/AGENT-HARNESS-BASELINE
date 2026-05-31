import 'package:core/core.dart';
import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/haptics/component_haptics.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// Show an ANDS bottom sheet (DESIGN-COMPONENTS §8): rounded top, grabber
/// handle, overlay backdrop (tap to dismiss), and keyboard avoidance.
///
/// Selection UIs should prefer this over a centered modal. Do not stack a
/// modal on top of a sheet (no modal nesting).
Future<T?> showDsBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool isScrollControlled = true,
}) {
  final c = context.c;
  // Light tap haptic as the sheet opens. Best-effort decoration; the modal is
  // shown regardless.
  fireHaptic(context, HapticIntent.light);
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    isScrollControlled: isScrollControlled,
    backgroundColor: c.surface,
    barrierColor: c.overlay,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (sheetContext) => DsBottomSheet(child: builder(sheetContext)),
  );
}

/// The bottom-sheet shell: grabber handle + content, with bottom padding that
/// tracks the keyboard inset so inputs are never covered. Usually obtained via
/// [showDsBottomSheet]; exposed for custom hosts/tests.
class DsBottomSheet extends StatelessWidget {
  const DsBottomSheet({required this.child, this.title, super.key});

  final Widget child;

  /// Optional sheet title; rendered as a leading row above [child].
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Semantics(
      container: true,
      label: title,
      child: Padding(
        // Keyboard avoidance: lift content above the on-screen keyboard.
        padding: EdgeInsets.only(bottom: viewInsets),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grabber handle.
              Padding(
                padding: const EdgeInsets.only(top: Space.x3, bottom: Space.x2),
                child: Container(
                  width: Space.x10,
                  height: Space.x1,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.x4,
                    Space.x2,
                    Space.x4,
                    Space.x4,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
