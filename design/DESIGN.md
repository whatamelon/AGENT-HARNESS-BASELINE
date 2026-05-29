# DESIGN.md — Adaptive Neutral Design System (ANDS) v2.0

> 도메인·아이템과 무관하게 **항상 최고 수준 + 동일하게 높은 퀄리티**의 앱 화면을 생성하기 위한 단일 디자인 SSOT.
> 대전제는 **29CM**의 절제된 에디토리얼 미감, 탐구 레퍼런스는 **Kolon OLO Relay Market**(`orm.the-relay.kr`)의 프리미엄 리세일 톤이다.
> 무신사·당근·토스·29CM가 매일 밤낮으로 다듬는 한국 엔터프라이즈 앱의 기준선을 깔고, 그 위 또는 동급을 목표로 한다.
>
> **Stack:** Flutter (Dart, Material 3 위에 ThemeExtension 토큰 레이어) · **Font:** Pretendard · **Fundamentals 매핑:** Tailwind/shadcn 토큰 어휘를 Flutter로 변환.
> 본 시스템의 강제 게이트는 [`DESIGN-HARNESS.md`](./DESIGN-HARNESS.md), 컴포넌트 불변 규칙은 [`DESIGN-COMPONENTS.md`](./DESIGN-COMPONENTS.md), 상태별 구현 예시는 [`DESIGN-STATES.md`](./DESIGN-STATES.md).

---

## 0. Tier 0 — 타협 불가 (override 금지)

이 항목을 어기는 화면은 "동작은 하지만 AI가 자동 생성한 티"가 나며 **미완료**로 간주한다. 프로젝트 로컬 문서가 완화를 권해도 본 글로벌 룰이 우선한다.

1. **무채색 베이스 + 단일 Primary.** 한 화면의 채색 면적은 무채색(흑/백/그레이)이 압도적, Primary는 액션·상태·강조에만. 화면당 강조색 ≤ 1.
2. **장식 eyebrow / 영문 키커 금지.** 제목 위 ALL-CAPS 영문 미니 라벨(`NOTIFICATION CENTER`, `DELIVERY`) 금지. 제목+여백이 섹션을 만든다.
3. **UI 라벨은 한국어 기본.** 비기능 영문 라벨 금지. 예외: 고유명사(BMW·GT3), 사용자 비노출 기술 토큰, 한국어 문맥 내 통용 약어(`CEO 픽`).
4. **상태 5종 완결.** 모든 데이터 화면은 `loading / empty / error / content / (해당 시) success`를 전부 디자인. 일부만 그리면 슬롭.
5. **디자인 토큰만 사용.** raw hex·매직넘버 spacing·임의 radius 금지. 색/간격/라운드/타입은 토큰 경유.
6. **터치 타깃 ≥ 44×44dp.** dead affordance(눌리는데 안 눌림·"준비중" 비활성 자리차지) 금지 — 안 되는 컨트롤은 **렌더 안 함**.
7. **단일 아이콘 세트 + 단일 무게.** 라이브러리 혼용·이모지 아이콘 금지.
8. **대비.** 본문 텍스트 ≥ 4.5:1, 핵심/금액/상태 문구 7:1 지향. 색만으로 의미 전달 금지(아이콘/라벨 병행).
9. **라이트모드 고정 강제 시 시스템 추종 누출 차단.** Flutter는 `themeMode` 단일 소스로 강제(웹 잔재 `prefers-color-scheme` 누출 패턴은 [light-mode 3-layer 룰] 참조).
10. **모달 남용 금지.** 선택·필터는 인라인 expand 또는 바텀시트. 풀스크린 모달은 파괴/확인 액션 한정. 모달 위 모달 금지.

---

## 1. Visual Theme & Atmosphere

### Design direction

