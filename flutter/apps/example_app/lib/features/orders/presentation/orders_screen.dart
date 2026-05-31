import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:example_app/features/orders/presentation/orders_controller.dart';

/// Orders 화면.
///
/// AppShell 탭 루트로 쓰려면 `ChromeScroll`로 감싸고 `appChromeProvider`를
/// 전달하세요(앱의 app.dart 참고). 풀스크린 서브 라우트면 자체 `DsAppBar`를
/// 둡니다. 라우트 등록 스니펫은 파일 하단 주석을 보세요.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {


    final c = context.c;
    final count = ref.watch(ordersControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(Space.x4),
      children: [
        Text(
          'Orders',
          style: DsType.title1.copyWith(color: c.text),
        ),
        const SizedBox(height: Space.x4),
        DsCard(
          child: Text(
            '탭한 횟수: $count',
            style: DsType.body.copyWith(color: c.text),
          ),
        ),
        const SizedBox(height: Space.x4),
        DsButton(
          label: '증가',
          leading: Icons.add,
          onPressed: () => ref
              .read(ordersControllerProvider.notifier)
              .increment(),
        ),
      ],
    );

  }
}

// ── 라우트 등록 ────────────────────────────────────────────────────────────
// 탭 브랜치로 추가하려면 app.dart 의 `appBranches` 에:
//
//   ShellBranch(
//     path: '/orders',
//     navItem: const DsNavItem(
//       icon: Icons.list_outlined,
//       selectedIcon: Icons.list,
//       label: 'Orders',
//     ),
//     builder: (context) => const OrdersScreen(),
//   ),
//
// 그리고 앱의 ChromeResolver switch 에 정책을, `appRouteWhitelist`
// 의 allowedPrefixes 에 '/orders' 을 추가하세요.
//
// 풀스크린 서브 라우트면 app.dart 의 buildAppRouter `extraRoutes` 에:
//
//   GoRoute(
//     path: '/orders',
//     parentNavigatorKey: rootKey,
//     builder: (context, state) => const OrdersScreen(),
//   ),
