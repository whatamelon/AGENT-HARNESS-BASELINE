import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reference_app/app.dart';

/// Home tab. Surfaces the P0 diagnostics (flavor + env presence) and exercises
/// two shell behaviours:
/// - long scrollable content so scrolling down hides the chrome (app bar +
///   bottom nav) via [ChromeScroll];
/// - a button that pushes the full-screen `/detail` route on the root
///   navigator, where the chrome policy hides the bottom nav.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final flavor = AppConfig.current;
    final rows = <(String, String)>[
      ('Flavor', flavor.label),
      ('Supabase 설정', AppEnv.hasSupabase ? '있음' : '없음'),
      ('Sentry 설정', AppEnv.hasSentry ? '있음' : '없음'),
    ];

    return ChromeScroll(
      controllerProvider: appChromeProvider,
      child: ListView(
        padding: const EdgeInsets.all(Space.x4),
        children: [
          Text(
            'P0 OK',
            key: const Key('p0-ok'),
            style: DsType.display.copyWith(color: c.text),
          ),
          const SizedBox(height: Space.x6),
          DsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.x2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label, style: DsType.body.copyWith(color: c.text)),
                        Text(
                          value,
                          style: DsType.label.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.x6),
          DsButton(
            label: '상세 화면 열기',
            leading: Icons.open_in_new,
            onPressed: () => context.push(AppRoutes.detail),
          ),
          const SizedBox(height: Space.x6),
          // Filler so the list scrolls and scroll-hide is visible.
          for (var i = 0; i < 20; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x3),
              child: DsCard.list(
                child: Text(
                  '소식 ${i + 1}',
                  style: DsType.body.copyWith(color: c.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
