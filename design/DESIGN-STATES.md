# DESIGN-STATES.md — 앱 상태별 컴포넌트 예시 (ANDS v2.0)

> 한국 1등 앱과 자동 생성 앱을 가르는 결정적 차이는 **상태 완결성**이다. 동작하는 화면이 아니라 *모든 상태가 디자인된* 화면이 프리미엄이다.
> 본 문서는 컴포넌트별로 `default · pressed · loading · empty · error · success · disabled · long-content`를 Flutter 코드와 카피 규칙으로 예시한다.
> 토큰: [`DESIGN.md`](./DESIGN.md) · 컴포넌트 계약: [`DESIGN-COMPONENTS.md`](./DESIGN-COMPONENTS.md) · 강제: [`DESIGN-HARNESS.md`](./DESIGN-HARNESS.md).

## 상태 매트릭스 (어떤 컴포넌트가 어떤 상태를 가져야 하나)

| 컴포넌트 | default | pressed | loading | empty | error | success | disabled | long-content |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Button | ● | ● | ● | — | ●(인라인) | ●(전환) | ● | ● |
| Text Field | ● | (focus) | — | — | ● | ●(검증통과) | ● | ● |
| List/Feed | ● | (행 press) | ● skeleton | ● | ● | — | — | ● |
| Card | ● | ● | ● skeleton | — | — | — | — | ● |
| Detail 화면 | ● | — | ● skeleton | — | ● | — | — | ● |
| Form 제출 | ● | — | ● | — | ● | ● | ● | ● |
| Image | ● | — | ● placeholder | — | ● fallback | — | — | — |

`●` = 반드시 디자인. `—` = 해당 없음. **빠진 ●가 하나라도 있으면 슬롭(미완료).**

---

## 0. 카피 규칙 (모든 상태 공통)

- **loading:** 무엇을 불러오는지 암시하는 형태(skeleton). 텍스트가 필요하면 "불러오는 중" 류 짧게.
- **empty:** "아직 없음"의 의미 + 다음 행동. 예: "찜한 상품이 없어요 / 마음에 드는 상품을 담아보세요" + [둘러보기].
- **error:** 실패 명명 + 복구. 예: "상품을 불러오지 못했어요 / 네트워크를 확인하고 다시 시도해 주세요" + [다시 시도]. **"문제가 발생했습니다" 금지.**
- **success:** 무엇이 됐는지 근거. 예: "예약이 확정됐어요 · 12월 24일 오후 2시 / 예약번호 A1B2C3".
- 모든 카피 한국어, 장식 영문/eyebrow 금지. 숫자는 천단위 콤마 + 단위 + 상대시간.

---

## 1. Button

```dart
// default / pressed / loading / disabled 를 한 위젯이 처리
class PrimaryButton extends StatelessWidget {
  final String label; final bool loading, enabled; final VoidCallback? onTap;
  const PrimaryButton({super.key, required this.label, this.loading=false, this.enabled=true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final disabled = !enabled || loading;
    return Semantics(
      button: true, enabled: !disabled, label: label,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceAlt,      // disabled ≠ 흐린 primary
          disabledForegroundColor: c.textSubtle,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
          textStyle: Theme.of(context).textTheme.labelLarge,
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(c.onPrimary.withOpacity(.12)), // pressed 잉크
        ),
        onPressed: disabled ? null : onTap,
        child: AnimatedSwitcher(
          duration: Dur.fast,
          // loading: 폭 점프 없이 라벨 자리에 스피너
          child: loading
              ? SizedBox(key: const ValueKey('l'), width:18,height:18,
                  child: CircularProgressIndicator(strokeWidth:2, color:c.onPrimary))
              : Text(label, key: const ValueKey('t')),
        ),
      ),
    );
  }
}
```

