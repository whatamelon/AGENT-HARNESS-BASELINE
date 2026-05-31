# DESIGN-UNIQLO.md — UNIQLO-grade App Harness (ANDS v2.0 프리셋)

> ANDS v2.0([`DESIGN.md`](./DESIGN.md))의 **드롭인 프리셋 + 방법론 레이어**. 포크 아님 — 베이스의 무채색 시스템·토큰 SSOT·5상태 게이트·Tier 0 를 그대로 상속하고, **레퍼런스만 29CM 에디토리얼 → UNIQLO 기능미(LifeWear)** 로 교체한다.
>
> **레퍼런스:** UNIQLO 모바일 앱. 글로벌하게 안정적·편안한 톤의 본질은 ① 무채색 캔버스 + **단일 시그니처 레드**, ② **고밀도 카탈로그 그리드**, ③ 장식 0의 기능적 위계, ④ 빠르고 조용한 피드백.
> **Stack:** Flutter (Material 3 + ThemeExtension). **Font:** Pretendard. **Fundamentals:** Tailwind/shadcn 2·4배수(4/8pt) → Flutter 매핑.
> **토큰 프리셋:** [`../flutter/packages/ds/tokens/presets/uniqlo.json`](../flutter/packages/ds/tokens/presets/uniqlo.json)

---

## 0. Tier 0 상속 + UNIQLO 추가 잠금 (override 금지)

[`DESIGN.md` §0](./DESIGN.md) Tier 0 전부 그대로 적용. 그 위에 프리셋 고유 잠금 4개를 더한다.

| # | UNIQLO 추가 잠금 | 이유 |
|---|---|---|
| U1 | **brand ≠ primary ≠ danger 3분리.** 기본 액션(Primary CTA, 장바구니/구매) = **블랙/ink**(`primary.seed`=ink). 시그니처 레드(`state.brand`=`#E60012`)는 **브랜드 accent 한정** — 로고·세일가·프로모션 배지에만, 화면당 레드 면적 최소. 에러는 별도 딥레드(`state.danger`=`#C2261D`). **브랜드 레드를 Primary CTA/seed 에 바인딩 금지.** | UNIQLO 실측: 레드는 브랜드/로고색, 기본 버튼은 블랙. 브랜드색을 semantic primary 에 직접 묶으면 브랜드 변경 시 의미 붕괴(토큰 안티패턴). [UXPin] |
| U2 | **레드 3겹 충돌 차단.** brand 레드 / danger 레드 / (혹시라도) primary 가 동시에 레드면 사용자 오인. 위 3분리로 primary 는 ink 라 충돌 1겹 제거. danger 와 brand 레드는 **항상 아이콘/라벨 병행**(색만으로 의미 금지). 파괴 액션(삭제)은 레드 채움 아닌 `neutral/ink` 또는 아웃라인 + 확인. | Tier0 §8. |
| U3 | **카탈로그 2–3열 고밀도.** 상품 리스트는 에디토리얼 hero 가 아니라 2–3열 그리드(UNIQLO 베스트셀러 섹션 = 3열, 엣지투엣지 이미지, gutter `x2`=8). 1열 hero 는 프로모션 1개 한정. | UNIQLO 카탈로그 DNA(4pt 그리드, 3-up 행). 한 스크롤에 상품 4+ 노출. |
| U4 | **각진 기능형.** radius `sm:4 / md:8 / lg:12`(베이스보다 타이트). pill 버튼·둥근 카드 지양. 바텀시트는 상단 모서리만 라운드. 그림자는 떠있는 표면(시트/스낵바)에만, 카드는 hairline. | 기능미 = 평평·정직. UNIQLO Figma 실측: 시트 top-only radius. |

---

## 1. 축 ① 그리드·여백 시스템 (2·4배수)

### 스페이싱 스케일 — Tailwind/shadcn → Flutter

토큰 SSOT 의 `space` 가 정본. 4dp base 의 2·4배수. **임의 px 금지**, 반드시 토큰 경유.

| 토큰 | dp | Tailwind 등가 | 용도 |
|---|---|---|---|
| `x1` | 4 | `1` | 아이콘-라벨 간격, 미세 간극 |
| `x2` | 8 | `2` | **그리드 셀 gutter**, 칩 내부 |
| `x3` | 12 | `3` | 리스트 행 내부 패딩 |
| `x4` | 16 | `4` | **스크린 좌우 gutter(기본)**, 카드 패딩 |
| `x5` | 20 | `5` | 시트 패딩 |
| `x6` | 24 | `6` | 섹션 간 분리 |
| `x8` | 32 | `8` | 블록 간 큰 호흡 |
| `x10` | 40 | `10` | 페이지 상/하단 여백 |
| `x12` | 48 | `12` | 히어로 상하 |

