import 'package:ds/src/components/state_view.dart';
import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/gen/typography.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// List render state (DESIGN-COMPONENTS §4). Drives content vs the shared
/// loading/empty/error shells.
enum DsListStatus { content, loading, empty, error }

/// A compact vertical list: hairline dividers between rows, surface background.
/// Density target is 3+ items per screen (global rule). loading/empty/error
/// delegate to [DsStateView] so states stay consistent.
///
/// Content renders as a non-scrolling [Column] meant to be embedded in an outer
/// scroll view (e.g. a page-level scrollable); it does not own a viewport.
class DsList extends StatelessWidget {
  const DsList({
    this.children = const <Widget>[],
    this.status = DsListStatus.content,
    this.emptyTitle = '결과가 없습니다',
    this.emptyMessage,
    this.errorMessage = '잠시 후 다시 시도해 주세요.',
    this.onRetry,
    super.key,
  });

  final List<Widget> children;
  final DsListStatus status;
  final String emptyTitle;
  final String? emptyMessage;
  final String errorMessage;

  /// Retry handler surfaced in the [DsListStatus.error] shell.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    switch (status) {
      case DsListStatus.loading:
        return const DsStateView.loading();
      case DsListStatus.empty:
        return DsStateView.empty(title: emptyTitle, message: emptyMessage);
      case DsListStatus.error:
        return DsStateView.error(message: errorMessage, onRetry: onRetry);
      case DsListStatus.content:
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i++) {
          if (i > 0) {
            rows.add(Divider(height: 1, thickness: 1, color: c.border));
          }
          rows.add(children[i]);
        }
        return ColoredBox(
          color: c.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        );
    }
  }
}

/// A compact list row: optional leading thumbnail (left ~56dp) + title/subtitle
/// (right) + optional trailing. Tap target is >=44dp via a min row height.
/// Tappable
/// rows expose a button Semantics with the title as label.
class DsListItem extends StatelessWidget {
  const DsListItem({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Leading thumbnail/icon (kept compact on the left).
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  static const double _minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x3,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: Space.x3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: DsType.body.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: Space.x1),
                    Text(
                      subtitle!,
                      style: DsType.bodySm.copyWith(color: c.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Space.x3),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(container: true, label: title, child: row);
    }

    return Semantics(
      button: true,
      label: title,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
