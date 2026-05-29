# DESIGN-COMPONENTS.md — 앱 디자인 컴포넌트 헌장 (ANDS v2.0)

> [`DESIGN.md`](./DESIGN.md)의 토큰·원칙을 컴포넌트 단위 **불변 계약**으로 고정한다.
> 각 컴포넌트는 `anatomy(구성) → variants(변형) → 규칙(MUST) → 금지(NEVER)` 순서. Flutter 위젯 매핑과 토큰 참조를 명시한다.
> 상태별 시각/코드는 [`DESIGN-STATES.md`](./DESIGN-STATES.md), 강제 검증은 [`DESIGN-HARNESS.md`](./DESIGN-HARNESS.md).

## 헌장 공통 원칙 (모든 컴포넌트 적용)

1. **토큰 only** — 색/간격/라운드/타입은 `context.c.*`, `Space.*`, `Radii.*`, `TextTheme` 경유. raw 값 금지.
2. **44dp 터치** — 인터랙티브 요소의 hit target ≥ 44×44dp(시각 크기와 별개로 `padding`/`GestureDetector` 확장 가능).
3. **상태 완결** — 인터랙티브/데이터 컴포넌트는 default·pressed·disabled·(해당 시)loading을 모두 정의. 데이터 컨테이너는 loading/empty/error/content.
4. **단일 Primary** — Primary는 결정 영역당 1개. 나머지는 중립/tonal.
5. **press 피드백** — 모바일 탭 가능한 모든 표면은 즉각 피드백(`InkWell`/opacity/scale 0.98).
6. **접근성** — 아이콘 단독 버튼엔 `Semantics(label:)`, 폼은 라벨 연결, 색+텍스트/아이콘 병행.

---

## 1. Button

**anatomy:** `[leading icon?] + label(동사) + [trailing icon?]`, 높이 48–52dp, 패딩 가로 16–20dp, radius `Radii.md`(12).

| Variant | 배경 | 텍스트 | 보더 | Flutter |
|---|---|---|---|---|
| Primary | `primary` | `onPrimary` | — | `FilledButton` |
| Secondary | `surface` | `text` | `1px border` | `OutlinedButton` |
| Tonal | `surfaceAlt` | `text` | — | `FilledButton.tonal` |
| Ghost | 투명 | `textMuted` | — | `TextButton` |
| Destructive | `danger` solid 또는 투명+`danger` 텍스트 | `onPrimary`/`danger` | (outline형) `danger` | `FilledButton`/`OutlinedButton` 커스텀 |

**MUST**
- 라벨은 한국어 동사: "결제하기", "예약하기", "저장", "신청하기", "삭제".
- pressed: `primaryPressed`(solid) 또는 `primarySoft` 오버레이. duration `Dur.fast`.
- 비동기: 누른 즉시 `disabled` + 인라인 스피너(라벨 자리 유지, 폭 점프 금지).
- 결정 영역당 Primary 1개. 나머지는 Secondary/Tonal/Ghost.
- focus: 2dp `focusRing`.

**NEVER**
- 영문 장식 라벨("CONFIRM", "GO"), 이모지 라벨.
- 같은 화면에 동급 Primary 2개 경쟁.
- disabled를 단순 회색으로만(커서/시맨틱 `aria/Semantics enabled:false` 병행 — 웹/접근성).
- loading과 disabled를 동일 시각으로 뭉개기.

```dart
FilledButton(
  style: FilledButton.styleFrom(
    backgroundColor: context.c.primary,
    foregroundColor: context.c.onPrimary,
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    textStyle: Theme.of(context).textTheme.labelLarge,
  ),
  onPressed: loading ? null : onPay,
  child: loading
      ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))
      : const Text('결제하기'),
)
```

---

## 2. Text Field / Input

**anatomy:** `라벨(위) + 필드(아이콘?/입력/접미사?) + 헬퍼/에러(아래)`. 필드 높이 48dp, radius `Radii.sm`(8), 패딩 가로 14dp.

