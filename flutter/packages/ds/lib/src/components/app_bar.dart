import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/gen/typography.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// ANDS sub-screen app bar (DESIGN-COMPONENTS §7).
///
/// Title (title3) + back affordance. Background `bg`; a hairline bottom border
/// appears once scrolled ([scrolled] = true) instead of a shadow. At most one
/// trailing action (global rule); pass [action] for it.
class DsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DsAppBar({
    required this.title,
    this.onBack,
    this.action,
    this.scrolled = false,
    super.key,
  });

  final String title;

  /// Back handler. When null, no back button is rendered (use on roots only —
  /// sub screens should always pass this).
  final VoidCallback? onBack;

  /// Single optional trailing action. Enforced to one by the API shape.
  final Widget? action;

  /// When true, reveal the hairline bottom border (scroll-synced by the host).
  final bool scrolled;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(
          bottom: BorderSide(
            color: scrolled ? c.border : c.bg,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: c.text,
                  tooltip: '뒤로',
                )
              else
                const SizedBox(width: Space.x4),
              Expanded(
                child: Text(
                  title,
                  style: DsType.title3.copyWith(color: c.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (action != null) action! else const SizedBox(width: Space.x4),
            ],
          ),
        ),
      ),
    );
  }
}
