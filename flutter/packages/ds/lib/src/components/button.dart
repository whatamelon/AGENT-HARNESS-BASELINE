import 'package:core/core.dart';
import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/gen/motion.dart';
import 'package:ds/src/haptics/component_haptics.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// The five ANDS button variants (DESIGN-COMPONENTS §1).
enum DsButtonVariant {
  /// Solid primary CTA — one decision area, one of these.
  primary,

  /// Outlined neutral action on surface.
  secondary,

  /// Filled-tonal neutral action (surfaceAlt).
  tonal,

  /// Transparent low-emphasis action.
  ghost,

  /// Solid danger for destructive confirmation.
  destructive,
}

/// ANDS button. Token-only; 48dp+ height; press scale; inline loading that
/// holds the label slot (no width jump); disabled is surfaceAlt + textSubtle
/// (never a dimmed primary).
class DsButton extends StatefulWidget {
  const DsButton({
    required this.label,
    required this.onPressed,
    this.variant = DsButtonVariant.primary,
    this.leading,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final DsButtonVariant variant;
  final IconData? leading;

  /// When true the button disables and shows an inline spinner in the label
  /// slot. Visually distinct from [onPressed] == null (disabled).
  final bool loading;

  bool get _isDisabled => onPressed == null && !loading;

  @override
  State<DsButton> createState() => _DsButtonState();
}

class _DsButtonState extends State<DsButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  /// Fires the press haptic, then invokes the caller's `onPressed`. Haptic is
  /// best-effort decoration: a destructive button warns, everything else is a
  /// light tap. Only reached when the button is enabled (see `onTap` guard).
  void _handleTap(BuildContext context) {
    final intent = widget.variant == DsButtonVariant.destructive
        ? HapticIntent.warning
        : HapticIntent.light;
    fireHaptic(context, intent);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final spec = _resolveSpec(c);
    final enabled = widget.onPressed != null && !widget.loading;

    final fg = widget.loading ? spec.fg.withValues(alpha: 0) : spec.fg;
    final content = _content(context, fg);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: enabled ? () => _handleTap(context) : null,
        child: AnimatedScale(
          scale: _pressed ? DsState.pressScale : 1.0,
          duration: Motion.fastDuration,
          curve: Motion.fastCurve,
          child: AnimatedContainer(
            duration: Motion.fastDuration,
            curve: Motion.fastCurve,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x5,
              vertical: Space.x3,
            ),
            decoration: BoxDecoration(
              color: _pressed && enabled ? spec.bgPressed : spec.bg,
              borderRadius: BorderRadius.circular(Radii.md),
              border: spec.border == null
                  ? null
                  : Border.all(color: spec.border!),
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  content,
                  if (widget.loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(spec.fg),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Color fg) {
    final labelStyle =
        Theme.of(context).textTheme.labelLarge?.copyWith(color: fg);
    if (widget.leading == null) {
      return Text(widget.label, style: labelStyle);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.leading, size: 18, color: fg),
        const SizedBox(width: Space.x2),
        Text(widget.label, style: labelStyle),
      ],
    );
  }

  _ButtonSpec _resolveSpec(DsColors c) {
    final p = c.primary;
    if (widget._isDisabled) {
      // Disabled is identical across variants: surfaceAlt + textSubtle.
      return _ButtonSpec(
        bg: c.surfaceAlt,
        bgPressed: c.surfaceAlt,
        fg: c.textSubtle,
        border: null,
      );
    }
    switch (widget.variant) {
      case DsButtonVariant.primary:
        return _ButtonSpec(
          bg: p.primary,
          bgPressed: p.pressed,
          fg: p.onPrimary,
          border: null,
        );
      case DsButtonVariant.secondary:
        return _ButtonSpec(
          bg: c.surface,
          bgPressed: c.surfaceAlt,
          fg: c.text,
          border: c.border,
        );
      case DsButtonVariant.tonal:
        return _ButtonSpec(
          bg: c.surfaceAlt,
          bgPressed: c.surfaceInset,
          fg: c.text,
          border: null,
        );
      case DsButtonVariant.ghost:
        return _ButtonSpec(
          bg: c.bg.withValues(alpha: 0),
          bgPressed: c.surfaceAlt,
          fg: c.textMuted,
          border: null,
        );
      case DsButtonVariant.destructive:
        return _ButtonSpec(
          bg: c.danger,
          bgPressed: c.danger.withValues(alpha: 0.88),
          fg: c.bg,
          border: null,
        );
    }
  }
}

@immutable
class _ButtonSpec {
  const _ButtonSpec({
    required this.bg,
    required this.bgPressed,
    required this.fg,
    required this.border,
  });

  final Color bg;
  final Color bgPressed;
  final Color fg;
  final Color? border;
}