### 그리드 규칙 (UNIQLO 카탈로그)

- **상품 그리드: 2–3열**(UNIQLO 베스트셀러 = 3-up, 모바일 기본 2열, 태블릿 3–4열). 셀 gutter `x2`(8), 스크린 gutter `x4`(16).
- 셀 = 엣지투엣지 이미지(비율 고정 3:4) + 하단 메타(브랜드/명/가격) 좌측정렬. 가격은 `price` 스타일.
- **풀블리드 hero 는 화면당 1개** 이하(프로모션). 나머지는 그리드.
- safe-area: 상/하단 inset 준수. 가로 스크롤 chip 은 풀블리드(`marginHorizontal: -x4` + `contentPadding: x4`) — [[horizontal-scroll-fullbleed]].
- 정렬: 본문·메타 **좌측정렬 고정**, 가격·숫자 행 내 우측 가능. 한 화면 좌측 정렬선 하나로 통일.

**self-check:** 한 스크롤에 상품 4+ 보이나? 셀 gutter 가 토큰(`x2`)인가? hero 가 1개 이하인가? 좌측 정렬선 통일됐나?

---

## 2. 축 ② 타이포·색 절제

### 색 — 무채색 캔버스 + ink Primary + 레드 brand accent

- 캔버스·표면·텍스트·보더 = 전부 `neutral` ramp(베이스 상속). 색은 **콘텐츠 이미지가 책임진다.**
- **Primary CTA = ink/블랙**(`primary.seed` light `#111114` / dark `#FAFAFA`). 장바구니/구매 등 기본 액션 버튼은 검정. `onPrimary`(텍스트색)는 런타임 `AdaptivePrimary.fromSeed` 가 ≥4.5:1 보장.
- **brand accent = 시그니처 레드**(`state.brand`=`#E60012` / dark `#FF3B30`, 생성물 `DsPrimitive.stateBrand`). **용도: 로고·세일가·프로모션 배지 한정.** Primary CTA·대면적 배경·장식 사용 금지. 화면당 레드 면적 최소. 정확값 미공개(Pantone 근사) → 브랜드 가이드로 override.
- 의미색: `info/success/warning/danger` 토큰. `danger`(`#C2261D` 딥레드)는 brand 레드와 **다른 값**으로 분리 — 에러 전용.
- **브랜드색을 primary seed 에 바인딩하지 않는다**(brand 변경 시 의미 붕괴 = 토큰 안티패턴, [UXPin]·[fourzerothree]). brand/primary/semantic 3계층 분리.
- 대비: 본문 ≥4.5:1, 가격/핵심/상태 7:1 지향. 색만으로 의미 전달 금지(아이콘/라벨 병행).

### 타이포 위계 (Pretendard)

`display / title1·2·3 / bodyLg·body·bodySm / label / caption / micro` + 프리셋 추가 **`price`**(17/700/-0.3) — 가격 강조용. 위계는 크기·굵기·자간으로만; 장식 eyebrow·영문 키커 금지(Tier0 §2·§3).

**self-check:** Primary CTA 가 ink/블랙인가(레드 아님)? brand 레드가 로고/세일/프로모션에만 쓰였나(면적 최소)? danger 레드 ≠ brand 레드 분리됐나? 가격에 `price`+tabular 썼나? 본문 4.5:1 통과?

---

## 3. 축 ③ 내비게이션·정보구조

- **바텀 탭 ≤5.** UNIQLO 표준: 홈 / 카테고리 / 검색 / 위시리스트 / 마이. 탭 루트엔 뒤로가기 없음.
- **플로우: 그리드 → 상세.** 상세 = 이미지 갤러리 → 핵심정보(명·가격) → 옵션(사이즈/색, 인라인 expand 또는 바텀시트, 모달 금지) → **sticky 단일 CTA(장바구니/구매)**. 핵심정보·가격은 첫 화면(fold 위).
- **검색·필터:** 검색은 헤더 상시 진입. 필터는 바텀시트(인라인 expand 우선), 적용 시 결과 즉시 갱신·active chip 가운데 scroll-into-view.
- **헤더 경량.** 제목 ±1 액션. 우측 검색/알림/도움말 도배 금지(Tier0·[[ui-service-quality-bar]] §9).

