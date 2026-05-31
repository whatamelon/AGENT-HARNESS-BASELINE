# Light/Dark 모드 강제 — 3-Layer 확인 규칙

## 핵심 규칙

> **앱을 라이트(또는 다크) 모드로 "강제"하려면 JS / NativeWind / CSS 세 레이어 모두 확인한다. 한 레이어만 패치하면 다른 레이어가 OS 설정을 따라가 모드가 부분적으로 누출된다.**

빡차 marketing web 배포 사례에서 확인: JS의 `useColorScheme` 호출을 전부 `"light"`로 하드코딩하고 `Appearance.getColorScheme`을 override 했는데도 화면 배경이 검정 — 원인은 `global.css`의 `@media (prefers-color-scheme: dark) { :root { --bbak-canvas: 10 10 12; ... } }` 와 `.dark:root { ... }` 블록이었다. NativeWind 토큰(`bg-canvas`, `bg-paper`)이 CSS 변수 기반이라 JS 패치와 무관하게 dark 값 채택.

## 적용 범위

RN-Web / Expo Web / 일반 웹앱 어디든. NativeWind, Tailwind dark variant, CSS variable 기반 디자인 토큰을 사용하는 모든 프로젝트.

## 3-Layer 체크리스트

라이트(또는 다크) 모드를 강제하기 전에 아래 모두 점검:

### Layer 1 — JS (React Native / RN-Web Appearance)

- `useColorScheme()` 호출 — react-native에서 import. 결과가 `'light' | 'dark' | null`.
- `Appearance.getColorScheme()` / `Appearance.addChangeListener` — 모듈 싱글톤.
- 강제 방법:
  - 컴포넌트 단위로 `const colorScheme = "light" as const` 하드코딩 (가장 확실)
  - 또는 module-level에서 `Appearance.getColorScheme = () => 'light'` mutate (subscriber 시점 문제 있음)
  - matchMedia(`prefers-color-scheme: dark`) override (entry HTML head, defer JS 전 실행)

### Layer 2 — NativeWind / Tailwind dark variant

- `tailwind.config.js`의 `darkMode` 옵션 확인:
  - `"media"` → OS `prefers-color-scheme` 직접 추적. media query 끄지 못함.
  - `"class"` → root 엘리먼트에 `.dark` 클래스가 있을 때만 dark variant 활성. 토글 제어 가능.
- NativeWind v4는 자체 `colorScheme` observable을 RN Appearance 또는 자체 hook에서 가져온다.
- `darkMode: "class"`로 두면 dark variant는 JS가 `.dark` 클래스를 root에 추가하지 않는 한 적용 안 됨.

### Layer 3 — CSS `:root` 변수 + `@media (prefers-color-scheme: dark)`

**가장 자주 빠뜨리는 부분.** CSS 변수 기반 디자인 토큰을 사용할 때:

```css
:root {
  --bg-canvas: 255 255 255;  /* light */
}

.dark:root {
  --bg-canvas: 10 10 12;  /* dark — class 모드용 */
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg-canvas: 10 10 12;  /* dark — OS 자동 감지 */
  }
}
```

`@media (prefers-color-scheme: dark)` 블록은 **JS와 완전히 독립적**으로 OS dark를 따라간다. `useColorScheme` 결과와 무관하게 CSS 변수가 dark 값으로 바뀐다. NativeWind/Tailwind 클래스가 이 변수를 `var(--bg-canvas)` 형태로 사용하면 dark가 그대로 반영됨.

**라이트 강제 시:**
- `@media (prefers-color-scheme: dark) { :root { ... } }` 블록 **삭제** (또는 light value 재선언)
- `.dark:root { ... }` 블록 삭제 (수동 토글 비활성)
- `:root` 한 블록에 light value만 남김
- `<meta name="color-scheme" content="light">` + `html { color-scheme: light }` 추가 (브라우저 form control / scrollbar tone 강제)

**다크 강제 시:** 반대로 :root에 dark value만 남기고 media query / class variant 삭제.

## 디버그 절차 (라이트 강제했는데 dark가 보일 때)