| State | 배경 | 보더 |
|---|---|---|
| default | `surfaceInset` | `1px border` |
| focus | `surface` | `2px focusRing` + `borderStrong` |
| error | `surface` | `1.5px danger` |
| disabled | `surfaceAlt` | `1px border` (텍스트 `textSubtle`) |

**MUST**
- 라벨은 항상 표시(필드 위 또는 floating). placeholder는 보조 예시일 뿐 라벨 대용 금지.
- 에러: 보더(`danger`) + 하단 메시지(`danger`) + 아이콘 — 3중 신호. 메시지에 복구 방법 포함("올바른 이메일 형식으로 입력해 주세요").
- 키보드 타입 적합 지정(`TextInputType`), 숫자/금액은 tabular.
- 입력 검증은 시스템 경계에서(클라 즉시 피드백 + 서버 재검증).

**NEVER**
- placeholder만으로 라벨 대체. 에러를 보더 색만으로 표현. 키보드가 필드를 가리는 레이아웃.

---

## 3. Card

**anatomy:** `surface` + `1px border`, radius `Radii.md`(12), 그림자 없음(`elevation/0`).

| Variant | 용도 | 구조 |
|---|---|---|
| List card(컴팩트 가로형) | 리스트 항목 | 썸네일 좌(96–112dp, 비율 고정) + 정보 우(제목/메타/가격) |
| Hero card(풀블리드) | 페이지 1장 | 이미지 풀블리드 + 오버레이/하단 정보 |
| Section card | 그룹 컨테이너 | 헤더(제목+액션?) + 콘텐츠, hairline 디바이더 |

**MUST**
- 카드 종류는 화면당 2종 이내. radius·padding 카드 간 동일.
- 탭 가능 카드는 `InkWell` + press 피드백. 썸네일 비율 고정(`AspectRatio`).
- 가격/금액 우측 정렬, tabular.

**NEVER**
- 카드 안 카드. 카드마다 다른 radius/padding. shadow+border+ring 동시. 풀블리드 hero 남발(1장 한정).

---

## 4. List / ListView

**anatomy:** 컴팩트 행 + hairline 디바이더. 1스크린 핵심 3+.

**MUST**
- `ListView.builder`/Sliver로 lazy. skeleton(loading)/empty/error 상태 구현(DESIGN-STATES.md §4).
- 디바이더 일관(`DividerTheme`, 1px `border`). 항목 간격 규칙적.
- 무한스크롤 또는 페이지네이션. 당겨서 새로고침(`RefreshIndicator`) 적용 시 일관.

**NEVER**
- 거대 카드로 1스크린 1.5개. divider 과함/없음 혼재. 빈 상태 미구현.

---

## 5. Bottom Sheet (모달 대체 1순위)

**anatomy:** 상단 radius `Radii.sheet`(20), grabber(중앙 상단 36×4dp `border`), 콘텐츠, 하단 safe-area + 액션.

**MUST**
- 선택·필터·옵션은 바텀시트 또는 인라인 expand로(풀스크린 모달 금지).
- 드래그 + 백드롭 탭 + 뒤로가기로 닫힘. `showModalBottomSheet(isScrollControlled:true)` + 키보드 avoid.
- `elevation/2` 그림자, 백드롭 `overlay`.

**NEVER**
- 시트 위 시트 중첩. 닫기 X만 제공(제스처/백드롭 없이). 키보드가 입력 가림.

---

## 6. Dialog (파괴/확인 한정)

**anatomy:** `surface`, radius `Radii.lg`(16), `elevation/3`, 제목(title-3) + 본문(body) + 액션(우측 정렬, 취소=Ghost/Secondary, 확정=Primary 또는 Destructive).

**MUST**
- 다이얼로그는 **파괴 액션·중대 확인·차단성 알림**에만. 그 외엔 시트/인라인/스낵바.
- 파괴 확정 버튼 카피에 결과 명시("삭제", "취소하기"). 위험 시 Destructive 변형.

**NEVER**
- 단순 선택을 다이얼로그로. 다이얼로그 위 다이얼로그.

