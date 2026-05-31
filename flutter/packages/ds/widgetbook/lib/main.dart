import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

void main() => runApp(const DsWidgetbook());

/// Widgetbook catalog: token palettes + P1-a component use-cases.
/// Light mode only — the design system is pinned to [ThemeMode.light].
class DsWidgetbook extends StatelessWidget {
  const DsWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      addons: [
        ViewportAddon([
          IosViewports.iPhone13,
          AndroidViewports.samsungGalaxyS20,
        ]),
        ThemeAddon<ThemeData>(
          themes: [
            WidgetbookTheme(name: 'ANDS Light', data: buildTheme()),
          ],
          themeBuilder: (context, theme, child) =>
              Theme(data: theme, child: child),
        ),
      ],
      directories: [
        WidgetbookCategory(
          name: 'Tokens',
          children: [
            WidgetbookComponent(
              name: 'Palette',
              useCases: [
                WidgetbookUseCase(name: 'Semantic colors', builder: _palette),
              ],
            ),
            WidgetbookComponent(
              name: 'Typography',
              useCases: [
                WidgetbookUseCase(name: 'Scale', builder: _typography),
              ],
            ),
            WidgetbookComponent(
              name: 'Spacing',
              useCases: [
                WidgetbookUseCase(name: 'Steps', builder: _spacing),
              ],
            ),
          ],
        ),
        WidgetbookCategory(
          name: 'Components',
          children: [
            WidgetbookComponent(
              name: 'DsButton',
              useCases: [
                WidgetbookUseCase(name: 'Primary', builder: _btn),
                WidgetbookUseCase(
                  name: 'Secondary',
                  builder: (c) => _btn(c, DsButtonVariant.secondary, '취소'),
                ),
                WidgetbookUseCase(
                  name: 'Tonal',
                  builder: (c) => _btn(c, DsButtonVariant.tonal, '저장'),
                ),
                WidgetbookUseCase(
                  name: 'Ghost',
                  builder: (c) => _btn(c, DsButtonVariant.ghost, '더보기'),
                ),
                WidgetbookUseCase(
                  name: 'Destructive',
                  builder: (c) => _btn(c, DsButtonVariant.destructive, '삭제'),
                ),
                WidgetbookUseCase(name: 'Loading', builder: _btnLoading),
                WidgetbookUseCase(name: 'Disabled', builder: _btnDisabled),
              ],
            ),
            WidgetbookComponent(
              name: 'DsTextField',
              useCases: [
                WidgetbookUseCase(name: 'Default', builder: _fieldDefault),
                WidgetbookUseCase(name: 'Error', builder: _fieldError),
              ],
            ),
            WidgetbookComponent(
              name: 'DsCard',
              useCases: [
                WidgetbookUseCase(name: 'List', builder: _cardList),
                WidgetbookUseCase(name: 'Section', builder: _cardSection),
              ],
            ),
            WidgetbookComponent(
              name: 'DsAppBar',
              useCases: [
                WidgetbookUseCase(name: 'Scrolled', builder: _appBar),
              ],
            ),
            WidgetbookComponent(
              name: 'DsList',
              useCases: [
                WidgetbookUseCase(name: 'Content', builder: _listContent),
                WidgetbookUseCase(name: 'Empty', builder: _listEmpty),
                WidgetbookUseCase(name: 'Error', builder: _listError),
              ],
            ),
            WidgetbookComponent(
              name: 'DsChip',
              useCases: [
                WidgetbookUseCase(name: 'Chips', builder: _chips),
                WidgetbookUseCase(name: 'Badges', builder: _badges),
              ],
            ),
            WidgetbookComponent(
              name: 'DsStateView',
              useCases: [
                WidgetbookUseCase(name: 'Empty', builder: _stateEmpty),
                WidgetbookUseCase(name: 'Error', builder: _stateError),
              ],
            ),
            WidgetbookComponent(
              name: 'DsBottomSheet',
              useCases: [
                WidgetbookUseCase(name: 'Sheet', builder: _bottomSheet),
              ],
            ),
            WidgetbookComponent(
              name: 'DsBottomNav',
              useCases: [
                WidgetbookUseCase(name: 'Destinations', builder: _bottomNav),
              ],
            ),
            WidgetbookComponent(
              name: 'DsImage',
              useCases: [
                WidgetbookUseCase(name: 'Fallback', builder: _image),
              ],
            ),
            WidgetbookComponent(
              name: 'DsDialog',
              useCases: [
                WidgetbookUseCase(name: 'Confirm', builder: _dialogConfirm),
                WidgetbookUseCase(
                  name: 'Destructive',
                  builder: _dialogDestructive,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'DsSnackbar',
              useCases: [
                WidgetbookUseCase(name: 'Success', builder: _snackSuccess),
                WidgetbookUseCase(name: 'Info + action', builder: _snackInfo),
                WidgetbookUseCase(name: 'Error', builder: _snackError),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

Widget _center(Widget child) => Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x4),
        child: SizedBox(width: 320, child: child),
      ),
    );

Widget _btn(
  BuildContext context, [
  DsButtonVariant variant = DsButtonVariant.primary,
  String label = '결제하기',
]) =>
    _center(DsButton(label: label, variant: variant, onPressed: () {}));

Widget _btnLoading(BuildContext context) =>
    _center(DsButton(label: '결제하기', loading: true, onPressed: () {}));

Widget _btnDisabled(BuildContext context) =>
    _center(const DsButton(label: '결제하기', onPressed: null));

Widget _fieldDefault(BuildContext context) =>
    _center(const DsTextField(label: '이메일', hint: 'name@example.com'));

Widget _fieldError(BuildContext context) => _center(
      const DsTextField(
        label: '이메일',
        status: DsFieldStatus.error,
        helper: '올바른 이메일 형식으로 입력해 주세요.',
      ),
    );

Widget _cardList(BuildContext context) => _center(
      DsCard.list(onTap: () {}, child: const Text('리스트 카드 항목')),
    );

Widget _cardSection(BuildContext context) =>
    _center(const DsCard(child: Text('섹션 카드 콘텐츠')));

Widget _appBar(BuildContext context) =>
    DsAppBar(title: '계약 상세', onBack: () {}, scrolled: true);

Widget _listContent(BuildContext context) => _center(
      DsList(
        children: [
          DsListItem(
            title: '방문 예약',
            subtitle: '2026년 7월 2일 오후 2시',
            onTap: () {},
          ),
          DsListItem(
            title: '추모관 안내',
            subtitle: '운영 시간 09:00–18:00',
            onTap: () {},
          ),
          const DsListItem(title: '고객센터', subtitle: '평일 09–18시'),
        ],
      ),
    );

Widget _listEmpty(BuildContext context) => _center(
      const SizedBox(
        height: 240,
        child: DsList(status: DsListStatus.empty),
      ),
    );

Widget _listError(BuildContext context) => _center(
      SizedBox(
        height: 280,
        child: DsList(status: DsListStatus.error, onRetry: () {}),
      ),
    );

Widget _chips(BuildContext context) => _center(
      Wrap(
        spacing: Space.x2,
        children: [
          DsChip(label: '전체', onTap: () {}),
          DsChip(label: '예약', selected: true, onTap: () {}),
        ],
      ),
    );

Widget _badges(BuildContext context) => _center(
      const Wrap(
        spacing: Space.x2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DsBadge(label: '진행중', tone: DsBadgeTone.info),
          DsBadge(label: '완료', tone: DsBadgeTone.success),
          DsTag(label: '추모공원'),
          DsCountBadge(count: 12),
        ],
      ),
    );

Widget _stateEmpty(BuildContext context) =>
    _center(const DsStateView.empty(message: '아직 등록된 항목이 없습니다.'));

Widget _stateError(BuildContext context) => _center(
      SizedBox(height: 280, child: DsStateView.error(onRetry: () {})),
    );

Widget _bottomSheet(BuildContext context) => _center(
      const DsBottomSheet(
        title: '옵션 선택',
        child: SizedBox(
          height: 120,
          child: Center(child: Text('시트 콘텐츠')),
        ),
      ),
    );

Widget _bottomNav(BuildContext context) => DsBottomNav(
      selectedIndex: 0,
      onTap: (_) {},
      items: const [
        DsNavItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: '홈',
        ),
        DsNavItem(icon: Icons.event_outlined, label: '예약', badgeCount: 3),
        DsNavItem(icon: Icons.person_outline, label: '내정보'),
      ],
    );

Widget _image(BuildContext context) => _center(
      const SizedBox(width: 160, child: DsImage(url: null)),
    );

Widget _dialogConfirm(BuildContext context) => DsDialog(
      title: '예약을 확정할까요?',
      message: '확정 후에는 변경이 어려울 수 있습니다.',
      onConfirm: () {},
      onCancel: () {},
    );

Widget _dialogDestructive(BuildContext context) => DsDialog(
      title: '계약을 삭제할까요?',
      message: '삭제한 계약은 복구할 수 없습니다.',
      confirmLabel: '삭제',
      variant: DsDialogVariant.destructive,
      onConfirm: () {},
      onCancel: () {},
    );

Widget _snackSuccess(BuildContext context) => _center(
      const DsSnackbarContent(
        message: '저장되었습니다.',
        tone: DsSnackTone.success,
      ),
    );

Widget _snackInfo(BuildContext context) => _center(
      DsSnackbarContent(
        message: '예약이 임시 저장되었습니다.',
        actionLabel: '실행취소',
        onAction: () {},
      ),
    );

Widget _snackError(BuildContext context) => _center(
      const DsSnackbarContent(
        message: '저장에 실패했습니다.',
        tone: DsSnackTone.error,
      ),
    );

Widget _palette(BuildContext context) {
  final c = context.c;
  final swatches = <(String, Color)>[
    ('primary', c.primary.primary),
    ('text', c.text),
    ('info', c.info),
    ('success', c.success),
    ('warning', c.warning),
    ('danger', c.danger),
  ];
  return _center(
    Wrap(
      spacing: Space.x2,
      runSpacing: Space.x2,
      children: [
        for (final (name, color) in swatches)
          Container(
            width: 96,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Text(name, style: DsType.caption.copyWith(color: c.bg)),
          ),
      ],
    ),
  );
}

Widget _typography(BuildContext context) {
  final c = context.c;
  return _center(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('display', style: DsType.display.copyWith(color: c.text)),
        Text('title1', style: DsType.title1.copyWith(color: c.text)),
        Text('body', style: DsType.body.copyWith(color: c.text)),
        Text('caption', style: DsType.caption.copyWith(color: c.textMuted)),
      ],
    ),
  );
}

Widget _spacing(BuildContext context) {
  final c = context.c;
  final steps = <double>[Space.x1, Space.x2, Space.x4, Space.x6, Space.x8];
  return _center(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: Container(
              width: s * 4,
              height: 16,
              color: c.primary.primary,
            ),
          ),
      ],
    ),
  );
}
