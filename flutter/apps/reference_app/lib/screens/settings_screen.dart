import 'package:app_kit/app_kit.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:reference_app/app.dart';

/// Settings tab. A scrollable list of settings rows; wrapped in [ChromeScroll]
/// so scrolling here also drives the shared chrome show/hide.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = <(IconData, String, String)>[
      (Icons.notifications_outlined, '알림', '푸시 알림 설정'),
      (Icons.lock_outline, '개인정보', '데이터 및 권한'),
      (Icons.palette_outlined, '테마', '라이트 모드'),
      (Icons.help_outline, '도움말', '자주 묻는 질문'),
      (Icons.info_outline, '버전 정보', '0.1.0'),
    ];

    return ChromeScroll(
      controllerProvider: appChromeProvider,
      child: ListView(
        padding: const EdgeInsets.all(Space.x4),
        children: [
          DsCard(
            padding: EdgeInsets.zero,
            child: DsList(
              children: [
                for (final (icon, title, subtitle) in items)
                  DsListItem(
                    title: title,
                    subtitle: subtitle,
                    leading: Icon(icon, color: c.textMuted),
                    trailing: Icon(Icons.chevron_right, color: c.textSubtle),
                    onTap: () {},
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.x6),
          for (var i = 0; i < 12; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x3),
              child: DsCard.list(
                child: Text(
                  '추가 설정 ${i + 1}',
                  style: DsType.body.copyWith(color: c.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
