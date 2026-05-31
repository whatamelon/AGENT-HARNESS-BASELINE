import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/gen/motion.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// Card variants (DESIGN-COMPONENTS §3).
enum DsCardVariant {
  /// Compact horizontal row: thumbnail left + info right.
  list,

  /// Full-bleed hero (page header, one per screen).
  hero,

  /// Grouped container: header + content with hairline dividers.
  section,
}

/// ANDS card: surface + 1px border + `Radii.md`, no shadow (elevation/0).
/// Tappable cards get a press scale. Nested radius is `Radii.sm`.
class DsCard extends StatefulWidget {
  const DsCard({
    required this.child,
    this.variant = DsCardVariant.section,
    this.onTap,
    this.padding,
    super.key,
  });

  /// Convenience for the compact list variant.
  const DsCard.list({
    required this.child,
    this.onTap,
    this.padding,
    super.key,
  }) : variant = DsCardVariant.list;

  /// Convenience for the full-bleed hero variant.
  const DsCard.hero({
    required this.child,
    this.onTap,
    this.padding,
    super.key,
  }) : variant = DsCardVariant.hero;

  final Widget child;
  final DsCardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  State<DsCard> createState() => _DsCardState();
}

class _DsCardState extends State<DsCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tappable = widget.onTap != null;
    final radius = BorderRadius.circular(Radii.md);

    final isHero = widget.variant == DsCardVariant.hero;
    final padding = widget.padding ??
        (isHero
            ? EdgeInsets.zero
            : const EdgeInsets.all(Space.x4));

    final card = AnimatedContainer(
      duration: Motion.fastDuration,
      curve: Motion.fastCurve,
      clipBehavior: isHero ? Clip.antiAlias : Clip.none,
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: radius,
        border: Border.all(color: c.border),
      ),
      child: widget.child,
    );

    if (!tappable) return card;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? DsState.pressScale : 1.0,
        duration: Motion.fastDuration,
        curve: Motion.fastCurve,
        child: card,
      ),
    );
  }
}
