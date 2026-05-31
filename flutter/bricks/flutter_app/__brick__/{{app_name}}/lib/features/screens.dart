import 'package:app_kit/app_kit.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:{{app_name}}/app.dart';
{{#tabs}}

/// {{label}} 탭. ds 컴포넌트만 사용하는 최소 화면. [ChromeScroll]로 감싸 공용
/// 크롬(앱바·바텀내비)의 스크롤 표시/숨김을 구동한다. 실제 기능은 별도
/// `mason make feature` 슬라이스로 채워 넣는다.
class {{key.pascalCase()}}Screen extends StatelessWidget {
  const {{key.pascalCase()}}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ChromeScroll(
      controllerProvider: appChromeProvider,
      child: ListView(
        padding: const EdgeInsets.all(Space.x4),
        children: [
          Text(
            '{{label}}',
            style: DsType.title1.copyWith(color: c.text),
          ),
          const SizedBox(height: Space.x4),
          DsCard(
            child: Text(
              '{{label}} 화면입니다. 여기에 기능을 채워 넣으세요.',
              style: DsType.body.copyWith(color: c.text),
            ),
          ),
          const SizedBox(height: Space.x6),
          for (var i = 0; i < 8; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x3),
              child: DsCard.list(
                child: Text(
                  '{{label}} 항목 ${i + 1}',
                  style: DsType.body.copyWith(color: c.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}{{/tabs}}
