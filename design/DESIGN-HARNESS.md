# DESIGN-HARNESS.md — 앱 디자인 시스템 하네스 (ANDS v2.0, Flutter)

> 디자인 품질은 "잘 만들었다"는 주관이 아니라 **통과/실패가 판정되는 게이트**다.
> 기존 웹 하네스(`visual-check.mjs`)의 12개 non-regression 게이트를 Flutter 컨텍스트로 번역하고, [`DESIGN.md`](./DESIGN.md) Tier 0를 자동 강제한다.
> 게이트를 통과 못 한 화면/컴포넌트는 **미완료**다. 작업 종료 전 본 하네스를 돌린다.

## 0. 강제 모델 (3계층)

| 계층 | 시점 | 방식 | 차단성 |
|---|---|---|---|
| **A. Tier-0 lock** | 작성 중·커밋 전 | 정적 분석(grep/`custom_lint`/dart analyze) | `exit ≠ 0` 하드 차단 |
| **B. 골든 + 위젯 테스트** | CI / 작업 종료 전 | `flutter test`(golden + a11y + 상태완결) | CI fail |
| **C. 시각/판단 리뷰** | 머지 전 | 리뷰어/비전 에이전트 + 루브릭 채점 | 명시 리뷰 게이트 |

웹 산출물(있을 경우)은 기존 `getdesign init-harness`의 `visual-check.mjs`를 그대로 사용한다. 본 문서는 **Flutter 모바일 산출물**의 동급 게이트다.

---

## 1. 계층 A — Tier-0 Lock (정적, 하드 차단)

[`DESIGN.md`](./DESIGN.md) §0의 10개 항목을 코드 레벨에서 검출한다. 위반 시 비영점 종료.

### A-1. 토큰 only / raw 값 금지
```bash
# raw hex (토큰/테마 파일 제외)
rg -n --glob 'lib/**/*.dart' --glob '!**/theme/**' --glob '!**/tokens*.dart' \
   '\bColor\(0x[0-9A-Fa-f]{8}\)|Colors\.(red|blue|green|amber|teal|indigo|purple|pink|orange)\b'
# 매직 spacing / 임의 radius (Space.*/Radii.* 미경유)
rg -n --glob 'lib/**/*.dart' 'EdgeInsets\.(all|symmetric|only)\(\s*[0-9]{1,3}\.?[0-9]*\s*[,)]' \
   | rg -v 'Space\.'
rg -n --glob 'lib/**/*.dart' 'BorderRadius\.circular\(\s*[0-9]' | rg -v 'Radii\.'
```
검출 → 토큰(`context.c.*`, `Space.*`, `Radii.*`)으로 치환. 단, `theme/`·`tokens*.dart`·테스트는 제외(SSOT 정의처).

### A-2. 장식 eyebrow / 영문 라벨 (no-design-slop 연동)
```bash
# 제목 위 ALL-CAPS 영문 Text (한글 미포함, 2단어↑ 대문자) — eyebrow 의심
rg -n --glob 'lib/**/*.dart' "Text\(\s*['\"][A-Z][A-Z &/]{4,}['\"]" \
   | rg -v '테스트|//|allowlist'
```
allowlist: 고유명사(BMW/GT3 등), 기술 토큰. 그 외 ALL-CAPS 영문 UI 라벨 → 한국어로.

### A-3. 단일 아이콘 세트 / 이모지 아이콘 금지
- 아이콘 패키지 1종(예: `lucide_icons` 또는 Material `Icons` 중 택1). import 소스 혼용 검출.
- 이모지를 `Text`로 아이콘 대용 → 검출/차단(데코 이모지 범위).

### A-4. dead affordance 금지
- `onPressed: () {}`(빈 핸들러)·`onTap: null` 인데 활성처럼 보이는 컨트롤, `'준비중'`/`'coming soon'` 라벨 검출 → 제거(렌더 안 함).

```bash
rg -n --glob 'lib/**/*.dart' "준비\s*중|coming soon|onPressed:\s*\(\)\s*\{\s*\}"
```

### A-5. 라이트모드 누출 차단
- `MaterialApp`에 `themeMode` 단일 소스 확인. 플랫폼 밝기 직접 분기(`MediaQuery.platformBrightnessOf`)로 강제 우회 패턴 검출.