- **Category:** 도메인 무관 범용 — 커머스·라이프스타일·예약·금융·콘텐츠·B2B 운영툴 어디에도 자연스럽게 안착.
- **Mood:** 조용한 프리미엄. 절제·정밀·여백·신뢰. 화려함이 아니라 "잘 정돈된 고급".
- **Density:** 모바일은 **여백 우선 + 콘텐츠 hero**. 정보는 카드로 그룹핑하되 한 화면에 미션 하나.
- **Personality:** 에디토리얼하고 단정. 절대 귀엽거나 장식적이거나 과하지 않다.
- **Metaphor:** 잘 편집된 매거진/셀렉트샵 — 제품·콘텐츠가 주인공, UI는 액자.

### Visual language

- **무채색 캔버스 + 콘텐츠/이미지가 색을 책임진다.** UI 크롬은 흑·백·그레이로 비우고, 사진·썸네일이 화면의 색채를 만든다(29CM 핵심).
- **Hairline first.** 구획은 그림자가 아니라 1px(혹은 0.5px) 디바이더와 여백으로. 그림자는 떠 있는 표면(시트/스낵바/팝오버)에만.
- **각진 절제된 라운드.** 과한 pill·둥근 카드 지양. 버튼/카드 8–12dp, 시트 상단 20dp.
- **타이포로 위계.** 큰 제목과 충분한 여백이 디자인을 만든다. 장식 대신 크기·굵기·자간.
- **모션은 오리엔테이션과 피드백 용도.** 엔터테인먼트용 무한 애니메이션 금지.

### Design philosophy

- 모든 화면은 답한다: **여기가 어디인지 · 무엇을 보는지 · 다음 행동이 무엇인지 · 결과가 어떻게 됐는지.**
- 폴리시는 spacing·typography·contrast·상태완결성에서 나온다. 그라데이션·이펙트로 때우지 않는다.
- **재사용 우선.** 새 컴포넌트 만들기 전에 같은 패턴이 다른 화면에 있는지 먼저 본다. 일관성이 곧 완성도.

---

## 2. Color Palette & Roles

색은 **의미와 정보**다. 토큰 역할을 보존하고 값은 프로젝트가 override 가능하되, Tier 0(무채색 베이스 + 단일 Primary)은 깨지 않는다.

### 2.1 Neutral ramp (시스템의 뼈대)

순수에 가까운 중립 그레이. 모든 텍스트·표면·보더의 출처.

| Token | Light | Dark | Role |
|---|---|---|---|
| `neutral/0` | `#FFFFFF` | `#0B0B0C` | 최상위 캔버스 / 카드 베이스 |
| `neutral/50` | `#FAFAFA` | `#0F0F11` | 페이지 배경(앱 셸) |
| `neutral/100` | `#F4F4F5` | `#161618` | 보조 표면, 섹션 그룹 배경 |
| `neutral/150` | `#ECECEE` | `#1C1C1F` | 입력 well, 인셋 표면 |
| `neutral/200` | `#E4E4E7` | `#26262A` | 기본 보더 / 디바이더 |
| `neutral/300` | `#D4D4D8` | `#34343A` | 강조 보더, 선택 외곽 |
| `neutral/400` | `#A1A1AA` | `#52525B` | 비활성 아이콘, 미세 보더 |
| `neutral/500` | `#8E8E93` | `#71717A` | placeholder, 캡션 보조 |
| `neutral/600` | `#6B6B70` | `#A1A1AA` | 보조 텍스트(muted) |
| `neutral/700` | `#48484C` | `#C4C4C9` | 강조 보조 텍스트 |
| `neutral/800` | `#2C2C30` | `#E4E4E7` | 부제/강조 본문 |
| `neutral/900` | `#1A1A1D` | `#F2F2F4` | 부제 |
| `neutral/ink` | `#111114` | `#FAFAFA` | **Primary 텍스트(거의 흑)** |

> 다크에서 ramp는 반전된 역할로 매핑된다(예: `neutral/600`이 라이트의 muted, 다크에선 더 밝은 값). 표는 "역할 → 라이트값/다크값"으로 읽는다.

### 2.2 Semantic surface/text tokens (앱이 직접 참조)

