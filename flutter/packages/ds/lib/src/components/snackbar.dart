import 'package:core/core.dart';
import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/gen/elevation.dart';
import 'package:ds/src/gen/typography.dart';
import 'package:ds/src/haptics/component_haptics.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// Snackbar tone (DESIGN-COMPONENTS §11). Drives the leading icon + accent.
enum DsSnackTone { success, info, error }

/// Show an ANDS snackbar via the nearest [ScaffoldMessenger]: floating card,
/// `Elevation.e3`, tone icon + Korean message, with an optional single action.
///
/// Returns the controller so callers can await dismissal if needed.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showDsSnackbar({
  required BuildContext context,
  required String message,
  DsSnackTone tone = DsSnackTone.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  // Outcome haptic keyed to tone: success/error fire; info is silent (a
  // neutral notice does not warrant feedback). Best-effort decoration.
  final outcome = _toneHaptic(tone);
  if (outcome != null) {
    fireHaptic(context, outcome);
  }
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  return messenger.showSnackBar(
    buildDsSnackBar(
      context: context,
      message: message,
      tone: tone,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}

/// Build the token-styled [SnackBar]. Exposed for custom hosts/tests; most
/// callers use [showDsSnackbar].
SnackBar buildDsSnackBar({
  required BuildContext context,
  required String message,
  DsSnackTone tone = DsSnackTone.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  // The visual surface, accent, and the single optional action all live inside
  // [DsSnackbarContent]; the host SnackBar is made transparent (token bg @ 0
  // alpha) so we keep one layer with no blank system action area.
  final c = context.c;
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: c.bg.withValues(alpha: 0),
    elevation: 0,
    margin: const EdgeInsets.all(Space.x4),
    padding: EdgeInsets.zero,
    content: DsSnackbarContent(
      message: message,
      tone: tone,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
    dismissDirection: DismissDirection.horizontal,
  );
}

/// The snackbar content body: tone icon + message + optional inline action.
/// Drawn on its own surface card with `Elevation.e3` so it reads as a floating
/// layer regardless of the host theme's default snackbar styling.
class DsSnackbarContent extends StatelessWidget {
  const DsSnackbarContent({
    required this.message,
    this.tone = DsSnackTone.info,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final DsSnackTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = _accent(c, tone);

    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
          boxShadow: Elevation.e3,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x3,
        ),
        child: Row(
          children: [
            Icon(_icon(tone), size: 20, color: accent),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Text(
                message,
                style: DsType.bodySm.copyWith(color: c.text),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: Space.x3),
              _Action(label: actionLabel!, color: accent, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x2,
              vertical: Space.x3,
            ),
            child: Center(
              child: Text(label, style: DsType.label.copyWith(color: color)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Maps a snackbar [tone] to its outcome haptic. `info` returns null (no
/// feedback for a neutral notice).
HapticIntent? _toneHaptic(DsSnackTone tone) {
  switch (tone) {
    case DsSnackTone.success:
      return HapticIntent.success;
    case DsSnackTone.error:
      return HapticIntent.error;
    case DsSnackTone.info:
      return null;
  }
}

Color _accent(DsColors c, DsSnackTone tone) {
  switch (tone) {
    case DsSnackTone.success:
      return c.success;
    case DsSnackTone.info:
      return c.info;
    case DsSnackTone.error:
      return c.danger;
  }
}

IconData _icon(DsSnackTone tone) {
  switch (tone) {
    case DsSnackTone.success:
      return Icons.check_circle_outline;
    case DsSnackTone.info:
      return Icons.info_outline;
    case DsSnackTone.error:
      return Icons.error_outline;
  }
}
