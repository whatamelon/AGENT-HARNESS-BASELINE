import 'package:app_kit/app_kit.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:example_app/app.dart';


/// 홈 탭. ds 컴포넌트만 사용하는 최소 화면. [ChromeScroll]로 감싸 공용
/// 크롬(앱바·바텀내비)의 스크롤 표시/숨김을 구동한다. 실제 기능은 별도
/// `mason make feature` 슬라이스로 채워 넣는다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ChromeScroll(
      controllerProvider: appChromeProvider,
      child: ListView(
        padding: const EdgeInsets.all(Space.x4),
        children: [
          Text(
            '홈',
            style: DsType.title1.copyWith(color: c.text),
          ),
          const SizedBox(height: Space.x4),
          DsCard(
            child: Text(
              '홈 화면입니다. 여기에 기능을 채워 넣으세요.',
              style: DsType.body.copyWith(color: c.text),
            ),
          ),
          const SizedBox(height: Space.x6),
          for (var i = 0; i < 8; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x3),
              child: DsCard.list(
                child: Text(
                  '홈 항목 ${i + 1}',
                  style: DsType.body.copyWith(color: c.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 서비스 탭. ds 컴포넌트만 사용하는 최소 화면. [ChromeScroll]로 감싸 공용
/// 크롬(앱바·바텀내비)의 스크롤 표시/숨김을 구동한다. 실제 기능은 별도
/// `mason make feature` 슬라이스로 채워 넣는다.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ChromeScroll(
      controllerProvider: appChromeProvider,
      child: ListView(
        padding: const EdgeInsets.all(Space.x4),
        children: [
          Text(
            '서비스',
            style: DsType.title1.copyWith(color: c.text),
          ),
          const SizedBox(height: Space.x4),
          DsCard(
            child: Text(
              '서비스 화면입니다. 여기에 기능을 채워 넣으세요.',
              style: DsType.body.copyWith(color: c.text),
            ),
          ),
          const SizedBox(height: Space.x6),
          for (var i = 0; i < 8; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x3),
              child: DsCard.list(
                child: Text(
                  '서비스 항목 ${i + 1}',
                  style: DsType.body.copyWith(color: c.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 마이 탭. ds 컴포넌트만 사용하는 최소 화면. [ChromeScroll]로 감싸 공용
/// 크롬(앱바·바텀내비)의 스크롤 표시/숨김을 구동한다. 실제 기능은 별도
/// `mason make feature` 슬라이스로 채워 넣는다.
class MypageScreen extends StatelessWidget {
  const MypageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ChromeScroll(
      controllerProvider: appChromeProvider,
      child: ListView(
        padding: const EdgeInsets.all(Space.x4),
        children: [
          Text(
            '마이',
            style: DsType.title1.copyWith(color: c.text),
          ),
          const SizedBox(height: Space.x4),
          DsCard(
            child: Text(
              '마이 화면입니다. 여기에 기능을 채워 넣으세요.',
              style: DsType.body.copyWith(color: c.text),
            ),
          ),
          const SizedBox(height: Space.x6),
          for (var i = 0; i < 8; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x3),
              child: DsCard.list(
                child: Text(
                  '마이 항목 ${i + 1}',
                  style: DsType.body.copyWith(color: c.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