| Token | Light | Dark | Role |
|---|---|---|---|
| `bg` | `#FFFFFF` | `#0B0B0C` | 앱 기본 배경 |
| `bg-subtle` | `#FAFAFA` | `#0F0F11` | 섹션/리스트 배경 |
| `surface` | `#FFFFFF` | `#161618` | 카드·시트·다이얼로그 |
| `surface-alt` | `#F4F4F5` | `#1C1C1F` | 보조 카드, 칩 배경 |
| `surface-inset` | `#ECECEE` | `#0F0F11` | 입력 well, 코드/메타 |
| `border` | `#E4E4E7` | `#26262A` | hairline 보더/디바이더 |
| `border-strong` | `#D4D4D8` | `#34343A` | 활성/선택 보더 |
| `text` | `#111114` | `#FAFAFA` | 기본 본문 |
| `text-muted` | `#6B6B70` | `#A1A1AA` | 보조 텍스트 |
| `text-subtle` | `#9E9EA4` | `#71717A` | 캡션·placeholder·메타 |
| `text-on-primary` | *auto* | *auto* | Primary 위 텍스트(2.3 계약) |
| `overlay` | `rgba(17,17,20,.45)` | `rgba(0,0,0,.6)` | 시트/모달 백드롭 |

### 2.3 Adaptive Primary — "어느 색을 넣어도 자연스럽다"의 계약

Primary는 **주입형(seed)**이다. 기본값은 무채색 ink. 어떤 hue를 넣어도 화면이 무너지지 않게 하는 6개 불변식:

| Token | 정의 | 기본값(ink seed) |
|---|---|---|
| `primary` | 주입된 seed (브랜드색) | `#111114` |
| `primary-pressed` | seed를 OKLCH lightness −6~8% | `#000000` |
| `primary-soft` | seed @ 10–12% alpha over surface | `rgba(17,17,20,.10)` |
| `primary-border` | seed @ 24% alpha (선택 외곽) | `rgba(17,17,20,.24)` |
| `on-primary` | 자동 산출 텍스트색 | `#FFFFFF` |
| `focus-ring` | seed @ 40% alpha, 2dp | `rgba(17,17,20,.40)` |

**불변식 (Tier 0 §1과 함께 강제):**

1. **면적 제한.** Primary 채색 면적은 화면의 ~10% 이하. 큰 채색 배경은 단 하나의 메인 CTA / 선택된 탭 / 진행바에만.
2. **on-primary 자동.** `on-primary = relativeLuminance(primary) < 0.5 ? neutral/0 : neutral/ink`. "흰 글자 고정"이 아니라 "읽히는 액션 텍스트".
3. **무채색과 페어링.** Primary는 항상 중립 위에 단독으로. 채도 높은 색 둘이 경쟁 금지.
4. **시맨틱 우선.** success/danger/warning/info의 의미 영역에서는 Primary가 그 자리를 양보한다(예: 결제 완료=success 초록, Primary 아님).
5. **soft는 배경, solid는 액션.** 선택 행·활성 칩 배경엔 `primary-soft`, 실제 CTA에만 `primary` solid.
6. **대비 자동 검증.** 주입 시점에 `on-primary` 대비를 계산해 4.5:1 미달이면 lightness를 보정(harness가 강제).

> Flutter 구현: `ColorScheme.fromSeed(seedColor:)`로 톤 팔레트를 얻되, 위 6 토큰은 ThemeExtension `AppColors`에 명시 보관해 Material 기본 매핑의 과채색을 차단한다(§9).

### 2.4 Semantic state colors (의미 고정 — Primary와 무관)

| Token | Light | Dark | 용도 |
|---|---|---|---|
| `info` | `#2E6FF2` | `#5B8DEF` | 정보·중립 안내 |
| `success` | `#16A34A` | `#34D399` | 완료·검증·성공 |
| `warning` | `#E08600` | `#F59E0B` | 주의·확인 필요 |
| `danger` | `#E5342B` | `#F87171` | 파괴·오류 |
| `*-soft` | 각 색 @ 10–14% alpha | 동일 | 상태 배경(뱃지/배너) |

### Color usage rules

