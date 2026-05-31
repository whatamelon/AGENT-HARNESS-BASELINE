import 'package:ds/src/components/chip.dart';
import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/gen/motion.dart';
import 'package:ds/src/gen/typography.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// A single bottom-nav destination (DESIGN-COMPONENTS §6).
@immutable
class DsNavItem {
  const DsNavItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badgeCount,
  });

  /// Inactive icon (Material `Icons.*` — single icon set).
  final IconData icon;

  /// Korean label shown under the icon.
  final String label;

  /// Optional filled/active icon; falls back to [icon] when null.
  final IconData? selectedIcon;

  /// Optional notification count rendered as a [DsCountBadge] on the icon.
  final int? badgeCount;
}

/// ANDS bottom navigation bar — presentational only (no routing; the P2
/// app_shell wires [onTap] to navigation). Active destination stays visibly
/// marked (primary icon + label); inactive uses `textSubtle`. Each tab target
/// is >=44dp. At most 5 tabs (global rule), enforced by an assert.
class DsBottomNav extends StatelessWidget {
  const DsBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    super.key,
  })  : assert(items.length >= 2, 'bottom nav needs at least 2 tabs'),
        assert(items.length <= 5, 'bottom nav allows at most 5 tabs');

  final List<DsNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavTab(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DsNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = selected ? c.primary.primary : c.textSubtle;
    final icon = selected ? (item.selectedIcon ?? item.icon) : item.icon;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Icon(icon: icon, color: color, badgeCount: item.badgeCount),
              const SizedBox(height: Space.x1),
              AnimatedDefaultTextStyle(
                duration: Motion.fastDuration,
                curve: Motion.fastCurve,
                style: DsType.micro.copyWith(color: color),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon({required this.icon, required this.color, this.badgeCount});

  final IconData icon;
  final Color color;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 24, color: color);
    final count = badgeCount;
    if (count == null || count <= 0) return iconWidget;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          top: -Space.x2,
          right: -Space.x3,
          child: DsCountBadge(count: count),
        ),
      ],
    );
  }
}
