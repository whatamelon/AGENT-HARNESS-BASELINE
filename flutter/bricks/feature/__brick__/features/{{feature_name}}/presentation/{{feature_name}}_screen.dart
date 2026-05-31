{{#is_list}}import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:{{package_name}}/features/{{feature_name}}/presentation/{{feature_name}}_controller.dart';

/// {{feature_name.titleCase()}} 화면 (list archetype).
///
/// 컬렉션을 DsList 로 렌더하고 로딩/빈/에러 3상태를 `AsyncValue.when` 으로
/// 빠짐없이 분기합니다. 에러 상태는 retry 어포던스를 노출합니다.
///
/// AppShell 탭 루트로 쓰려면 `ChromeScroll` 로 감싸고 `appChromeProvider` 를
/// 전달하세요(앱의 app.dart 참고). 풀스크린 서브 라우트면 자체 `DsAppBar` 를
/// 둡니다. 라우트 등록 스니펫은 파일 하단 주석을 보세요.
class {{feature_name.pascalCase()}}Screen extends ConsumerWidget {
  const {{feature_name.pascalCase()}}Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch({{feature_name.camelCase()}}ControllerProvider);

    return async.when(
      loading: () => const Center(child: DsStateView.loading()),
      error: (error, _) => Center(
        child: DsStateView.error(
          message: error is Exception ? error.toString() : null,
          onRetry: () => ref.invalidate({{feature_name.camelCase()}}ControllerProvider),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: DsStateView.empty());
        }
        return ListView(
          padding: const EdgeInsets.all(Space.x4),
          children: [
            DsCard(
              padding: EdgeInsets.zero,
              child: DsList(
                children: [
                  for (final item in items)
                    DsListItem(
{{#with_domain}}                      title: item.title,
{{/with_domain}}{{^with_domain}}                      title: item,
{{/with_domain}}                      onTap: () {},
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
{{/is_list}}{{#is_detail}}import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:{{package_name}}/features/{{feature_name}}/presentation/{{feature_name}}_controller.dart';

/// {{feature_name.titleCase()}} 상세 화면 (detail archetype).
///
/// 단수 엔티티를 헤더 → 본문(DsCard) 위계로 보여주고, 하단에 **단일** sticky
/// CTA(DsButton) 하나만 둡니다(글로벌 슬롭룰: 결정 영역당 CTA 1개). 로딩/에러
/// 상태는 `AsyncValue.when` 으로 분기합니다.
///
/// 풀스크린 서브 라우트가 기본입니다. 자체 `DsAppBar` 를 두려면 Scaffold 로
/// 감싸세요. 라우트 등록 스니펫은 파일 하단 주석을 보세요.
class {{feature_name.pascalCase()}}Screen extends ConsumerWidget {
  const {{feature_name.pascalCase()}}Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch({{feature_name.camelCase()}}ControllerProvider);

    return async.when(
      loading: () => const Center(child: DsStateView.loading()),
      error: (error, _) => Center(
        child: DsStateView.error(
          message: error is Exception ? error.toString() : null,
          onRetry: () => ref.invalidate({{feature_name.camelCase()}}ControllerProvider),
        ),
      ),
      data: (entity) {
        if (entity == null) {
          return const Center(child: DsStateView.empty());
        }
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Space.x4),
                children: [
{{#with_domain}}                  Text(
                    entity.title,
                    style: DsType.title1.copyWith(color: c.text),
                  ),
{{/with_domain}}{{^with_domain}}                  Text(
                    '{{feature_name.titleCase()}}',
                    style: DsType.title1.copyWith(color: c.text),
                  ),
{{/with_domain}}                  const SizedBox(height: Space.x4),
                  DsCard(
                    child: Text(
{{#with_domain}}                      entity.id,
{{/with_domain}}{{^with_domain}}                      entity,
{{/with_domain}}                      style: DsType.body.copyWith(color: c.text),
                    ),
                  ),
                ],
              ),
            ),
            // ── sticky 단일 CTA (결정 영역당 1개) ─────────────────────────
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Space.x4),
                child: DsButton(
                  label: '확인',
                  onPressed: () {},
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
{{/is_detail}}{{#is_form}}import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:{{package_name}}/features/{{feature_name}}/presentation/{{feature_name}}_controller.dart';

/// {{feature_name.titleCase()}} 입력 화면 (form archetype).
///
/// 멀티필드 폼: DsTextField 들 + 필드별 검증 status(normal/error/success) +
/// 제출. 제출 액션은 `Result` 를 반환하므로 화면은 성공/실패를 명시적으로
/// 처리합니다. 제출 중에는 CTA 가 inline 로딩으로 바뀝니다.
///
/// 풀스크린 서브 라우트가 기본입니다. 필드 키/검증 규칙은 컨트롤러에서
/// 정의하세요. 라우트 등록 스니펫은 파일 하단 주석을 보세요.
class {{feature_name.pascalCase()}}Screen extends ConsumerWidget {
  const {{feature_name.pascalCase()}}Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final state = ref.watch({{feature_name.camelCase()}}ControllerProvider);
    final controller = ref.read({{feature_name.camelCase()}}ControllerProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Space.x4),
            children: [
              Text(
                '{{feature_name.titleCase()}}',
                style: DsType.title1.copyWith(color: c.text),
              ),
              const SizedBox(height: Space.x4),
              for (final field in {{feature_name.pascalCase()}}Controller.fieldKeys) ...[
                DsTextField(
                  label: field,
                  status: state.fieldStatus[field] ?? DsFieldStatus.normal,
                  helper: state.fieldHelper[field],
                  enabled: !state.isSubmitting,
                  onChanged: (value) => controller.updateField(field, value),
                ),
                const SizedBox(height: Space.x4),
              ],
            ],
          ),
        ),
        // ── sticky 단일 제출 CTA ──────────────────────────────────────────
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: DsButton(
              label: '제출',
              loading: state.isSubmitting,
              onPressed: state.isSubmitting ? null : controller.submit,
            ),
          ),
        ),
      ],
    );
  }
}
{{/is_form}}
// ── 라우트 등록 ────────────────────────────────────────────────────────────
// 탭 브랜치로 추가하려면 app.dart 의 `appBranches` 에:
//
//   ShellBranch(
//     path: '/{{feature_name}}',
//     navItem: const DsNavItem(
//       icon: Icons.list_outlined,
//       selectedIcon: Icons.list,
//       label: '{{feature_name.titleCase()}}',
//     ),
//     builder: (context) => const {{feature_name.pascalCase()}}Screen(),
//   ),
//
// 그리고 앱의 ChromeResolver switch 에 정책을, `appRouteWhitelist`
// 의 allowedPrefixes 에 '/{{feature_name}}' 을 추가하세요.
//
// 풀스크린 서브 라우트면 app.dart 의 buildAppRouter `extraRoutes` 에:
//
//   GoRoute(
//     path: '/{{feature_name}}',
//     parentNavigatorKey: rootKey,
//     builder: (context, state) => const {{feature_name.pascalCase()}}Screen(),
//   ),