- 화면당 Primary 1개. info(파랑)는 중립 정보 전용이며 CTA와 경쟁하지 않는다.
- red는 파괴/오류에만. 평상시 강조에 red를 쓰지 않는다.
- 색만으로 상태 전달 금지 — 항상 아이콘 또는 라벨 동반.
- foreground/background 페어는 **라이트·다크 둘 다** 계산 대비를 검증. 한쪽에서 안전하다고 가정 금지.
- `bg: text` + `color: white` 같은 의미 반전 금지(테마 전환 시 깨짐).

---

## 3. Typography Rules — Pretendard

한글·영문·숫자가 한 폰트에서 균형 잡히는 **Pretendard**가 본 시스템의 단일 텍스트 폰트다.

### 3.1 Font

```
Primary: Pretendard (Variable 권장: PretendardVariable)
Fallback: -apple-system(SF Pro/Apple SD Gothic Neo), Roboto, "Noto Sans KR", sans-serif
Mono (옵션, 금액 정렬·코드·ID): "Pretendard"의 tabular figures 또는 system mono
```

> Pretendard는 Google Fonts에 없다. Flutter는 폰트 에셋 번들 + `pubspec.yaml` 선언이 필수다(§9.3).

### 3.2 Type scale (모바일 기준 / sp 단위)

| Role | Size | Line height | Weight | Tracking | 용도 |
|---|---:|---:|---:|---:|---|
| `display` | 32–40 | 1.12 | 700 | −0.03em | 온보딩·프로모 hero (드묾) |
| `title-1` | 26–28 | 1.20 | 700 | −0.025em | 페이지 대제목 |
| `title-2` | 22 | 1.25 | 700 | −0.02em | 섹션 제목 |
| `title-3` | 18–20 | 1.30 | 600 | −0.02em | 카드/그룹 제목 |
| `body-lg` | 16 | 1.55 | 400/500 | −0.01em | 본문 강조 |
| `body` | 15 | 1.55 | 400 | −0.01em | 기본 본문 |
| `body-sm` | 14 | 1.50 | 400 | 0 | 보조 본문·리스트 메타 |
| `label` | 13 | 1.40 | 500/600 | 0 | 버튼·탭·칩 라벨 |
| `caption` | 12 | 1.35 | 500 | 0 | 메타·타임스탬프·뱃지 |
| `micro` | 11 | 1.30 | 600 | +0.01em | 카운트·미세 라벨(남용 금지) |

### Typography rules

- **자간(tracking).** 한글 큰 제목은 음수 자간(−0.02~−0.03em)으로 조여야 프리미엄해 보인다. 본문은 −0.01em~0.
- **숫자는 tabular.** 금액·수량·타임스탬프·카운트는 고정폭 숫자로 정렬 흔들림 제거. 금액은 우측 정렬.
- **한 카드 안 텍스트 크기 ≤ 3종.** 위계는 크기보다 굵기·색으로 먼저 잡는다.
- **줄 길이.** 본문 가독 폭은 한 줄 한국어 기준 너무 길지 않게(모바일은 화면폭, 태블릿/웹은 ~38em).
- **숫자 포맷.** 천단위 콤마 + `원`, 상대시간(`3분 전`), raw 출력 금지.
- 제목 위 장식 eyebrow 금지(Tier 0 §2).

---

## 4. Component Stylings (요약 — 전체 헌장은 DESIGN-COMPONENTS.md)

### Buttons

| Variant | Style | 비고 |
|---|---|---|
| Primary | `primary` solid, `on-primary` 텍스트, radius 10–12dp, 높이 48–52dp | 결정 영역당 1개 |
| Secondary | `surface` + `border`, `text` | 보조 액션 |
| Tonal | `surface-alt` 배경, `text`, 보더 없음 | 위계 중간 |
| Ghost | 투명, `text-muted` | 인라인/저강도 |
| Destructive | `danger` solid 또는 `danger` 텍스트+보더 | 카피로 파괴 의도 확인 |

- 라벨은 동사형: "결제하기", "예약 확정", "저장", "신청". 영문 라벨 금지.
- 비동기 액션은 누른 즉시 비활성 + 스피너(중복 제출 차단). 상태 예시는 DESIGN-STATES.md.
- 최소 터치 44dp. Primary는 secondary보다 시각적으로 분명히 우위.

