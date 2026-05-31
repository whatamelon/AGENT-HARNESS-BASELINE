import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:example_app/features/reservation/presentation/reservation_controller.dart';

/// Reservation 화면.
///
/// AppShell 탭 루트로 쓰려면 `ChromeScroll`로 감싸고 `appChromeProvider`를
/// 전달하세요(앱의 app.dart 참고). 풀스크린 서브 라우트면 자체 `DsAppBar`를
/// 둡니다. 라우트 등록 스니펫은 파일 하단 주석을 보세요.
class ReservationScreen extends ConsumerWidget {
  const ReservationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final state = ref.watch(reservationControllerProvider);

    if (state.isLoading) {
      return const Center(child: DsStateView.loading());
    }
    if (state.error != null) {
      return Center(
        child: DsStateView.error(
          message: state.error,
          onRetry: () => ref
              .read(reservationControllerProvider.notifier)
              .load(),
        ),
      );
    }
    if (state.items.isEmpty) {
      return const Center(child: DsStateView.empty());
    }

    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        DsCard(
          padding: EdgeInsets.zero,
          child: DsList(
            children: [
              for (final item in state.items)
                DsListItem(
                  title: item.title,
                  onTap: () {},
                ),
            ],
          ),
        ),
      ],
    );


  }
}

// ── 라우트 등록 ────────────────────────────────────────────────────────────
// 탭 브랜치로 추가하려면 app.dart 의 `appBranches` 에:
//
//   ShellBranch(
//     path: '/reservation',
//     navItem: const DsNavItem(
//       icon: Icons.list_outlined,
//       selectedIcon: Icons.list,
//       label: 'Reservation',
//     ),
//     builder: (context) => const ReservationScreen(),
//   ),
//
// 그리고 앱의 ChromeResolver switch 에 정책을, `appRouteWhitelist`
// 의 allowedPrefixes 에 '/reservation' 을 추가하세요.
//
// 풀스크린 서브 라우트면 app.dart 의 buildAppRouter `extraRoutes` 에:
//
//   GoRoute(
//     path: '/reservation',
//     parentNavigatorKey: rootKey,
//     builder: (context, state) => const ReservationScreen(),
//   ),
