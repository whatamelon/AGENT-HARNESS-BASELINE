import 'package:core/core.dart';
import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/haptics/component_haptics.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// Text field state (DESIGN-COMPONENTS §2). default/focus are runtime; error
/// and success are caller-driven; disabled follows `enabled: false`.
enum DsFieldStatus { normal, error, success }

/// ANDS text field. Label always shown (above), surfaceInset background,
/// `Radii.sm`. Error is a triple signal: 1.5px danger border + helper message
/// + trailing icon. Focus shows a 2dp focus ring + borderStrong.
class DsTextField extends StatefulWidget {
  const DsTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.status = DsFieldStatus.normal,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;

  /// Helper/error message shown below the field. For [DsFieldStatus.error]
  /// this should include recovery guidance.
  final String? helper;
  final DsFieldStatus status;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  State<DsTextField> createState() => _DsTextFieldState();
}

class _DsTextFieldState extends State<DsTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focused != _focusNode.hasFocus) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void didUpdateWidget(DsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Error haptic fires once, on the transition *into* the error status
    // (validation just failed) — not on every rebuild that stays in error.
    final enteredError = widget.status == DsFieldStatus.error &&
        oldWidget.status != DsFieldStatus.error;
    if (enteredError) {
      fireHaptic(context, HapticIntent.error);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final theme = Theme.of(context);
    final isError = widget.status == DsFieldStatus.error;
    final isSuccess = widget.status == DsFieldStatus.success;

    final Color borderColor;
    double borderWidth = 1;
    if (!widget.enabled) {
      borderColor = c.border;
    } else if (isError) {
      borderColor = c.danger;
      borderWidth = 1.5;
    } else if (_focused) {
      borderColor = c.borderStrong;
      borderWidth = 2;
    } else if (isSuccess) {
      borderColor = c.success;
    } else {
      borderColor = c.border;
    }

    final bg = widget.enabled
        ? (_focused ? c.surface : c.surfaceInset)
        : c.surfaceAlt;

    final trailingIcon = isError
        ? Icon(Icons.error_outline, size: 18, color: c.danger)
        : isSuccess
            ? Icon(Icons.check_circle_outline, size: 18, color: c.success)
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: widget.enabled ? c.text : c.textSubtle,
          ),
        ),
        const SizedBox(height: Space.x2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: _focused && widget.enabled
                ? [
                    BoxShadow(
                      color: c.primary.focusRing,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: Space.x4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  controller: widget.controller,
                  enabled: widget.enabled,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  onChanged: widget.onChanged,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: widget.enabled ? c.text : c.textSubtle,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: c.textSubtle,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: Space.x3,
                    ),
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: Space.x2),
                trailingIcon,
              ],
            ],
          ),
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: Space.x2),
          Text(
            widget.helper!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isError
                  ? c.danger
                  : isSuccess
                      ? c.success
                      : c.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