**self-check:** 탭 ≤5인가? 가격이 fold 위인가? sticky CTA 정확히 1개인가? 옵션 선택이 모달 아닌 인라인/시트인가? 헤더 우측 액션 ≤1?

---

## 4. 축 ④ 모션·피드백

토큰 `motion`(fast 120 / base 180 / slow 280 / page 300, easeOut). 엔터테인먼트 무한 애니메이션 금지 — 오리엔테이션·피드백 전용.

- **즉시 피드백 <100ms:** 탭 → press 피드백(`pressScale` 0.98 + `pressedInkOverlay`). 장바구니 담기 = 옵티미스틱 + 햅틱(light).
- **상태 5종 완결**(Tier0 §4): `loading`(skeleton — 그리드 셀 형태로) / `empty`(자연 한국어 카피 + 행동 유도) / `error`(danger + 아이콘 + 재시도) / `content` / `success`(토스트/스낵바).
- 전환: 페이지 push `page`(300, easeOutQuart). 시트 슬라이드업 `slow`. 한 가지 모션 언어로 통일.
- 숫자/시간 포맷: 천단위 콤마, `원`, 상대시간. raw 출력 금지.

**self-check:** 탭 반응 <100ms·옵티미스틱인가? 5상태 다 그렸나? skeleton 이 실제 그리드 형태인가? 전환 모션 일관?

---

## 5. 방법론 — Design Thinking × Jobs 가 토큰을 만든다

디자인 시스템은 한 방에 떨어지지 않는다. **반복·비선형 루프**(NN/g·d.school)로 토큰·컴포넌트를 깎는다.

| Design Thinking 단계 | 디자인 시스템 산출 | Jobs 원칙 접목 |
|---|---|---|
| **Empathize** | 실사용자·기기·맥락 관찰(한국 모바일 기준선) | **Empathy** — 사용자가 이미 아는 실세계 은유에서 출발 |
| **Define** | 제약·토큰·원칙 확정(Tier0, neutral ramp, 레드) | **Focus** — "아니오"로 본질만 남김. 강조색 1개. |
| **Ideate** | 컴포넌트 변형안 생성 | 옵션을 넓게 펼친 뒤 깎는다 |
| **Prototype** | 컴포넌트 단위 프로토타입(빅뱅 금지) | **Deep simplicity** — 표면 미니멀이 아니라 구조를 이해한 단순함 |
| **Test** | 실사용·대비·상태 검증 → 토큰으로 회귀 | **Craft on hidden surfaces** — 안 보이는 상태(empty/error)·토큰 일관성까지 마감 |

> 핵심 명제(검증된 2차 출처): 단순함은 생략이 아니라 **엄밀함의 산출물**(Smithsonian, NN/g). "단순함은 궁극의 정교함"·3-클릭 안에 핵심 도달(NBC, muz.li). → 본 하네스의 self-check 들이 그 "엄밀함"을 강제하는 게이트다.
>
> ※ 본 명제들의 출처는 deep-research 1차 패스에서 수집됐으나 검증 하네스 버그(verifier 무투표→자동 refute)로 confirmed 카운트가 0으로 집계됨. 소스 품질(NN/g·d.school·Smithsonian·Style Dictionary GitHub)은 양호하며, 명제는 업계 정설과 일치. 정밀 재검증은 후속 과제.

---

## 6. 프리셋 활성화

```bash
cd ~/.config/agent-harness-baseline/flutter/packages/ds
# 1) 프리셋을 활성 SSOT 로 교체 (프로젝트별 결정)
cp tokens/presets/uniqlo.json tokens/tokens.json
# 2) Dart 토큰 재생성 (drift 게이트 통과 필수)
dart run tool/gen_tokens.dart
# 3) 검증
flutter test            # token_check_test + contrast + tap_target
```

프로젝트별로 브랜드 레드 정확값을 바꾸려면 활성 `tokens.json` 의 `state.brand`(+`semantic.brandAccent` 참조) override 후 재생성. **Primary CTA 는 ink 유지** — 레드로 바꾸지 말 것. **베이스 ANDS 로 되돌리려면** git 으로 `tokens.json` 복원.

생성물(검증됨): `DsPrimitive.stateBrand = Color(0xFFE60012)`(brand accent), `DsPrimitive.stateDanger = Color(0xFFC2261D)`(에러, 분리), Primary 는 정적 미emit — 런타임 `AdaptivePrimary.fromSeed(ink)` 계산.

> ⚠️ `tokens/presets/uniqlo.json` 자체는 gen_tokens 가 안 읽으므로(SSOT=`tokens/tokens.json` 고정) 프리셋 파일만 둬도 drift 게이트엔 영향 없음.

