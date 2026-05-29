---
slug: tokens
tier: 1
applies_to: [foundation, theme, all-styling]
must:
  - semantic_tokens_not_raw_colors_in_reusable_components
  - tailwind_class_pointing_to_css_variable
  - primary_swappable_without_redesign
  - light_only_token_set
must_not:
  - dark_token_block
  - random_gray_values_in_reusable_components
  - primary_tint_on_page_background_cards_table_rows
  - rainbow_badge_systems
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