- **pressed:** `overlayColor`로 12% 잉크. 레이아웃 이동 없음.
- **loading:** `onPressed:null` + 스피너. 중복 제출 차단(High severity).
- **disabled:** `surfaceAlt` 배경 + `textSubtle` — "흐린 Primary"가 아니라 명백히 비활성. `Semantics(enabled:false)`.
- **error(전환):** 실패 시 버튼 흔들기 금지. 스낵바/필드 에러로 안내, 버튼은 default 복귀.

---

## 2. Text Field — focus / error / 검증통과

```dart
TextField(
  decoration: InputDecoration(
    labelText: '이메일',                       // 라벨 상시
    hintText: 'name@example.com',             // 보조 예시(라벨 대용 아님)
    errorText: error,                          // null이면 정상, 값 있으면 danger 보더+메시지
    suffixIcon: valid ? Icon(Icons.check_circle, color: context.c.success, size:20) : null,
    filled: true,
    fillColor: context.c.surfaceInset,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.sm),
      borderSide: BorderSide(color: context.c.border)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.sm),
      borderSide: BorderSide(color: context.c.borderStrong, width: 2)),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.sm),
      borderSide: BorderSide(color: context.c.danger, width: 1.5)),
  ),
  keyboardType: TextInputType.emailAddress,
)
```

- **error 카피:** 무엇이 왜 틀렸고 어떻게 고치는지. "올바른 이메일 형식이 아니에요". 보더 색만으로 끝내지 않는다.
- **검증통과:** suffix `success` 체크로 확신 제공.
- **long-content:** 긴 입력은 `maxLines`/스크롤, 라벨 wrap.

---

## 3. Card — content / skeleton(loading) / press

```dart
// content
InkWell(
  onTap: onTap, borderRadius: BorderRadius.circular(Radii.md),
  child: Container(
    padding: const EdgeInsets.all(Space.x4),
    decoration: BoxDecoration(
      color: context.c.surface,
      border: Border.all(color: context.c.border),
      borderRadius: BorderRadius.circular(Radii.md)),
    child: Row(children: [
      ClipRRect(borderRadius: BorderRadius.circular(Radii.sm),
        child: AspectRatio(aspectRatio: 1, child: SizedBox(width:96, child: thumb))),
      const SizedBox(width: Space.x4),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: Space.x1),
        Text(meta, style: t.bodySmall),
        const SizedBox(height: Space.x2),
        Text('${price.comma()}원', style: t.titleSmall),  // tabular, 우측 정렬 가능
      ])),
    ]),
  ),
)
```

```dart
// skeleton: 같은 레이아웃 골격을 surfaceAlt 블록 + shimmer(절제)로
Widget skeletonCard(BuildContext c) => Container(
  padding: const EdgeInsets.all(Space.x4),
  child: Row(children: [
    _box(96, 96), const SizedBox(width: Space.x4),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _box(double.infinity, 16), const SizedBox(height: 8),
      _box(120, 14), const SizedBox(height: 12), _box(80, 16),
    ])),
  ]),
);
Widget _box(double w, double h) => /* surfaceAlt + Radii.sm + AnimatedOpacity pulse */;
```

- skeleton은 콘텐츠 형태를 모사(텍스트 2줄+썸네일). 무관한 회색 박스 금지.
- shimmer는 절제(저대비, reduced-motion에서 정지).

---

## 4. List / Feed — loading / empty / error / content

```dart
switch (state) {
  Loading() => ListView(children: List.generate(6, (_) => skeletonCard(context))),
  Empty()   => _EmptyView(
                 icon: Icons.favorite_border,
                 title: '찜한 상품이 없어요',
                 body: '마음에 드는 상품을 담아보세요',
                 action: ('둘러보기', onBrowse)),
  Failure() => _ErrorView(
                 title: '상품을 불러오지 못했어요',
                 body: '네트워크를 확인하고 다시 시도해 주세요',
                 action: ('다시 시도', onRetry)),
  Loaded(:final items) when items.isEmpty => /* 위 Empty */,
  Loaded(:final items) => RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height:1, color: context.c.border),
        itemBuilder: (_, i) => productCard(items[i]),
      )),
}
```

