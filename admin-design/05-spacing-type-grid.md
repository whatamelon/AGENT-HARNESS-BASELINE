---
slug: spacing-type-grid
tier: 1
applies_to: [layout, typography, responsive]
must:
  - four_px_grid
  - viewport_adaptive_padding
  - responsive_workspace_not_responsive_website
  - column_priority_for_every_data_table
  - border_over_shadow_for_structure
must_not:
  - oversized_pill_shapes
  - large_colored_glow_shadows
  - random_gray_values_in_components
  - import_custom_web_fonts_without_approved_font
cross_ref: [00-non-negotiable, 04-tokens, 06-shell-pages, 09-tables]
verifier_probes:
  - id: viewport-matrix-snapshots
    layer: L3
    rule: "every list/detail/form route renders without horizontal overflow at viewports 834/1280/1512/1728/2560"
  - id: row-height-canonical
    layer: L4
    rule: "DataTable row height in [32, 36, 40, 48] only"
  - id: no-heavy-card-shadow
    layer: L1
    grep: "shadow-2xl|shadow-\\[0_.+_60px\\]|drop-shadow-\\[0_.+_40px\\]"
    expect: 0
---

# 5. Spacing, Border, Radius, Elevation

## 5.1 Grid

4px spacing grid.

```txt
1 = 4px   2 = 8px   3 = 12px  4 = 16px  5 = 20px
6 = 24px  8 = 32px  10 = 40px 12 = 48px
```

## 5.2 Page spacing

| Viewport | Content padding | Layout behavior |
|---|---:|---|
| 11" iPad / tablet | 16px | Sidebar drawer; filter sheet |
| 13" laptop | 24px | persistent sidebar; compact toolbar |
| 16" laptop | 24-32px | full toolbar; optional right inspector |
| 24" monitor | 32px | full width workspace; split panes |
| 32" monitor | 32-40px | persistent filter, right inspector, multi-pane |

## 5.3 Component heights

| Component | Compact | Default | Comfortable |
|---|---:|---:|---:|
| Button | 32px | 36px | 40px |
| Input/select | 32px | 36px | 40px |
| Table row | 32-36px | 40px | 48px |
| Toolbar | 40px | 48px | 56px |
| Header nav item | 32px | 36px | 40px |
| Modal footer | 56px | 64px | 72px |

## 5.4 Border

Default:

```txt
border border-border
```

structure 는 shadow 가 아닌 border.

허용 shadow: Dropdown/menu/popover, Modal/sheet — subtle only.
금지 shadow: Large colored glow, heavy card shadow, marketing-style floating card.

## 5.5 Radius

```txt
--radius: 0.5rem
```

- Button/input/card: `rounded-md` or token equivalent.
- Table: 외부 container rounded 가능, 내부 cell 은 grid align.
- Badge: `rounded-md` or `rounded-full` — status style 따라 consistent.
- oversized pill 회피. compact status pill 만 예외.

---

# 6. Typography

## 6.1 Font

```txt
font-sans: system UI stack
```

platform-native rendering. product 가 approved font 보유 시에만 web font import.

## 6.2 Type scale

| Role | Size | Weight | Usage |
|---|---:|---:|---|
| Page title | 24px | 600/700 | Top-level page heading |
| Section title | 18px | 600 | Card/section heading |
| Subsection title | 16px | 600 | Form/table subgroup |
| Body | 14px | 400 | Main admin text |
| Body strong | 14px | 500/600 | Table key values/actions |
| Small | 13px | 400 | Secondary metadata |
| Caption | 12px | 400/500 | Badge, helper, table metadata |

## 6.3 Text color rules

| Text role | Token/class |
|---|---|
| Primary | `text-foreground` |
| Secondary | `text-muted-foreground` |
| Tertiary | `text-muted-foreground/80` |
| Disabled | `text-muted-foreground/50` |
| Link/action | `text-foreground underline-offset-4 hover:underline` (or primary only when needed) |
| Error | `text-destructive` |

reusable component 에 random gray 사용 금지. token 만.

---

# 7. Responsive Workspace System

## 7.1 Principle

어드민 UI 는 responsive website 가 아니다. **responsive workspace**.

screen 이 커질 때 card 단순 확대 X. adapt:
- density
- sidebar 동작
- filter 배치
- column visibility
- split pane
- detail inspector
- saved view
- keyboard efficiency

## 7.2 Breakpoint behavior

| Width | Mode | Required behavior |
|---:|---|---|
| `< 1024px` | Tablet | Sidebar drawer; filter sheet; table h-scroll; hide low-priority columns |
| `1024-1279px` | Small laptop | Persistent sidebar 224-240px; compact filter; no persistent right panel |
| `1280-1535px` | Laptop | Sidebar 240px; full table toolbar; detail drawer available |
| `1536-1919px` | Desktop | Sidebar 256px; optional split pane; more columns |
| `>= 1920px` | Large monitor | Persistent filter panel or right inspector allowed |
| `>= 2560px` | XL monitor | Multi-pane allowed, content max-width 로 unreadable line length 방지 |

## 7.3 Column visibility by viewport

모든 data table 컬럼 priority:

```ts
priority: "required" | "high" | "medium" | "low" | "debug"
```

- `required`: 항상 visible
- `high`: laptop+
- `medium`: tablet hidden, desktop visible
- `low`: tablet/laptop default hidden, column visibility menu 로 접근
- `debug`: default hidden, admin/super-admin 또는 debug view 만

## 7.4 Horizontal scroll policy

table 은 h-scroll 가능. 단 controlled.

Required:
- key identifier 컬럼 visible 유지
- row action 도달 가능
- column visibility menu 사용
- critical value tooltip 없이 truncate 금지