> 권장: 위 검출을 `tool/design_lint.sh` 한 파일로 묶고 `flutter analyze`와 함께 pre-commit/CI에서 실행.

---

## 2. 계층 B — 골든 + 위젯 테스트 (CI 차단)

### B-1. 상태 완결성 골든 (DESIGN-STATES.md 매트릭스 강제)

각 핵심 컴포넌트는 **상태별 골든 스냅샷**을 가진다. 매트릭스의 `●` 중 스냅샷 누락 = 실패.

```dart
// test/golden/product_card_test.dart
void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final state in ['content', 'loading', 'longContent']) {
      testGoldens('ProductCard $state ${brightness.name}', (tester) async {
        await tester.pumpWidgetBuilder(
          buildProductCard(state),
          wrapper: appThemeWrapper(brightness: brightness, primary: const Color(0xFF111114)),
          surfaceSize: const Size(390, 320),
        );
        await screenMatchesGolden(tester, 'product_card_${state}_${brightness.name}');
      });
    }
  }
}
```

- 라이트·다크 **둘 다** 스냅샷(대비 비회귀).
- Feed/Detail/Form 화면은 loading·empty·error·content 4종 골든 필수.
- `flutter test --update-goldens`로 baseline 갱신, diff는 리뷰.

### B-2. Adaptive Primary 계약 테스트 (§2.3 강제)

어떤 seed를 넣어도 on-primary 대비 ≥ 4.5:1.

```dart
test('on-primary contrast holds for arbitrary seeds', () {
  for (final seed in [0xFF111114, 0xFF2E6FF2, 0xFFE5342B, 0xFFF5C518, 0xFF16A34A, 0xFF8E44AD]) {
    final colors = AppColors.light(primary: Color(seed));
    final ratio = contrastRatio(colors.primary, colors.onPrimary);
    expect(ratio, greaterThanOrEqualTo(4.5), reason: 'seed=${seed.toRadixString(16)}');
  }
});
// contrastRatio = WCAG 상대 휘도 공식. 노란색 seed → onPrimary가 ink로 자동 전환되는지 확인.
```

### B-3. 대비 게이트 (텍스트 4.5:1)
- 토큰 페어(`text`/`bg`, `textMuted`/`surface`, `onPrimary`/`primary`, `*-soft` 위 텍스트)를 라이트·다크 양쪽에서 계산 검증하는 단위 테스트. 핵심/금액 문구는 7:1 지향.

### B-4. 터치 타깃 ≥ 44dp
```dart
testWidgets('interactive targets >= 44dp', (tester) async {
  await tester.pumpWidget(appUnderTest());
  for (final f in find.byWidgetPredicate((w) => w is InkWell || w is GestureDetector).evaluate()) {
    final size = tester.getSize(find.byWidget(f.widget));
    expect(size.height >= 44 && size.width >= 44, isTrue);
  }
});
```

### B-5. 접근성 (a11y) 게이트 — axe의 Flutter 대응
```dart
testWidgets('meets a11y guidelines', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(appUnderTest());
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline)); // 아이콘 버튼 라벨
  handle.dispose();
});
```

### B-6. reduced-motion
- `MediaQueryData(disableAnimations: true)` 컨텍스트에서 펌프 → 무한 애니메이션/shimmer 정지, 전환 0ms 확인.

### B-7. text-zoom / 오버플로
```dart
testWidgets('no overflow at textScale 2.0', (tester) async {
  await tester.pumpWidget(MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
    child: appUnderTest()));
  expect(tester.takeException(), isNull); // RenderFlex overflow → 예외로 검출
});
```
- viewport matrix: 360×640(소형폰)·390×844(폰)·768×1024(태블릿)에서 각각 펌프, 오버플로 0.

---

## 3. 계층 C — 시각/판단 루브릭 (리뷰 게이트)

정적·골든으로 못 잡는 미감/위계/카피는 리뷰어(또는 비전 에이전트)가 머신리더블 루브릭으로 채점한다. **"이 화면을 29CM/토스 PM이 통과시킬까?"** 못 통과할 디테일이면 슬롭.