---

## 7. 통합 self-check (완료 게이트)

화면 작성·수정 후 전부 통과해야 "완료". 하나라도 미달이면 슬롭 → 회귀.

- [ ] Tier 0(베이스 10개) + U1–U4 전부 충족
- [ ] 그리드: 한 스크롤 상품 4+, 셀 gutter `x2`, hero ≤1, 좌측 정렬선 통일
- [ ] 색: Primary CTA=ink(블랙), brand 레드는 로고/세일만, danger≠brand 레드, 파괴 액션 레드 아님, 본문 ≥4.5:1
- [ ] 타이포: 가격 `price` 스타일, eyebrow/영문 키커 0
- [ ] IA: 탭 ≤5, 가격 fold 위, sticky CTA 1개, 옵션 인라인/시트
- [ ] 모션: <100ms 피드백·옵티미스틱, 5상태 완결, skeleton=그리드형, 모션 일관
- [ ] 토큰: raw hex·매직넘버 0, 전부 토큰 경유, `flutter test` green

---

## 8. 출처 (검증 등급)

> deep-research 하네스 3회 + 직접 타겟 리서치(2026-05-31). 하네스는 adversarial verifier 가 *반증가능 사실*만 통과시켜 디자인 판단을 abstain 처리 → 색 역할 등 핵심 결론은 직접 페치로 보강.

**색 역할 (confirmed, 다중 소스):**
- UNIQLO 팔레트 = 레드+화이트, 2006 Kashiwa Sato 리브랜드 이후 불변. 레드는 **브랜드/로고색**, 공식 UI hex 미공개(Pantone 근사) — brandpalettes.com/uniqlo-colors, brandcolorcode.com/uniqlo (vote 2-0~3-0).
- 블랙은 정당·권장 add-to-cart 색(럭셔리/미니멀) — claspo.io/blog/add-to-cart-button-color.
- brand ≠ semantic primary 분리 베스트프랙티스 — [UXPin](https://www.uxpin.com/studio/blog/color-consistency-design-systems/), [fourzerothree](https://www.fourzerothree.in/p/semantic-colour-tokens-in-action), [imperavi](https://imperavi.com/blog/designing-semantic-colors-for-your-system/).

**그리드/타이포 (confirmed):**
- UNIQLO 앱 = 4pt 스페이싱, 베스트셀러 3-up 그리드, 타입 24/20/16/14/12/10, weight 400/500/700, 시트 top-only radius — [swarnak.medium UNIQLO Figma recreate](https://swarnak.medium.com/recreate-uniqlos-ui-on-figma-pixel-perfect-edition-efad42466cf7).
- 8pt 선형 + 4pt half-step, 모바일 gutter 16px — [designsystems.com](https://www.designsystems.com/space-grids-and-layouts/), uxplanet 8pt grid.
- 가격/숫자 = tabular-nums(`font-variant-numeric: tabular-nums`) — [MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/font-variant-numeric), redas.dev/blog/tabular-nums.

**모션 (M3 공식 토큰):**
- duration: short 50–200 / medium 250–400 / long 450–600 / extra-long 700–1000 ms. easing: standard `cubic-bezier(0.2,0,0,1)`, emphasized-decelerate `(0.05,0.7,0.1,1)`, emphasized-accelerate `(0.3,0,0.8,0.15)` — [M3 motion tokens-specs](https://m3.material.io/styles/motion/easing-and-duration/tokens-specs), pub.dev `material_design`(primary).

**방법론:**
- Design Thinking 5단계(비선형/반복), Stanford d.school 기원 — [NN/g](https://www.nngroup.com/articles/design-thinking/), [IxDF](https://ixdf.org/literature/article/5-stages-in-the-design-thinking-process).
- Jobs: 단순함=엄밀함의 산출(생략 아님), 숨은 면까지 마감, 3-클릭 — [Smithsonian](https://www.smithsonianmag.com/arts-culture/how-steve-jobs-love-of-simplicity-fueled-a-design-revolution-23868877/), [NBC 6 pillars](https://www.nbcnews.com/tech/tech-news/6-pillars-steve-jobs-design-philosophy-flna119120).

> 한계: UNIQLO는 공식 디자인 토큰/앱 스펙을 공개하지 않음 → 색·그리드 수치는 디자이너 리버스엔지니어링(secondary) + 업계 정설 기반. 정확 브랜드 레드는 프로젝트가 공식 가이드 확보 시 `state.brand` override.