```dart
// 중립 상태 셸 (empty/error 공용 골격)
class _StateView extends StatelessWidget {
  final IconData icon; final String title, body; final (String, VoidCallback)? action;
  @override Widget build(BuildContext context) {
    final c = context.c; final t = Theme.of(context).textTheme;
    return Center(child: Padding(padding: const EdgeInsets.all(Space.x8),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 40, color: c.textSubtle),       // 중립 아이콘, 일러스트 가능
        const SizedBox(height: Space.x4),
        Text(title, style: t.titleSmall, textAlign: TextAlign.center),
        const SizedBox(height: Space.x2),
        Text(body, style: t.bodySmall?.copyWith(color: c.textMuted), textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: Space.x6),
          OutlinedButton(onPressed: action!.$2, child: Text(action!.$1)),
        ],
      ])));
  }
}
```

- empty/error 는 center 정렬 허용(콘텐츠 부재 상태). content는 좌측 정렬 리스트.
- error 액션은 복구 동사("다시 시도"). 실패 원인이 사용자 행동으로 풀리면 그 행동을 제시.

---

## 5. Detail 화면 — skeleton / content / error

- **loading:** hero 이미지 영역 + 제목/가격/본문 블록을 skeleton으로. AppBar는 즉시 렌더(뒤로가기 동작).
- **content:** 이미지(풀블리드) → 핵심정보(제목·가격·핵심속성, 첫 화면 안) → 상세 → sticky 단일 CTA(하단 safe-area).
- **error:** 본문 영역에 `_ErrorView` + [다시 시도]. AppBar/뒤로가기는 유지(막다른 길 금지).
- sticky CTA는 정확히 1개. 카드 내 진입 액션과 푸터 CTA 중복 금지.

---

## 6. Form 제출 흐름 — idle / submitting / success / error

```
idle      → [신청하기] enabled
submitting→ [신청하기] loading(스피너, 비활성), 입력 잠금
success   → 성공 화면/시트: "신청이 접수됐어요 · 접수번호 R-2026-0042" + [확인]
error     → 인라인 필드 에러(검증) 또는 상단 배너(서버 오류) + 재시도 가능, 입력값 보존
```

- 성공은 근거(번호/시각) 제시. 입력값은 에러 시 절대 날리지 않음.
- 옵티미스틱 업데이트 가능 영역(좋아요/장바구니)은 즉시 반영 후 실패 시 롤백 + 토스트.

---

## 7. Image — placeholder / loaded / fallback

```dart
FadeInImage(
  placeholder: MemoryImage(kTransparent),
  image: ResizeImage(NetworkImage(url), width: cacheWidth),
  fadeInDuration: Dur.base,
  imageErrorBuilder: (_, __, ___) => Container(
    color: context.c.surfaceAlt,
    child: Icon(Icons.image_not_supported_outlined, color: context.c.textSubtle)),
)
// placeholder 동안 surfaceAlt + skeleton, 실패 시 중립 fallback. 비율은 AspectRatio로 고정.
```

---

## 8. long-content / 지역화 스트레스

모든 텍스트 노드는 **긴 한국어·영문·해시·식별자**에서 깨지지 않아야 한다.

- 제목: `maxLines` + `TextOverflow.ellipsis` 또는 wrap. 카드 제목 2줄 cap 후 말줄임.
- 금액/숫자: tabular, 우측 정렬, 콤마.
- Row 자식에 `Expanded`/`Flexible` + `overflow` — 가로 오버플로 0.
- 텍스트 확대(시스템 폰트 scale 1.5×)에서 레이아웃 reflow, 가로 스크롤 발생 금지.
- 칩/태그 가로 스크롤은 풀블리드 + content padding.

---

## 검증

각 컴포넌트의 위 상태는 **골든 테스트로 스냅샷**한다(DESIGN-HARNESS.md §골든). 상태 하나라도 스냅샷이 없으면 상태 완결성 게이트 실패 → 미완료.
