# 가로 스크롤 풀블리드 규칙

## 핵심 규칙

> **가로 스크롤(`ScrollView horizontal`, `FlatList horizontal`)은 부모 글로벌 패딩/마진의 시각적 영향을 받지 않는다. 본체는 풀블리드로 깔고, content에 자체 padding을 줘서 양옆이 끊긴 것처럼 보이지 않게 한다.**

## 안티패턴 — 끊긴 것처럼 보임

```tsx
// 부모가 mx-5 (20px). ScrollView가 그 안에 갇혀 있어
// 마지막 칩이 mx-5 영역 안에서 더는 못 흐름 → "여기서 끊기네" 느낌
<View className="mx-5">
  <ScrollView horizontal>
    {items.map(...)}
  </ScrollView>
</View>
```

스크롤로 active 항목을 가운데로 정렬해야 할 때, 양 끝 항목 활성 시 위치가 어색해지는 것도 같은 원인.

## 안전 패턴 — 풀블리드

```tsx
// ScrollView 본체는 mx-5 패딩을 뚫고 화면 전체 너비를 차지하되,
// content는 자체 paddingHorizontal: 20으로 시작/끝 여유 확보
<View className="mx-5">
  <ScrollView
    horizontal
    showsHorizontalScrollIndicator={false}
    style={{ marginHorizontal: -20 }}
    contentContainerStyle={{ paddingHorizontal: 20 }}
  >
    {items.map(...)}
  </ScrollView>
</View>
```

핵심 두 줄:
- `style={{ marginHorizontal: -<부모 padding> }}` — 부모 패딩 무효화 (풀블리드)
- `contentContainerStyle={{ paddingHorizontal: <부모 padding> }}` — 시작/끝 여유

## 적용 대상

- 카테고리 chip row
- 필터 chip row
- 캐러셀 / 호리즌탈 카드 리스트
- 가로 슬라이드 / 룩북 / 마키
- 주차/날짜/탭 picker

## active scroll-into-view 패턴과의 결합

active 항목을 가운데로 자동 스크롤할 때 풀블리드는 필수. 그렇지 않으면:
- 양 끝 항목이 active 되었을 때 가운데로 못 와서 잘려 보임
- 풀블리드면 가운데 정렬 시 부모 패딩 영역까지 자연스럽게 흐름

```tsx
useEffect(() => {
  const layout = layouts.current[active];
  if (!layout || containerWidth === 0) return;
  const target = layout.x + layout.width / 2 - containerWidth / 2;
  scrollRef.current?.scrollTo({ x: Math.max(0, target), animated: true });
}, [active, containerWidth]);
```

## How to apply

- 가로 스크롤을 추가/수정하는 모든 자리에서 부모 padding 값을 먼저 확인
- ScrollView/FlatList는 그 값의 음수 margin으로 풀블리드 진입
- content는 같은 값의 paddingHorizontal로 시작/끝 여백
- React Native + NativeWind 환경에서는 [[feedback-rn-web-flex]] 룰과 함께 적용 (`marginHorizontal`/`paddingHorizontal`은 inline style로)