### Cards & sheets

- 카드 = `surface` + `1px border` (그림자 기본 없음). radius 12dp(중첩 카드 8dp).
- 패딩: 컴팩트 12 / 표준 16–20 / hero 24–32dp.
- **카드 종류 2종으로 제한:** ① 컴팩트 가로형(썸네일 좌 + 정보 우, 리스트용) ② 풀블리드 hero(페이지 1장).
- 카드 안 카드 금지. 모바일 카드는 press 피드백 필수(opacity/scale 0.98).
- 바텀시트: 상단 radius 20dp, grabber, 드래그+백드롭+뒤로가기로 닫힘, 키보드 avoid.

### Inputs & forms

- `surface` 또는 `surface-inset`, 1px border, radius 8–10dp, 높이 48dp.
- Focus: 2dp `focus-ring` + `border-strong`. 라벨은 항상 위 또는 floating(placeholder를 라벨 대용 금지).
- 검증 메시지는 필드 하단 + 복구 방법 포함. 에러는 `danger`, 보더+아이콘+텍스트 3중 신호.

### Lists

- 컴팩트 행(썸네일 ~96–112dp + 정보), 1스크린 핵심 항목 3+.
- 일관된 hairline 디바이더. 무한스크롤/페이지네이션 구현. skeleton/empty/error 필수.
- 가로 스크롤(칩/캐러셀)은 풀블리드 + content padding(부모 거터 음수 마진).

### Navigation

- 바텀 탭 ≤ 5. 현재 위치 시각 지속. 탭 루트엔 뒤로가기 없음.
- sub 화면 앱바 = 제목 + 뒤로가기. 우상단 액션 ≤ 1(실제 동작하는 기능만).
- 스크롤 방향 동기 show/hide. safe-area 준수.

### Badges & chips

- pill(999dp) 또는 6–8dp radius, 라벨 12–13sp. 색+텍스트 병행(`결제완료`, `배송중`).
- 색만 있는 dot 단독 금지(라벨/툴팁 동반).

---

## 5. Layout Principles

### Spacing scale (4dp 베이스)

| Token | dp | 용도 |
|---|---:|---|
| `space/1` | 4 | 아이콘-텍스트 미세 간격 |
| `space/2` | 8 | 인라인 그룹, 칩 내부 |
| `space/3` | 12 | 컴팩트 필드/카드 간격 |
| `space/4` | 16 | 기본 컴포넌트 패딩, 화면 좌우 거터 |
| `space/5` | 20 | 카드 패딩, 그룹 간격 |
| `space/6` | 24 | 섹션 간격 |
| `space/8` | 32 | 주요 섹션 패딩 |
| `space/10` | 40 | 페이지 섹션 갭 |
| `space/12` | 48 | hero/프로모 갭 |

- **화면 좌우 거터 = 16–20dp** 고정(앱 전체 일관). 풀블리드 이미지/캐러셀만 거터 무시.
- 세로 리듬: 섹션 사이 24–32dp, 카드 사이 8–12dp.

### Grid & containers

- 모바일 1열 기본, 2열은 그리드 상품/썸네일에 한정.
- 태블릿/웹 확장 시 reading content 폭 제한(과도한 stretch 금지), 대시보드는 다열.
- 본문 좌측 정렬 고정. center 정렬은 empty/온보딩 hero에만.

### Hierarchy

1. 페이지 제목 + 핵심 상태/가격.
2. 메인 액션(단일 CTA).
3. 콘텐츠/근거.
4. 보조 액션·메타.

### Whitespace

- 결정·파괴 액션 주변엔 여백을 비운다.
- 떠다니는 고아 컨트롤 금지 — 컨트롤은 영향 대상 옆에.
- 한 페이지 한 미션. 여러 톤(hero+저널+룩북+CTA) 섞기 금지.

---

## 6. Depth & Elevation

그림자는 **떠 있는 표면**에만. 평상시 깊이는 hairline + 표면 대비로.