---

## 7. App Bar / Navigation

### Bottom Navigation
**MUST:** 탭 ≤ 5, 현재 탭 시각 지속(`primary` 또는 ink 활성/`textSubtle` 비활성), 라벨 한국어, 스크롤 show/hide 동기. safe-area 하단.
**NEVER:** 탭 6+, 탭 루트에 뒤로가기, dead 탭("준비중").

### App Bar (sub 화면)
**MUST:** 제목(title-3) + 뒤로가기(좌). 우상단 액션 ≤ 1(실제 동작). 배경 `bg`, 스크롤 시 hairline 보더 노출(그림자 대신).
**NEVER:** 검색+알림+도움말 우상단 몰기. 탭 루트에 SubAppBar.

---

## 8. Badge / Chip / Tag

**anatomy:** pill(`Radii.full`) 또는 `Radii.sm`(8), 패딩 가로 8–10/세로 4dp, `caption`/`label` 텍스트.

| Type | 배경 | 텍스트 |
|---|---|---|
| 상태 뱃지 | `*-soft`(success/warning/danger/info) | 해당 색 |
| 중립 태그 | `surfaceAlt` | `textMuted` |
| 선택 칩(active) | `primarySoft` | `primary` + `primaryBorder` 외곽 |
| 카운트 | `primary` 또는 `danger` solid | `onPrimary` |

**MUST:** 색+텍스트 병행(`배송중`, `결제완료`, `마감`). 선택 칩 row는 풀블리드 가로 스크롤 + active scroll-into-view.
**NEVER:** 색만 있는 dot 단독. 칩 row를 부모 거터에 가둬 끊겨 보이게.

---

## 9. Tab Bar (세그먼트/스와이프 탭)

**MUST:** 활성 indicator(2dp `primary` 또는 ink), 비활성 `textMuted`. 가로 스크롤 시 active 가운데 정렬. 본문 좌측 정렬 유지.
**NEVER:** 탭 텍스트 center 도배로 위계 붕괴. indicator 없는 탭.

---

## 10. Snackbar / Toast

**anatomy:** `elevation/3`, radius `Radii.md`, 하단 floating(safe-area + 16dp), 텍스트 + 액션(선택).

**MUST:** 성공/정보/오류를 아이콘+색으로 구분. 액션은 1개("실행 취소", "보기"). 자동 dismiss 3–5초, 오류는 더 길게/수동.
**NEVER:** 토스트로 차단성 확인 대체. 동시 다중 스택.

---

## 11. Image / Thumbnail

**MUST:** 비율 고정(`AspectRatio` 1:1 / 4:5 / 3:4 / 16:9 중 도메인 선택, 앱 내 일관). 로딩 placeholder(`surfaceAlt` + skeleton), 실패 fallback(중립 아이콘). `cacheWidth`로 디코드 최적화.
**NEVER:** 비율 깨짐(stretch). 로딩/실패 상태 없이 raw `Image.network`.

---

## 12. Empty / Error / Loading 컨테이너 (상태 컴포넌트)

데이터를 표시하는 모든 화면이 공유하는 상태 셸. 상세 카피·코드는 DESIGN-STATES.md.

**MUST**
- **loading:** skeleton(콘텐츠 형태 모사) 우선, 불가 시 중앙 스피너. 빈 화면 금지.
- **empty:** 중립 일러스트/아이콘 + 한 줄 설명 + (가능 시) 행동 유도 버튼. "아직 없음"이 무슨 의미인지 설명.
- **error:** 실패를 명명 + 복구 경로("다시 시도", "새로고침"). 뭉뚱그린 메시지 금지.
- **success:** 무엇이 완료됐는지 명시(주문번호/예약시각 등 근거).

---

## 컴포넌트 헌장 위반 = 미완료

위 MUST를 빠뜨리거나 NEVER를 범한 컴포넌트는 PR/작업 완료로 보지 않는다. 검증은 DESIGN-HARNESS.md의 골든 테스트 + slop 검출 + 상태 완결성 게이트로 강제한다.
