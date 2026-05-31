import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Full-screen detail route pushed on the root navigator. The shell is not in
/// the tree here, so there is no bottom nav (the chrome policy for `/detail`
/// also sets `showBottomNav: false`). This screen owns its own [DsAppBar] with
/// a back affordance (sub-screen rule).
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          DsAppBar(
            title: '상세',
            onBack: () => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Space.x4),
              children: [
                DsCard(
                  child: Text(
                    '이 화면은 루트 내비게이터에 푸시된 풀스크린 상세입니다. '
                    '바텀 내비게이션은 보이지 않습니다.',
                    style: DsType.body.copyWith(color: c.text),
                  ),
                ),
                const SizedBox(height: Space.x4),
                DsButton(
                  label: '닫기',
                  variant: DsButtonVariant.secondary,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
