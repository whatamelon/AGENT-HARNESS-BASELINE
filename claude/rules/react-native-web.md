# React Native + NativeWind + Expo Web 호환성

## 핵심 규칙

> **레이아웃 결정 속성(flex-direction, position, transform, width/height)은 `className` 대신 인라인 `style` prop에 직접 박는다.**

NativeWind v4 + Tailwind v3 컴파일러는 메트로 캐시 / 자식 프로세스 / RN-Web CSS 변환 단계를 거치므로, className만으로는 멀티 타깃(iOS / Android / Web)에서 레이아웃 일관성이 안정적이지 않다. 시각 스타일(색, 패딩, 마진, 텍스트)은 className OK, **레이아웃 결정 속성은 inline style 우선.**

## 적용 대상

모든 React Native 프로젝트 (Expo / bare RN) 중 다음 조건 중 하나라도 만족:
- Expo Web (`expo start --web`) 또는 react-native-web을 통한 웹 타깃 빌드
- NativeWind 사용
- 단일 코드베이스로 네이티브 + 웹을 동시 지원

## 안전 패턴 vs 위험 패턴

### ✅ 안전 (inline style)

```tsx
// 가로 카드 (이미지 좌측 + 텍스트 우측)
<View
  className="bg-paper border border-line"
  style={{
    width: 300,
    height: 120,
    flexDirection: "row",
  }}
>
  <Image style={{ width: 120, height: 120 }} />
  <View style={{ flex: 1 }}>...</View>
</View>

// 마키 / 캐러셀 컨테이너
<Animated.View
  style={{
    flexDirection: "row",
    flexWrap: "nowrap",
    width: TOTAL_WIDTH,
    transform: [{ translateX }],
  }}
>
  {items}
</Animated.View>
```

### ⚠️ 위험 (className만으로 layout)

```tsx
// 웹에서 flex-row가 안 잡혀 카드가 세로로 쌓일 수 있음
<View className="flex-row" style={{ width: 300 }}>
  <Image />
  <View />
</View>
```

## 어떤 속성에 어떤 방식을 쓸지

| 속성 카테고리 | 권장 방식 | 예시 |
|--------------|----------|------|
| `flexDirection`, `flexWrap` | **inline style** | `style={{ flexDirection: "row" }}` |
| `position` (absolute/relative) | **inline style** | `style={{ position: "absolute" }}` |
| `transform` | inline style (필수, RN 문법) | `style={{ transform: [{ translateX: 0 }] }}` |
| `width`, `height` (고정값) | inline style 권장 | `style={{ width: 300 }}` |
| `flex: 1` (잔여공간) | className 또는 inline 모두 OK | `className="flex-1"` |
| 색상 / 배경 | className OK | `className="bg-paper"` |
| 패딩 / 마진 / gap | className OK | `className="px-4 py-3"` |
| 텍스트 (size, weight, color) | className OK | `className="text-body-m font-bold text-ink"` |
| border / rounded | className OK | `className="border border-line"` |

## 디버깅 체크리스트

화면이 코드와 다르게 보일 때:

1. 파일 mtime이 Metro 시작 시각 이후인지 확인
   ```bash
   stat -f "%Sm" file.tsx
   ps -o lstart= -p <metro-pid>
   ```
2. 브라우저 하드 리프레시 (`Cmd+Shift+R`) — 매번 첫 단계
3. Metro 캐시 클리어 재시작
   ```bash
   rm -rf .expo node_modules/.cache
   npx expo start --web --clear
   ```
4. 그래도 안 잡히면 → className → inline style로 전환
5. NativeWind 자식 프로세스 살아있는지 확인
   ```bash
   ps aux | grep nativewind
   ```

## 마키 / 캐러셀 특수 사항

가로 마키처럼 부모 컨테이너보다 큰 width를 가진 자식이 있을 때:
- 자식 컨테이너에 명시적 `width` (총 길이) + `flexDirection: "row"` + `flexWrap: "nowrap"` 인라인 스타일
- 부모는 `overflow: "hidden"` 또는 `className="overflow-hidden"`
- 자식 카드들은 각각 명시적 `width` 보유 (flex-shrink 회피)

## 왜 이 규칙이 존재하는가

**Why:** NativeWind는 className을 JS 객체 스타일로 컴파일한 후, RN 네이티브 또는 RN-Web에 전달한다. 캐시 / 컴파일 / 핫리로드 / 클래스 추출 단계가 여러 겹이라 디자인 의도가 화면에 늦게 반영되거나 무시되는 케이스가 빈번하다. 레이아웃 결정 속성을 inline에 박으면 컴파일 단계를 우회해서 RN 런타임에 직접 도달하므로 차이가 발생하지 않는다.

**How to apply:**
- 새 RN 컴포넌트를 만들거나 기존 컴포넌트 수정 시 — flex-direction을 정해야 하는 자리에서는 inline style 우선
- 디자인 리뷰 / 코드 리뷰에서 `className="flex-row"` 또는 `className="flex-col"`을 단독으로 쓴 곳 발견하면 inline 전환 제안
- 마키 / 캐러셀 / 가로 스크롤 카드처럼 레이아웃이 visual-critical한 곳은 100% inline
- UI/UX 작업 시 [[design-context]] 룰과 함께 적용