| Token | Light value | 용도 |
|---|---|---|
| `elevation/0` | 그림자 없음, `1px border` | 카드·기본 표면 |
| `elevation/1` | `0 1px 2px rgba(0,0,0,.04)` | 살짝 뜬 칩/누른 카드 |
| `elevation/2` | `0 4px 16px rgba(0,0,0,.08)` | 바텀시트·팝오버·드롭다운 |
| `elevation/3` | `0 8px 32px rgba(0,0,0,.12)` | 다이얼로그·스낵바·FAB |

### Depth rules

- 그림자 + 보더 + ring 동시 사용 금지(하나만).
- 다크모드는 그림자 대신 표면 밝기 단차로 깊이 표현.
- 2단계 초과 중첩 그림자 금지. blur 40+/elevation 24 같은 과한 그림자 금지.

---

## 7. Motion

| Token | Duration | Curve(Flutter) | 용도 |
|---|---:|---|---|
| `motion/fast` | 120ms | `Curves.easeOutCubic` | 탭 피드백, 토글, 칩 |
| `motion/base` | 180ms | `Curves.easeOutCubic` | 화면 내 전환, expand |
| `motion/slow` | 280ms | `Curves.easeOutQuart` | 시트/다이얼로그 진입 |
| `motion/page` | 300ms | `Curves.easeOutQuart` | 라우트 전환 |

- 탭 반응 < 100ms 체감(옵티미스틱 업데이트 + 햅틱).
- 무한/장식 애니메이션 금지(로딩 인디케이터 예외).
- `MediaQuery.disableAnimations`(reduced motion) 존중 — 모션 0 또는 페이드만.
- hover/press가 레이아웃을 밀지 않게(transform/opacity만, 박스 크기 변경 금지).

---

## 8. Do's & Don'ts

### Do

- 시맨틱 토큰만 사용. 상태 전이를 분명히(pending → 진행 → 완료/실패).
- 간결한 동사 라벨 + 근거 지향 카피(가격·수량·상태·시각 명시).
- 모든 데이터 화면에 loading/empty/error/content/success.
- 키보드/포커스/스크린리더 라벨 포함. 가능하면 골든/스크린샷으로 시각 검증.
- 새 패턴 만들기 전 동일 패턴 재사용.

### Don't

- 실제 브랜드 DESIGN.md를 그대로 복제 금지(영감으로만).
- 여러 영감 브랜드를 한 화면에 섞기 금지(병합 시스템 먼저 정의).
- 핵심 정보에 저대비 회색 텍스트 금지.
- "문제가 발생했습니다" 같은 뭉뚱그린 에러로 실패 숨기기 금지.
- 위계/여백으로 풀 문제를 장식 그라데이션으로 때우기 금지.
- **IRON LAW — 장식 eyebrow 금지** (Tier 0 §2).
- **IRON LAW — 비기능 영문 UI 라벨 금지** (Tier 0 §3).

---

## 9. Flutter 구현 — Material 3 위 토큰 레이어

Flutter 기본 `ColorScheme`/`ThemeData`만으로는 본 시스템의 무채색 절제가 깨진다(Material 기본 톤이 과채색). **`ColorScheme.fromSeed`로 베이스를 얻되, 본 시스템 토큰은 ThemeExtension에 명시 보관**해서 컴포넌트가 직접 참조한다.

### 9.1 토큰 ThemeExtension (요지)

```dart
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg, bgSubtle, surface, surfaceAlt, surfaceInset;
  final Color border, borderStrong;
  final Color text, textMuted, textSubtle;
  final Color primary, primaryPressed, primarySoft, primaryBorder, onPrimary, focusRing;
  final Color info, success, warning, danger;
  const AppColors({ /* ... */ });

  /// Adaptive Primary 계약(§2.3): 어떤 seed를 넣어도 on-primary 대비 보장.
  factory AppColors.light({Color primary = const Color(0xFF111114)}) {
    final onPrimary = _readableOn(primary);          // luminance < .5 ? white : ink
    return AppColors(
      bg: const Color(0xFFFFFFFF),
      surface: const Color(0xFFFFFFFF),
      surfaceAlt: const Color(0xFFF4F4F5),
      border: const Color(0xFFE4E4E7),
      text: const Color(0xFF111114),
      textMuted: const Color(0xFF6B6B70),
      textSubtle: const Color(0xFF9E9EA4),
      primary: primary,
      primaryPressed: _darken(primary, .07),
      primarySoft: primary.withOpacity(.10),
      primaryBorder: primary.withOpacity(.24),
      onPrimary: onPrimary,
      focusRing: primary.withOpacity(.40),
      info: const Color(0xFF2E6FF2),
      success: const Color(0xFF16A34A),
      warning: const Color(0xFFE08600),
      danger: const Color(0xFFE5342B),
      // ... 나머지 ramp
    );
  }
  // copyWith / lerp 구현 필수(ThemeExtension 계약)
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}
```

