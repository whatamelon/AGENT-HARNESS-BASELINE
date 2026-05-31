import 'package:ds/src/components/button.dart';
import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/gen/elevation.dart';
import 'package:ds/src/gen/typography.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// Dialog intent (DESIGN-COMPONENTS §10). Dialogs are for confirm/destructive
/// decisions only — selection UIs use a bottom sheet instead.
enum DsDialogVariant {
  /// Neutral confirmation — primary confirm CTA.
  confirm,

  /// Destructive confirmation — danger confirm CTA.
  destructive,
}

/// Show an ANDS dialog (DESIGN-COMPONENTS §10): centered surface card, backdrop
/// + back-button dismiss, single layer (never stack a dialog on a dialog).
///
/// Returns `true` when the confirm action is taken, `false`/`null` on cancel or
/// barrier dismiss. Korean copy by default.
Future<bool?> showDsDialog({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  DsDialogVariant variant = DsDialogVariant.confirm,
}) {
  // Note: the destructive-confirm `warning` haptic is *not* fired here — the
  // confirm CTA is a `DsButtonVariant.destructive` button, which already emits
  // `HapticIntent.warning` on press via the button wiring. Firing again from
  // this builder would double-buzz a single tap. Neutral confirm uses a
  // primary button (`HapticIntent.light`), matching a low-stakes confirm.
  final c = context.c;
  return showDialog<bool>(
    context: context,
    barrierColor: c.overlay,
    builder: (dialogContext) => DsDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      variant: variant,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
      onCancel: () => Navigator.of(dialogContext).pop(false),
    ),
  );
}

/// The dialog shell: surface card with `Radii.lg`, `Elevation.e3`, title3 +
/// body copy, and a cancel/confirm action row. Usually obtained via
/// [showDsDialog]; exposed for custom hosts/tests.
class DsDialog extends StatelessWidget {
  const DsDialog({
    required this.title,
    required this.onConfirm,
    required this.onCancel,
    this.message,
    this.confirmLabel = '확인',
    this.cancelLabel = '취소',
    this.variant = DsDialogVariant.confirm,
    super.key,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final DsDialogVariant variant;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isDestructive = variant == DsDialogVariant.destructive;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Semantics(
          container: true,
          label: title,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.lg),
                boxShadow: Elevation.e3,
              ),
              child: Padding(
                padding: const EdgeInsets.all(Space.x6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: DsType.title3.copyWith(color: c.text),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: Space.x2),
                      Text(
                        message!,
                        style: DsType.body.copyWith(color: c.textMuted),
                      ),
                    ],
                    const SizedBox(height: Space.x6),
                    Row(
                      children: [
                        Expanded(
                          child: DsButton(
                            label: cancelLabel,
                            variant: DsButtonVariant.secondary,
                            onPressed: onCancel,
                          ),
                        ),
                        const SizedBox(width: Space.x3),
                        Expanded(
                          child: DsButton(
                            label: confirmLabel,
                            variant: isDestructive
                                ? DsButtonVariant.destructive
                                : DsButtonVariant.primary,
                            onPressed: onConfirm,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
