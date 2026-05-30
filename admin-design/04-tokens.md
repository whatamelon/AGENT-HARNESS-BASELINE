---
slug: tokens
tier: 1
applies_to: [foundation, theme, all-styling]
must:
  - semantic_tokens_not_raw_colors_in_reusable_components
  - tailwind_class_pointing_to_css_variable
  - primary_swappable_without_redesign
  - light_only_token_set
  - theme_color_mapping_resolves_to_valid_color   # @theme 의 --color-* 가 실제 유효 색을 만든다 (채널 토큰이면 hsl() 래핑) — Tailwind v4 (2026-05-31)
must_not:
  - dark_token_block
  - random_gray_values_in_reusable_components
  - primary_tint_on_page_background_cards_table_rows
  - rainbow_badge_systems
  - bare_channel_token_in_theme_color_mapping     # @theme { --color-x: var(--x) } + --x=HSL채널(`0 0% 96%`) → background-color 무효 → surface 전부 투명 (Tailwind v4, 2026-05-31)
cross_ref: [00-non-negotiable, 03-philosophy, 05-spacing-type-grid, 17-status]
allowed_base_color: [neutral, zinc]
forbidden_base_color: [slate, stone]
verifier_probes:
  - id: dark-token-block-absent
    layer: L1
    grep: "^\\s*\\.dark\\s*\\{|\\.dark:root\\s*\\{|@media\\s*\\(prefers-color-scheme:\\s*dark\\)"
    expect: 0
    allow_paths: []
  - id: primary-occurrence-cap
    layer: L2
    rule: "bg-primary count <= 1 per route file; primary 색상은 CTA/focus/active nav/selected tab/checkbox/chart accent 만"
  - id: no-tinted-card-background
    layer: L2
    rule: "Card component className grep: bg-primary/bg-blue-/bg-indigo-/bg-purple- on card containers = forbidden"
  - id: theme-color-token-resolves
    layer: L2
    rule: "globals.css `@theme`(inline) 의 `--color-*: var(--<token>)` 에서 <token> 이 HSL 채널(`H S% L%`, hsl()/oklch() 없는 raw 3값)로 정의됐으면 반드시 `hsl(var(--<token>))` 로 감싼다. 미래핑 시 Tailwind v4 가 `background-color: 0 0% 96%`(무효) 생성 → bg-*/text-*/border-* 유틸 전부 투명. 토큰을 full color(oklch/hsl()/hex)로 저장한 경우만 raw `var()` 허용."
  - id: surface-bg-opaque-runtime
    layer: L3
    rule: "주요 surface(card/muted/popover/primary, sticky thead)의 computed background-color 가 transparent(rgba(0,0,0,0)) 가 아니어야 한다. static className(bg-muted 존재) 통과만으로 불충분 — 렌더 후 실제 opaque 확인(브라우저 computed style)."
---

# 4. Design Tokens

## 4.1 Token principles

- 재사용 컴포넌트는 semantic token 만, raw color X.
- Tailwind class 는 CSS variable 가리킨다: `bg-background`, `text-foreground`, `border-border`, `text-muted-foreground`, `bg-muted`, `ring-ring`.
- brand primary 는 redesign 없이 swappable.
- dark mode token block **금지**.

## 4.2 Base color

Default:

```txt
baseColor: neutral
```

허용 대안:

```txt
zinc     - 약간 차가운 톤, developer/admin tool 에 좋음
neutral  - default, 가장 flexible
```

회피:

```txt
slate    - bluish 화 + arbitrary primary 와 충돌
stone    - warm/beige 화 + 일부 enterprise surface 와 충돌
```

## 4.3 shadcn/ui configuration

신규 shadcn/ui setup:

```json
{
  "style": "new-york",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "baseColor": "neutral",
    "cssVariables": true
  }
}
```

Next.js/RSC 프로젝트는 `rsc` 를 실제 app 에 맞춤. Rhea 같은 newer compact style 이 이미 stable 하면 유지. 아니면 `new-york`.

## 4.4 Core semantic token map

| Token | Meaning | Default visual |
|---|---|---|
| `background` | Page background | White |
| `foreground` | Primary text | Near black |
| `card` | Card/surface | White |
| `card-foreground` | Card text | Near black |
| `popover` | Popover/dialog/dropdown surface | White |
| `popover-foreground` | Overlay text | Near black |
| `primary` | Injected brand/action color | Neutral black by default |
| `primary-foreground` | Text on primary | White |
| `secondary` | Secondary surface | Gray 50/100 |
| `secondary-foreground` | Text on secondary | Near black |
| `muted` | Muted surface | Gray 50/100 |
| `muted-foreground` | Muted text | Gray 500/600 |
| `accent` | Hover/active neutral accent | Gray 50/100 |
| `accent-foreground` | Text on accent | Near black |
| `destructive` | Destructive action | Red, limited use |
| `destructive-foreground` | Text on destructive | White |
| `border` | Default border | Gray 200 |
| `input` | Input border | Gray 200/300 |
| `ring` | Focus ring | Primary or near black |
| `success` | Completion indicator | Small semantic accent only |
| `warning` | Warning indicator | Small semantic accent only |
| `info` | Informational indicator | Small semantic accent only |