### 9.2 spacing / radius / type 토큰

```dart
abstract class Space { static const x1=4.0,x2=8.0,x3=12.0,x4=16.0,x5=20.0,x6=24.0,x8=32.0,x10=40.0,x12=48.0; }
abstract class Radii { static const sm=8.0, md=12.0, lg=16.0, sheet=20.0, full=999.0; }
abstract class Dur { static const fast=Duration(milliseconds:120), base=Duration(milliseconds:180), slow=Duration(milliseconds:280); }

TextTheme pretendardTextTheme(Color ink, Color muted) => TextTheme(
  displaySmall: TextStyle(fontSize:34, height:1.12, fontWeight:FontWeight.w700, letterSpacing:-1.0, color:ink),
  titleLarge:   TextStyle(fontSize:26, height:1.20, fontWeight:FontWeight.w700, letterSpacing:-0.6, color:ink),
  titleMedium:  TextStyle(fontSize:22, height:1.25, fontWeight:FontWeight.w700, letterSpacing:-0.4, color:ink),
  titleSmall:   TextStyle(fontSize:18, height:1.30, fontWeight:FontWeight.w600, letterSpacing:-0.3, color:ink),
  bodyLarge:    TextStyle(fontSize:16, height:1.55, fontWeight:FontWeight.w400, color:ink),
  bodyMedium:   TextStyle(fontSize:15, height:1.55, fontWeight:FontWeight.w400, color:ink),
  bodySmall:    TextStyle(fontSize:14, height:1.50, fontWeight:FontWeight.w400, color:muted),
  labelLarge:   TextStyle(fontSize:13, height:1.40, fontWeight:FontWeight.w600, color:ink),  // 버튼
  labelSmall:   TextStyle(fontSize:12, height:1.35, fontWeight:FontWeight.w500, color:muted),
);
```

### 9.3 ThemeData 조립 + Pretendard 번들

```yaml
# pubspec.yaml — Pretendard는 Google Fonts 미제공 → 에셋 번들 필수
flutter:
  fonts:
    - family: Pretendard
      fonts:
        - asset: assets/fonts/Pretendard-Regular.otf
        - asset: assets/fonts/Pretendard-Medium.otf
          weight: 500
        - asset: assets/fonts/Pretendard-SemiBold.otf
          weight: 600
        - asset: assets/fonts/Pretendard-Bold.otf
          weight: 700
```

```dart
ThemeData buildTheme({Color seed = const Color(0xFF111114)}) {
  final colors = AppColors.light(primary: seed);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light)
      .copyWith(surface: colors.surface, onSurface: colors.text, outlineVariant: colors.border);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    scaffoldBackgroundColor: colors.bg,
    colorScheme: scheme,
    textTheme: pretendardTextTheme(colors.text, colors.textMuted),
    splashFactory: InkSparkle.splashFactory,   // 절제된 잉크
    extensions: [colors],
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 1),
    // 컴포넌트 테마(Filled/Outlined/Text Button, Input, Card, BottomSheet)는 DESIGN-COMPONENTS.md
  );
}
// 라이트 강제: MaterialApp(themeMode: ThemeMode.light, theme: buildTheme(), darkTheme: buildThemeDark())
```

### 9.4 Flutter 위젯 규칙 (ui-ux-pro-max flutter 스택)

