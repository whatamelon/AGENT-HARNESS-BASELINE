import 'dart:async';

import 'package:app_kit/app_kit.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:reference_app/app.dart' show appChromeProvider;

/// Design-token + P1-a component showcase, rendered as the "디자인" tab body
/// inside the app shell. The shell owns the app bar + bottom nav; this is just
/// a scrollable body wrapped in [ChromeScroll] so scrolling here drives the
/// shared chrome show/hide.
class DsShowcasePage extends StatefulWidget {
  const DsShowcasePage({super.key});

  @override
  State<DsShowcasePage> createState() => _DsShowcasePageState();
}

class _DsShowcasePageState extends State<DsShowcasePage> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ChromeScroll(
      controllerProvider: appChromeProvider,
      child: ListView(
        padding: const EdgeInsets.all(Space.x4),
        children: [
          _section(context, '색상', _palette(context)),
          _section(context, '타이포그래피', _typography(context)),
          _section(context, '스페이싱', _spacing(context)),
          _section(context, '버튼', _buttons(context)),
          _section(context, '텍스트 필드', _fields(context)),
          _section(context, '카드', _cards(context)),
          _section(context, '리스트', _list(context)),
          _section(context, '칩·뱃지·태그', _chips(context)),
          _section(context, '상태 뷰', _states(context)),
          _section(context, '바텀 시트', _bottomSheet(context)),
          _section(context, '바텀 내비게이션', _bottomNav(context)),
          _section(context, '이미지', _images(context)),
          _section(context, '다이얼로그', _dialogs(context)),
          _section(context, '스낵바', _snackbars(context)),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DsType.title2.copyWith(color: context.c.text)),
          const SizedBox(height: Space.x4),
          child,
        ],
      ),
    );
  }

  Widget _palette(BuildContext context) {
    final c = context.c;
    final swatches = <(String, Color, Color)>[
      ('bg', c.bg, c.text),
      ('surfaceAlt', c.surfaceAlt, c.text),
      ('surfaceInset', c.surfaceInset, c.text),
      ('primary', c.primary.primary, c.onPrimary),
      ('text', c.text, c.bg),
      ('textMuted', c.textMuted, c.bg),
      ('info', c.info, c.bg),
      ('success', c.success, c.bg),
      ('warning', c.warning, c.bg),
      ('danger', c.danger, c.bg),
    ];
    return Wrap(
      spacing: Space.x2,
      runSpacing: Space.x2,
      children: [
        for (final (name, bg, fg) in swatches)
          Container(
            width: 96,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: c.border),
            ),
            child: Text(name, style: DsType.caption.copyWith(color: fg)),
          ),
      ],
    );
  }

  Widget _typography(BuildContext context) {
    final c = context.c;
    final styles = <(String, TextStyle)>[
      ('display', DsType.display),
      ('title1', DsType.title1),
      ('title2', DsType.title2),
      ('title3', DsType.title3),
      ('body', DsType.body),
      ('label', DsType.label),
      ('caption', DsType.caption),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, style) in styles)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: Text('$name · 다람쥐 헌 쳇바퀴',
                style: style.copyWith(color: c.text),),
          ),
      ],
    );
  }

  Widget _spacing(BuildContext context) {
    final c = context.c;
    final steps = <(String, double)>[
      ('x1', Space.x1),
      ('x2', Space.x2),
      ('x4', Space.x4),
      ('x6', Space.x6),
      ('x8', Space.x8),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, value) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    name,
                    style: DsType.caption.copyWith(color: c.textMuted),
                  ),
                ),
                Container(width: value, height: 16, color: c.primary.primary),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buttons(BuildContext context) {
    return Wrap(
      spacing: Space.x2,
      runSpacing: Space.x2,
      children: [
        DsButton(label: '결제하기', onPressed: () {}),
        DsButton(
            label: '취소',
            variant: DsButtonVariant.secondary,
            onPressed: () {},),
        DsButton(
            label: '저장', variant: DsButtonVariant.tonal, onPressed: () {},),
        DsButton(
            label: '더보기', variant: DsButtonVariant.ghost, onPressed: () {},),
        DsButton(
            label: '삭제',
            variant: DsButtonVariant.destructive,
            onPressed: () {},),
        DsButton(label: '진행중', loading: true, onPressed: () {}),
        const DsButton(label: '비활성', onPressed: null),
      ],
    );
  }

  Widget _fields(BuildContext context) {
    return const Column(
      children: [
        DsTextField(label: '이메일', hint: 'name@example.com'),
        SizedBox(height: Space.x4),
        DsTextField(
          label: '비밀번호',
          status: DsFieldStatus.error,
          helper: '8자 이상 입력해 주세요.',
        ),
      ],
    );
  }

  Widget _cards(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        DsCard.list(
          onTap: () {},
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.surfaceInset,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Text('리스트 카드 항목',
                    style: DsType.body.copyWith(color: c.text),),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.x4),
        DsCard(
          child: Text('섹션 카드 콘텐츠',
              style: DsType.body.copyWith(color: c.text),),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final c = context.c;
    Widget thumb() => Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: c.surfaceInset,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        );
    return DsCard(
      padding: EdgeInsets.zero,
      child: DsList(
        children: [
          DsListItem(
            title: '방문 예약',
            subtitle: '2026년 7월 2일 오후 2시',
            leading: thumb(),
            trailing: Icon(Icons.chevron_right, color: c.textSubtle),
            onTap: () {},
          ),
          DsListItem(
            title: '추모관 안내',
            subtitle: '운영 시간 09:00–18:00',
            leading: thumb(),
            trailing: Icon(Icons.chevron_right, color: c.textSubtle),
            onTap: () {},
          ),
          DsListItem(
            title: '고객센터',
            subtitle: '평일 09–18시',
            leading: thumb(),
          ),
        ],
      ),
    );
  }

  Widget _chips(BuildContext context) {
    return Wrap(
      spacing: Space.x2,
      runSpacing: Space.x2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DsChip(label: '전체', onTap: () {}),
        DsChip(label: '예약', selected: true, onTap: () {}),
        DsChip(label: '안내', leading: Icons.info_outline, onTap: () {}),
        const DsBadge(label: '진행중', tone: DsBadgeTone.info),
        const DsBadge(label: '완료', tone: DsBadgeTone.success),
        const DsBadge(label: '대기', tone: DsBadgeTone.warning),
        const DsBadge(label: '취소', tone: DsBadgeTone.danger),
        const DsTag(label: '추모공원'),
        const DsCountBadge(count: 5),
        const DsCountBadge(count: 128),
      ],
    );
  }

  Widget _states(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          height: 240,
          child: DsCard(
            padding: EdgeInsets.zero,
            child: DsStateView.empty(message: '아직 등록된 항목이 없습니다.'),
          ),
        ),
        const SizedBox(height: Space.x4),
        SizedBox(
          height: 280,
          child: DsCard(
            padding: EdgeInsets.zero,
            child: DsStateView.error(onRetry: () {}),
          ),
        ),
      ],
    );
  }

  Widget _bottomSheet(BuildContext context) {
    return DsButton(
      label: '바텀 시트 열기',
      variant: DsButtonVariant.tonal,
      onPressed: () => _openSheet(context),
    );
  }

  void _openSheet(BuildContext context) {
    unawaited(
      showDsBottomSheet<void>(
        context: context,
        builder: (sheetContext) {
          final c = sheetContext.c;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('옵션 선택', style: DsType.title3.copyWith(color: c.text)),
              const SizedBox(height: Space.x4),
              DsButton(
                label: '확인',
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bottomNav(BuildContext context) {
    return DsCard(
      padding: EdgeInsets.zero,
      child: DsBottomNav(
        selectedIndex: _navIndex,
        onTap: (index) => setState(() => _navIndex = index),
        items: const [
          DsNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: '홈',
          ),
          DsNavItem(icon: Icons.event_outlined, label: '예약', badgeCount: 3),
          DsNavItem(
            icon: Icons.receipt_long_outlined,
            label: '계약',
          ),
          DsNavItem(icon: Icons.person_outline, label: '내정보'),
        ],
      ),
    );
  }

  Widget _images(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 96, child: DsImage(url: null)),
        SizedBox(width: Space.x4),
        Expanded(child: DsImage(url: '', aspectRatio: 16 / 9)),
      ],
    );
  }

  Widget _dialogs(BuildContext context) {
    return Wrap(
      spacing: Space.x2,
      runSpacing: Space.x2,
      children: [
        DsButton(
          label: '확인 다이얼로그',
          variant: DsButtonVariant.tonal,
          onPressed: () => _openDialog(context),
        ),
        DsButton(
          label: '삭제 다이얼로그',
          variant: DsButtonVariant.destructive,
          onPressed: () => _openDialog(context, destructive: true),
        ),
      ],
    );
  }

  void _openDialog(BuildContext context, {bool destructive = false}) {
    unawaited(
      showDsDialog(
        context: context,
        title: destructive ? '계약을 삭제할까요?' : '예약을 확정할까요?',
        message: destructive ? '삭제한 계약은 복구할 수 없습니다.' : '확정 후에는 변경이 어려울 수 있습니다.',
        confirmLabel: destructive ? '삭제' : '확인',
        variant: destructive
            ? DsDialogVariant.destructive
            : DsDialogVariant.confirm,
      ),
    );
  }

  Widget _snackbars(BuildContext context) {
    return Wrap(
      spacing: Space.x2,
      runSpacing: Space.x2,
      children: [
        DsButton(
          label: '성공',
          variant: DsButtonVariant.tonal,
          onPressed: () => showDsSnackbar(
            context: context,
            message: '저장되었습니다.',
            tone: DsSnackTone.success,
          ),
        ),
        DsButton(
          label: '정보 + 액션',
          variant: DsButtonVariant.tonal,
          onPressed: () => showDsSnackbar(
            context: context,
            message: '예약이 임시 저장되었습니다.',
            actionLabel: '실행취소',
            onAction: () {},
          ),
        ),
        DsButton(
          label: '오류',
          variant: DsButtonVariant.tonal,
          onPressed: () => showDsSnackbar(
            context: context,
            message: '저장에 실패했습니다.',
            tone: DsSnackTone.error,
          ),
        ),
      ],
    );
  }
}
