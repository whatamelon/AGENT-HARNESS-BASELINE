import 'package:core/core.dart';
import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/gen/typography.dart';
import 'package:ds/src/haptics/component_haptics.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// Status tone for [DsBadge] (DESIGN-COMPONENTS §5). Each maps to a semantic
/// *Soft background + the matching solid text color.
enum DsBadgeTone { info, success, warning, danger, neutral }

/// A pill-shaped selectable chip (filter/choice). default is a neutral
/// surfaceAlt pill; selected switches to primary-soft + primary text +
/// primary-border. Tap target is >=44dp; exposes button + selected Semantics.
class DsChip extends StatelessWidget {
  const DsChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = c.primary;

    final bg = selected ? p.soft : c.surfaceAlt;
    final fg = selected ? p.primary : c.textMuted;
    final border = selected ? p.border : c.border;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        // Selection haptic on toggle, then the caller's handler. Kept null when
        // the chip is non-interactive so the disabled (untappable) state holds.
        onTap: onTap == null
            ? null
            : () {
                fireHaptic(context, HapticIntent.selection);
                onTap!.call();
              },
        borderRadius: BorderRadius.circular(Radii.full),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x4,
              vertical: Space.x2,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Radii.full),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  Icon(leading, size: 16, color: fg),
                  const SizedBox(width: Space.x1),
                ],
                Text(label, style: DsType.label.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small status badge: soft tinted background + solid same-hue text. Non-
/// interactive, pill-shaped, caption-sized.
class DsBadge extends StatelessWidget {
  const DsBadge({
    required this.label,
    this.tone = DsBadgeTone.neutral,
    super.key,
  });

  final String label;
  final DsBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = _resolve(c);

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x2,
          vertical: Space.x1,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Text(label, style: DsType.caption.copyWith(color: fg)),
      ),
    );
  }

  (Color, Color) _resolve(DsColors c) {
    switch (tone) {
      case DsBadgeTone.info:
        return (c.infoSoft, c.info);
      case DsBadgeTone.success:
        return (c.successSoft, c.success);
      case DsBadgeTone.warning:
        return (c.warningSoft, c.warning);
      case DsBadgeTone.danger:
        return (c.dangerSoft, c.danger);
      case DsBadgeTone.neutral:
        return (c.surfaceAlt, c.textMuted);
    }
  }
}

/// A neutral metadata tag: surfaceAlt background, muted text, small radius.
/// For non-status, non-interactive labels (e.g. category names).
class DsTag extends StatelessWidget {
  const DsTag({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x2,
          vertical: Space.x1,
        ),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Text(label, style: DsType.caption.copyWith(color: c.textMuted)),
      ),
    );
  }
}

/// A compact count badge (notification dot with a number). Danger background,
/// on-danger text. Caps display at 99+.
class DsCountBadge extends StatelessWidget {
  const DsCountBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final text = count > 99 ? '99+' : '$count';

    return Semantics(
      label: '$count개',
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: Space.x1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.danger,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Text(text, style: DsType.micro.copyWith(color: c.bg)),
      ),
    );
  }
}