- **`ColorScheme`/토큰 경유.** `Colors.blue` 같은 개별 상수 직접 사용 금지(`context.c.primary`).
- **위젯 트리 얕게.** 10+ 중첩 금지. 깊으면 위젯/메서드로 추출.
- **Column/Row 우선**, 단순 세로 리스트에 Stack 금지.
- 긴 리스트는 `ListView.builder`/`Sliver`로 lazy. 이미지 `cacheWidth`/`FadeInImage`로 점프 방지.
- 상태관리 일관(프로젝트 선택: Riverpod/Bloc 등). 본 시스템은 비종속.

---

## 10. Responsive Behavior

| Name | Width | 동작 |
|---|---:|---|
| Phone | `< 600dp` | 1열, 하단 안전 액션, 44dp 터치 |
| Tablet | `600–1023dp` | 2열 전환, 사이드 패널 가능, reading 폭 제한 |
| Desktop/Web | `>= 1024dp` | 다열 그리드, 좌측 내비, 본문 폭 캡 |

- Primary 액션은 가로 스크롤 없이 항상 도달 가능.
- 텍스트 확대(150%/200%)에서 가로 오버플로 없음 — 긴 카피/식별자는 wrap.
- 테이블은 모바일에서 카드화하거나 데이터 무결성이 필요할 때만 가로 스크롤.
- safe-area(노치/홈 인디케이터) 항상 준수.

---

## 11. Agent Prompt Guide

### UI 작업 표준 프롬프트

> `DESIGN.md`(ANDS)와 `DESIGN-COMPONENTS.md`·`DESIGN-STATES.md`를 따른다. 29CM급 절제된 무채색 프리미엄 모바일 UI. Pretendard 타입 스케일·4dp 스페이싱·hairline 깊이·단일 Primary. loading/empty/error/content/success/disabled/long-content 상태를 전부 커버. 라이트·다크 둘 다 대비 4.5:1↑ 검증, 골든/스크린샷 근거 제시. Tier 0(무채색 베이스·장식eyebrow금지·한국어라벨·상태완결·토큰only·44dp·단일아이콘세트) 준수.

### 작업 전 컨텍스트 요약(필수)

- 제품 목표:
- 핵심 사용자/액션:
- 화면/컴포넌트:
- 주입 Primary seed(있으면):
- 활성 토큰/기존 컴포넌트:
- 제약:
- 검증 계획(골든/대비/상태):

### Quick token reference

- 베이스: 무채색 ramp. Primary: 주입형(기본 ink `#111114`), 면적 ≤10%.
- Radius: 버튼/인풋 8–12, 카드 12, 시트 20dp.
- Spacing: 4dp 스케일, 화면 거터 16–20dp.
- Font: Pretendard. 큰 제목 음수 자간(−0.02~−0.03em), 숫자 tabular.
- Mood: 조용한 프리미엄, 에디토리얼. 장식·과채색 금지.

### 레퍼런스 활용

1. 29CM = 절제·여백·콘텐츠 hero·무채색의 대전제.
2. Kolon OLO Relay(`orm.the-relay.kr`) = 프리미엄 리세일/셀렉트 톤 탐구 대상.
3. 공개 브랜드는 영감 재료일 뿐, 그대로 복제하지 않는다.
4. 영감을 본 시스템에 병합할 때 접근성·상태완결·토큰 규칙을 보존한다.

---

## 12. 동반 문서

| 문서 | 역할 |
|---|---|
| [`DESIGN-COMPONENTS.md`](./DESIGN-COMPONENTS.md) | 컴포넌트 불변 헌장 — anatomy·variant·규칙·금지 |
| [`DESIGN-STATES.md`](./DESIGN-STATES.md) | 컴포넌트 상태별 예시 — Flutter 코드 + 카피 규칙 |
| [`DESIGN-HARNESS.md`](./DESIGN-HARNESS.md) | 강제 게이트 — Tier0 lock·slop 검출·토큰 lint·골든·a11y |

> 본 4종은 `~/.config/agent-harness-baseline/design/`의 글로벌 SSOT다. 수정 후 `bash bin/sync-attest.sh`로 Claude Code·Codex 링크 동기화를 인증한다.