| Probe | 질문 | fail 조건 | severity |
|---|---|---|---|
| 무채색 지배 | 화면 채색 면적의 주체가 중립인가? | Primary/채도색이 ~10% 초과 점유 | high |
| 위계 | 제목>섹션>카드 타입 램프가 크기·굵기로 드러나나? | 다 같은 무게로 평평 | high |
| 단일 CTA | 결정 영역 Primary 1개 + sticky CTA 1개? | 경쟁 Primary 2+ / 중복 CTA | high |
| 여백 리듬 | 섹션·카드 간격이 토큰 리듬을 따르나? | 불규칙·과밀·붕 뜸 | med |
| 정렬 | 본문 좌측, 금액 우측, 좌측 정렬선 1축 통일? | center 도배 / 정렬선 난립 | med |
| 카피 구체성 | 상태 카피가 의미+행동을 말하나? | "문제 발생"·generic filler·번역체 | high |
| 카드 일관 | 카드 종류 ≤2, radius·padding 동일? | 카드마다 제각각 / 카드 안 카드 | med |
| 깊이 절제 | 그림자가 떠 있는 표면에만, 과하지 않나? | shadow 남발 / border+shadow+ring 동시 | med |
| 상태 완결 | loading/empty/error/content가 다 있나? | 일부 누락 | high |
| 모션 절제 | 모션이 피드백/오리엔테이션 용도인가? | 장식 무한 애니 | med |

high가 하나라도 fail이면 리뷰 게이트 차단. 판정은 `~/.claude/logs/designslop-review.jsonl` 류로 추적 가능.

---

## 4. Attestation (어드민/대규모 작업 시)

대규모 화면 생성·어드민 one-shot은 첫 코드 수정 전 attestation을 남긴다(글로벌 admin-design 룰과 정합):

```json
{
  "design_system": "ANDS@2.0.0",
  "seed_primary": "#111114",
  "loaded_docs": ["DESIGN.md","DESIGN-COMPONENTS.md","DESIGN-STATES.md","DESIGN-HARNESS.md"],
  "tier0_ack": true,
  "gates_planned": ["A-tier0-lint","B-golden","B-a11y","B-contrast","B-touch","C-rubric"],
  "exceptions": [],
  "worker_id": "main"
}
```

---

## 5. 작업 종료 전 체크리스트 (복붙용)

```
[ ] Tier 0 (DESIGN.md §0) 10항목 위반 0
[ ] design_lint.sh / flutter analyze 통과 (raw hex·매직값·eyebrow·dead affordance 0)
[ ] 골든: 핵심 컴포넌트 라이트+다크, 상태(loading/empty/error/content) 스냅샷 존재
[ ] Adaptive Primary: 임의 seed 6종 on-primary 대비 ≥ 4.5:1
[ ] 대비: 본문 4.5:1↑, 금액/핵심 7:1 지향 (라이트·다크 양쪽)
[ ] 터치 타깃 ≥ 44dp / 아이콘 버튼 Semantics 라벨
[ ] reduced-motion: 무한 애니/shimmer 정지
[ ] textScale 2.0 오버플로 0 / 소형폰·폰·태블릿 viewport 통과
[ ] 상태 5종 완결(데이터 화면) + 카피 한국어·구체적(복구 경로 포함)
[ ] 단일 Primary·단일 sticky CTA·무채색 지배 (리뷰 루브릭 high 0)
```

하나라도 미충족이면 **미완료** — 수정 후 재실행.

---

## 6. 설치/실행 메모

- 권장 패키지: `golden_toolkit`(골든 시나리오), `flutter_test`의 `meetsGuideline`(내장 a11y), 선택적 `custom_lint`로 토큰 규칙 lint화.
- 정적 게이트는 `tool/design_lint.sh`로 묶고 CI 잡 분리(룰 `ci-parallelization`: lint/analyze/test/golden 병렬 job).
- 웹 산출물 병행 시 `getdesign init-harness`의 `visual-check.mjs`로 동일 게이트(contrast/responsive/keyboard/axe/reduced-motion/forced-colors/text-zoom/overflow/density/interaction/hierarchy/copy)를 적용.

> 본 하네스는 글로벌 SSOT(`~/.config/agent-harness-baseline/design/`)다. 수정 후 `bash bin/sync-attest.sh`로 동기화 인증.