1. **CSS 변수 dump 먼저.** 브라우저 dev tools → :root computed values 확인. `--canvas`/`--paper`가 dark hex면 Layer 3 문제 100%.
2. JS `useColorScheme()` 결과 확인. dark면 Layer 1.
3. root element class 확인. `.dark` 있으면 Layer 2 (class 모드 토글 문제).
4. CSS file에서 `prefers-color-scheme` 검색. media query 있으면 Layer 3.

JS 패치만 시도하고 화면이 안 바뀌면 **거의 항상 CSS layer 누락**이다.

## 빡차 사례 (2026-05-21)

- 증상: 네이버 웨일 다크모드 + macOS 라이트모드 환경에서 marketing web의 home 배경 검정.
- 시도한 패치 (다 효과 없었음):
  - HTML head에서 `window.matchMedia` override
  - `Appearance.getColorScheme = () => 'light'` 모듈 mutate
  - 16개 컴포넌트에서 `useColorScheme()` 호출 → `"light" as const` 하드코딩
- 실제 원인: `global.css`의 `@media (prefers-color-scheme: dark) { :root { --bbak-canvas: 10 10 12; ... } }` 블록이 OS dark를 직접 감지해 CSS 변수 override.
- 해결: 그 블록과 `.dark:root` 블록 삭제 → CSS 변수 light 고정.
- 교훈: NativeWind 클래스가 CSS 변수 기반이면 JS 패치는 무의미.

## How to apply

- 라이트/다크 강제 요청 받으면 **첫 액션이 `grep -rn "prefers-color-scheme\|\\.dark:root" <project>`**. 결과를 먼저 보고 작업 계획.
- `tailwind.config.js`의 `darkMode` 옵션 동시 확인.
- 패치 후 dev tools에서 :root computed CSS 변수 값으로 검증.
- 디자인 토큰이 CSS 변수가 아니라 JS 상수(예: `RULER_B.paper = "#FFFFFF"`)면 Layer 3 무관. JS만 패치하면 됨.

## Why

**Why:** 다크모드 강제 작업이 layer를 분산해 있어 한 곳만 패치하면 다른 곳이 OS를 따른다. CSS의 `prefers-color-scheme` 미디어 쿼리는 JS 런타임 패치로 차단 불가능 (CSS engine이 직접 OS API 호출).

**How to judge edge cases:** "JS에서 색을 fix했는데 화면이 여전히 다른 모드"라면 무조건 CSS layer 의심. tailwind/NativeWind 토큰이 CSS 변수 var(--xxx) 형태로 컴파일되는지 확인.

---

## 부속 규칙 — RN-Web `Modal` portal escape

RN-Web의 `<Modal>`은 `ReactDOM.createPortal`로 children을 `document.body`에 직접 mount한다. 부모 트리에 CSS containing block(`transform`, `contain`)을 걸어도 Modal 자식은 그 바깥에 렌더된다.

**증상:** 모바일 앱을 in-page iPhone preview 프레임 안에 띄운 marketing/landing 사이트에서, 햄버거 사이드바·바텀시트가 프레임을 뚫고 전체 브라우저 viewport에 깔린다.

**해결:** web 한정으로 Modal을 일반 `<View style={{ position:'absolute', inset:0 }}>` 오버레이로 swap. 네이티브는 Modal 유지(안드 백버튼·상태바 처리 차이).

```tsx
const isWeb = Platform.OS === 'web'
if (isWeb && !visible) return null
const Wrapper = isWeb
  ? ({ children }) => (
      <View style={{ position: 'absolute', top: 0, right: 0, bottom: 0, left: 0, zIndex: 1000 }}>
        {children}
      </View>
    )
  : ({ children }) => (
      <Modal visible={visible} transparent onRequestClose={onClose}>{children}</Modal>
    )
return <Wrapper>{...}</Wrapper>
```

screenClip 같은 frame 자식에 `transform: [{ translateX: 0 }]` 또는 inline style `contain: paint`을 함께 걸어 stacking context를 만들어두면 inline overlay가 프레임 내부에 가둠.