## 4.5 CSS variable starter

shadcn output 없으면 light-only token file 생성:

```css
:root {
  --radius: 0.5rem;

  --background: 0 0% 100%;
  --foreground: 0 0% 9%;

  --card: 0 0% 100%;
  --card-foreground: 0 0% 9%;

  --popover: 0 0% 100%;
  --popover-foreground: 0 0% 9%;

  --primary: 0 0% 9%;
  --primary-foreground: 0 0% 98%;

  --secondary: 0 0% 96%;
  --secondary-foreground: 0 0% 9%;

  --muted: 0 0% 96%;
  --muted-foreground: 0 0% 45%;

  --accent: 0 0% 96%;
  --accent-foreground: 0 0% 9%;

  --destructive: 0 84% 60%;
  --destructive-foreground: 0 0% 98%;

  --border: 0 0% 90%;
  --input: 0 0% 90%;
  --ring: 0 0% 9%;

  --success: 142 71% 45%;
  --warning: 38 92% 50%;
  --info: 217 91% 60%;
}
```

`.dark` token block 생성 **금지**.

## 4.6 Primary color usage governance

허용:

| UI element | Primary usage |
|---|---|
| Main CTA button | Solid primary background |
| Focus ring | Primary or neutral ring |
| Active nav item | Thin left indicator or subtle foreground emphasis |
| Selected tab | Underline, border, or text emphasis |
| Selected table row | Thin accent border or subtle tint < 4% visual intensity |
| Checkbox/radio/switch active | Primary fill |
| Chart accent | 1-2 series max unless chart requires more |

금지:

| UI element | Forbidden usage |
|---|---|
| Page background | No primary tint |
| Cards | No primary-tinted card backgrounds |
| Table rows | No full saturated primary row backgrounds |
| Icons | Do not color every icon primary |
| Headers | No giant primary gradients |
| Empty states | No colorful illustrations unless explicitly requested |
| Badges | Do not create rainbow badge systems |

## 4.7 Tailwind v4 `@theme` 매핑 — 채널 토큰은 hsl() 로 감싼다 (non-negotiable, 2026-05-31)

§4.5 의 토큰은 **HSL 채널**(`--muted: 0 0% 96%` — `hsl()` 없는 raw 3값)로 저장한다(shadcn 관례). Tailwind v4 는 `@theme` 의 `--color-*` 값을 **색으로 직접** 소비한다(`.bg-muted { background-color: var(--color-muted) }`). 따라서 `@theme` 에서 채널 토큰을 그대로 매핑하면 `background-color: 0 0% 96%`(무효값) → 모든 `bg-*`/`text-*`/`border-*` 유틸이 **투명**해진다.

```css
/* ❌ 깨짐 — 채널 토큰을 raw 로 매핑 (background-color:0 0% 96% = 무효 → 투명) */
@theme inline {
  --color-muted: var(--muted);      /* --muted: 0 0% 96% */
  --color-card: var(--card);
}

/* ✅ 정답 — 채널 토큰을 hsl() 로 감싼다 */
@theme inline {
  --color-muted: hsl(var(--muted));
  --color-card: hsl(var(--card));
  --color-success: hsl(var(--success));   /* 의미색도 동일. opacity 모디파이어(bg-success/15) 도 정상 작동 */
}
```

대안: 토큰을 **full color**(`oklch(...)`/`hsl(...)`/`#hex`)로 저장하면 `--color-x: var(--x)` raw 매핑 OK.

**왜 위험한가 — static verifier 가 못 잡는 갭:** `bg-muted` 클래스는 존재하므로 className 기반 static 검사(L1/L2)는 **통과**한다. 그런데 런타임 computed background 는 `rgba(0,0,0,0)`. 흰 페이지 위에선 카드가 흰색으로 보여 "정상"처럼 넘어가다가, **sticky thead 처럼 배경이 겹쳐야 하는 곳에서 행이 비쳐** 비로소 터진다(§09 §12.10). base 규칙(`body{background:hsl(var(--background))}`, `*{border-color:hsl(var(--border))}`)은 `hsl()` 로 직접 쓰므로 멀쩡 → "테두리·body 는 되는데 카드 배경만 투명"이라는 헷갈리는 증상.

**진단:** 라이트/다크나 위치 문제로 오인 말고, 브라우저 dev tools 에서 `getComputedStyle(card).backgroundColor` 를 먼저 본다. `rgba(0,0,0,0)` 면 `@theme` 매핑(`--color-*`)을 의심 → `hsl()` 래핑 확인. probe `theme-color-token-resolves`(L2) + `surface-bg-opaque-runtime`(L3) 로 강제.
