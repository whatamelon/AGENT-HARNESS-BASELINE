// alchemist's `goldenTest` returns a Future that is intentionally fire-and-
// forget at the top level of a test file (the framework awaits it internally);
// awaiting/unawaiting each call is not the supported usage.
// ignore_for_file: discarded_futures

import 'package:alchemist/alchemist.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P1-a component goldens (light mode, state matrix). Dark goldens are P1.5;
/// dark-relevant contrast is covered in code by B-2/B-3.
void main() {
  group('P1-a goldens', () {
    goldenTest(
      'buttons — 5 variants + states',
      fileName: 'buttons',
      // The loading variant runs an indeterminate spinner that never settles;
      // pump a fixed frame instead of pumpAndSettle.
      pumpBeforeTest: (tester) async =>
          tester.pump(const Duration(milliseconds: 50)),
      builder: () => GoldenTestGroup(
        columns: 2,
        children: [
          GoldenTestScenario(
            name: 'primary',
            child: _wrap(DsButton(label: '결제하기', onPressed: () {})),
          ),
          GoldenTestScenario(
            name: 'secondary',
            child: _wrap(
              DsButton(
                label: '취소',
                variant: DsButtonVariant.secondary,
                onPressed: () {},
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'tonal',
            child: _wrap(
              DsButton(
                label: '저장',
                variant: DsButtonVariant.tonal,
                onPressed: () {},
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'ghost',
            child: _wrap(
              DsButton(
                label: '더보기',
                variant: DsButtonVariant.ghost,
                onPressed: () {},
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'destructive',
            child: _wrap(
              DsButton(
                label: '삭제',
                variant: DsButtonVariant.destructive,
                onPressed: () {},
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'loading',
            child: _wrap(
              DsButton(label: '결제하기', loading: true, onPressed: () {}),
            ),
          ),
          GoldenTestScenario(
            name: 'disabled',
            child: _wrap(const DsButton(label: '결제하기', onPressed: null)),
          ),
          GoldenTestScenario(
            name: 'with leading icon',
            child: _wrap(
              DsButton(
                label: '예약하기',
                leading: Icons.event_available,
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'text fields — states',
      fileName: 'text_fields',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'default',
            child: _wrap(
              const DsTextField(label: '이메일', hint: 'name@example.com'),
            ),
          ),
          GoldenTestScenario(
            name: 'error',
            child: _wrap(
              const DsTextField(
                label: '이메일',
                status: DsFieldStatus.error,
                helper: '올바른 이메일 형식으로 입력해 주세요.',
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'success',
            child: _wrap(
              const DsTextField(
                label: '이메일',
                status: DsFieldStatus.success,
                helper: '사용 가능한 이메일입니다.',
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'disabled',
            child: _wrap(
              const DsTextField(label: '이메일', enabled: false, hint: '입력 불가'),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'cards — 3 variants',
      fileName: 'cards',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'list',
            child: _wrap(
              DsCard.list(
                onTap: () {},
                child: const Text('컴팩트 리스트 카드'),
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'section',
            child: _wrap(
              const DsCard(child: Text('섹션 컨테이너 카드')),
            ),
          ),
          GoldenTestScenario(
            name: 'hero',
            child: _wrap(
              const DsCard.hero(
                child: SizedBox(
                  height: 120,
                  child: Center(child: Text('히어로 카드')),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'app bar — scrolled/idle',
      fileName: 'app_bar',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'idle',
            child: _wrap(
              DsAppBar(title: '계약 상세', onBack: () {}),
            ),
          ),
          GoldenTestScenario(
            name: 'scrolled',
            child: _wrap(
              DsAppBar(title: '계약 상세', onBack: () {}, scrolled: true),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'list — content/empty/error',
      fileName: 'list',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'content',
            child: _wrap(
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
            ),
          ),
          GoldenTestScenario(
            name: 'empty',
            child: _wrap(
              const SizedBox(
                height: 240,
                child: DsList(status: DsListStatus.empty),
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'error',
            child: _wrap(
              SizedBox(
                height: 280,
                child: DsList(status: DsListStatus.error, onRetry: () {}),
              ),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'chips & badges',
      fileName: 'chips',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'chip default/selected',
            child: _wrap(
              Wrap(
                spacing: Space.x2,
                children: [
                  DsChip(label: '전체', onTap: () {}),
                  DsChip(label: '예약', selected: true, onTap: () {}),
                ],
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'badges',
            child: _wrap(
              const Wrap(
                spacing: Space.x2,
                children: [
                  DsBadge(label: '진행중', tone: DsBadgeTone.info),
                  DsBadge(label: '완료', tone: DsBadgeTone.success),
                  DsBadge(label: '대기', tone: DsBadgeTone.warning),
                  DsBadge(label: '취소', tone: DsBadgeTone.danger),
                  DsBadge(label: '기본'),
                ],
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'tag & count',
            child: _wrap(
              const Wrap(
                spacing: Space.x2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DsTag(label: '추모공원'),
                  DsCountBadge(count: 3),
                  DsCountBadge(count: 128),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'state view — empty/error',
      fileName: 'state_view',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'empty',
            child: _wrap(
              const SizedBox(
                height: 240,
                child: DsStateView.empty(message: '아직 등록된 항목이 없습니다.'),
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'error',
            child: _wrap(
              SizedBox(
                height: 280,
                child: DsStateView.error(onRetry: () {}),
              ),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'bottom sheet — shell',
      fileName: 'bottom_sheet',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'sheet',
            child: _wrap(
              const DsBottomSheet(
                title: '옵션 선택',
                child: SizedBox(
                  height: 120,
                  child: Center(child: Text('시트 콘텐츠')),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'bottom nav — destinations',
      fileName: 'bottom_nav',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'home selected + badge',
            child: _wrap(
              SizedBox(
                height: 72,
                child: DsBottomNav(
                  selectedIndex: 0,
                  onTap: (_) {},
                  items: const [
                    DsNavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: '홈',
                    ),
                    DsNavItem(
                      icon: Icons.event_outlined,
                      label: '예약',
                      badgeCount: 3,
                    ),
                    DsNavItem(
                      icon: Icons.person_outline,
                      label: '내정보',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'image — states',
      fileName: 'image',
      builder: () => GoldenTestGroup(
        columns: 2,
        children: [
          GoldenTestScenario(
            name: 'fallback (null url)',
            child: _wrap(
              const SizedBox(
                width: 120,
                child: DsImage(url: null),
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'fallback 16:9',
            child: _wrap(
              const SizedBox(
                width: 160,
                child: DsImage(url: '', aspectRatio: 16 / 9),
              ),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'dialog — confirm/destructive',
      fileName: 'dialog',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'confirm',
            child: _wrap(
              DsDialog(
                title: '예약을 확정할까요?',
                message: '확정 후에는 변경이 어려울 수 있습니다.',
                onConfirm: () {},
                onCancel: () {},
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'destructive',
            child: _wrap(
              DsDialog(
                title: '계약을 삭제할까요?',
                message: '삭제한 계약은 복구할 수 없습니다.',
                confirmLabel: '삭제',
                variant: DsDialogVariant.destructive,
                onConfirm: () {},
                onCancel: () {},
              ),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'snackbar — tones',
      fileName: 'snackbar',
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'success',
            child: _wrap(
              const DsSnackbarContent(
                message: '저장되었습니다.',
                tone: DsSnackTone.success,
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'info + action',
            child: _wrap(
              DsSnackbarContent(
                message: '예약이 임시 저장되었습니다.',
                actionLabel: '실행취소',
                onAction: () {},
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'error',
            child: _wrap(
              const DsSnackbarContent(
                message: '저장에 실패했습니다.',
                tone: DsSnackTone.error,
              ),
            ),
          ),
        ],
      ),
    );
  });
}

/// Wrap a component in the DS theme on a sized surface for stable goldens.
Widget _wrap(Widget child) => Theme(
      data: buildTheme(),
      child: Builder(
        builder: (context) => ColoredBox(
          color: context.c.bg,
          child: Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: SizedBox(width: 320, child: child),
          ),
        ),
      ),
    );
