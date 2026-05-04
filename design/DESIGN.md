# DESIGN.md — Shared Product Design System

A shared, AI-readable design system for Claude Code, Codex, and both Macs. This file follows the getdesign.md / Stitch-inspired DESIGN.md pattern: it gives agents concrete visual tokens, component rules, layout behavior, and prompt guidance so UI work stays consistent.

## 1. Visual Theme & Atmosphere

### Design direction

- **Category**: premium developer/productivity SaaS, AI-native tooling, technical dashboards.
- **Mood**: precise, calm, focused, high-trust, quietly premium.
- **Density**: medium-high information density with strong grouping and whitespace.
- **Personality**: competent and fast; never cute, gimmicky, or overly decorative.
- **Primary metaphor**: command center / cockpit / design review board.

### Visual language

- Clean neutral foundation with one confident accent color.
- Crisp cards, subtle borders, restrained shadows, and clear hierarchy.
- Monospace accents for commands, logs, hashes, tokens, and technical metadata.
- Use motion sparingly for orientation and feedback, not entertainment.

### Design philosophy

- Prioritize legibility, speed, and decision clarity.
- Every screen should answer: **where am I, what changed, what needs action, what proves it worked?**
- Prefer one strong focal area over many competing panels.
- Visual polish should come from spacing, typography, contrast, and state completeness.

## 2. Color Palette & Roles

Use semantic tokens. Project-local design systems may override values, but should preserve roles.

### Light theme

| Token | Hex | Role |
|---|---:|---|
| `--background` | `#FAFAF8` | App/page background; warm off-white |
| `--surface` | `#FFFFFF` | Cards, panels, elevated content |
| `--surface-muted` | `#F3F4F1` | Secondary panels, subtle section backgrounds |
| `--surface-inset` | `#ECEDE8` | Code blocks, input wells, recessed areas |
| `--border` | `#DADDD4` | Default borders and dividers |
| `--border-strong` | `#B9BFB2` | Active/selected borders |
| `--text` | `#171A16` | Primary text |
| `--text-muted` | `#5F665B` | Secondary text |
| `--text-subtle` | `#858C80` | Captions, metadata, placeholders |
| `--accent` | `#10A37F` | Primary action, highlights, success-forward brand accent |
| `--accent-strong` | `#0B7F63` | Hover/pressed accent |
| `--accent-soft` | `#DDF8EF` | Accent background, selected rows |
| `--info` | `#2563EB` | Informational state |
| `--warning` | `#D97706` | Warnings, needs attention |
| `--danger` | `#DC2626` | Destructive actions/errors |
| `--success` | `#059669` | Success/verified/pass |

### Dark theme

| Token | Hex | Role |
|---|---:|---|
| `--background` | `#090B0A` | App/page background |
| `--surface` | `#111412` | Cards, panels |
| `--surface-muted` | `#171B18` | Secondary panels |
| `--surface-inset` | `#060807` | Code blocks, input wells |
| `--border` | `#2A302B` | Default borders |
| `--border-strong` | `#3F4A42` | Active/selected borders |
| `--text` | `#F4F7F2` | Primary text |
| `--text-muted` | `#B5BDB1` | Secondary text |
| `--text-subtle` | `#7C857A` | Captions, placeholders |
| `--accent` | `#10B981` | Primary action/highlight |
| `--accent-strong` | `#34D399` | Hover/active accent |
| `--accent-soft` | `#0D2B22` | Accent background |
| `--info` | `#60A5FA` | Informational state |
| `--warning` | `#F59E0B` | Warnings |
| `--danger` | `#F87171` | Destructive/errors |
| `--success` | `#34D399` | Success/verified/pass |

### Color usage rules

- One primary accent per screen. Do not scatter accent everywhere.
- Use green/accent for progress, sync, verified, and primary CTA.
- Use blue for neutral information only; do not compete with the primary CTA.
- Use red only for destructive/error states.
- Never rely on color alone; pair state color with icon, label, or text.

## 3. Typography Rules

### Font stack

```css
--font-sans: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
--font-mono: "SF Mono", ui-monospace, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
```

If a project already uses Geist, SF Pro, Pretendard, or a product-specific font, keep that project font and map the scale below.

### Type scale

| Role | Size | Line height | Weight | Usage |
|---|---:|---:|---:|---|
| Display | 48–64px | 1.0–1.08 | 650–750 | Marketing hero only |
| H1 | 32–40px | 1.1 | 650–750 | Page title |
| H2 | 24–28px | 1.18 | 620–700 | Section title |
| H3 | 18–20px | 1.3 | 600–680 | Card/panel title |
| Body | 15–16px | 1.55 | 400–480 | Main content |
| Body small | 13–14px | 1.45 | 400–500 | Dense UI, tables |
| Caption | 11–12px | 1.35 | 500–600 | Metadata, labels |
| Code | 12–14px | 1.45 | 400–520 | Commands, hashes, logs |

### Typography rules

- Headings should be short and concrete; avoid vague marketing filler.
- Use tabular numbers for metrics, timestamps, prices, and counts.
- Use monospace for commands, file paths, IDs, hashes, env vars, and logs.
- Avoid more than three text sizes within one card.
- Korean/English mixed copy should preserve comfortable line height (`1.5+`).

## 4. Component Stylings

### Buttons

| Variant | Style | States |
|---|---|---|
| Primary | Accent fill, white/dark text, 10–12px radius | Hover darkens; focus ring; disabled 50% opacity |
| Secondary | Surface fill, border, primary text | Hover uses muted surface; active border strong |
| Ghost | Transparent, muted text | Hover muted surface; no heavy border |
| Destructive | Danger fill or danger outline | Confirm destructive intent in copy |

Button rules:

- Primary button appears once per decision area.
- Labels should be verbs: “Sync”, “Verify”, “Apply”, “Deploy”, “Review”.
- Minimum touch target: 44px height on mobile, 36px desktop dense UI.

### Cards and panels

- Background: `--surface`; border: `1px solid var(--border)`.
- Radius: 14–18px for large panels, 10–12px for nested cards.
- Padding: 16px dense, 20–24px standard, 32px hero/marketing.
- Header area should include title, concise description, and optional status/action.
- Use subtle dividers, not heavy boxes, for dense internal sections.

### Inputs and forms

- Inputs use `--surface` or `--surface-inset`, 1px border, 10px radius.
- Focus: 2px accent ring or accent border plus accessible outline.
- Validation messages appear below the field and include recovery guidance.
- Required fields should be explicit in label or helper text.

### Tables and lists

- Use compact rows with clear row hover.
- Keep key identifiers monospace.
- Use sticky headers for long tables when possible.
- Empty table state must explain what to do next.

### Navigation

- Current location must be visually persistent.
- Use breadcrumbs for deep workflows.
- On mobile, collapse secondary navigation before hiding primary actions.

### Status badges

- Shape: pill, 999px radius, 11–12px label.
- Pair color with text: `PASS`, `SYNCED`, `DIRTY`, `FAILED`, `PENDING`.
- Avoid ambiguous color-only dots unless paired with label or tooltip.

## 5. Layout Principles

### Spacing scale

Use 4px-based spacing:

| Token | px | Usage |
|---|---:|---|
| `--space-1` | 4 | Tight icon/text gaps |
| `--space-2` | 8 | Inline groups, badges |
| `--space-3` | 12 | Compact field/card gaps |
| `--space-4` | 16 | Default component padding |
| `--space-5` | 20 | Panel spacing |
| `--space-6` | 24 | Section spacing |
| `--space-8` | 32 | Major section padding |
| `--space-10` | 40 | Page section gap |
| `--space-12` | 48 | Hero/marketing gap |

### Grid and containers

- Default content max-width: 1120–1280px.
- Reading content max-width: 720–820px.
- Dashboard: 12-column grid desktop, 6 tablet, 1–2 mobile.
- Use left alignment for productivity tools; center alignment only for landing hero/empty states.

### Hierarchy

1. Page title and primary status.
2. Main action or decision.
3. Evidence/details.
4. Secondary actions and logs.

### Whitespace

- Preserve whitespace around decisions and destructive actions.
- Dense technical data is allowed, but grouped into cards with explicit labels.
- Avoid “floating orphan controls”; controls should live near affected content.

## 6. Depth & Elevation

### Elevation tokens

| Token | Value | Usage |
|---|---|---|
| `--shadow-xs` | `0 1px 1px rgba(0,0,0,.04)` | Subtle surface lift |
| `--shadow-sm` | `0 8px 24px rgba(0,0,0,.08)` | Cards/popovers light theme |
| `--shadow-md` | `0 18px 48px rgba(0,0,0,.14)` | Dialogs, command palettes |
| `--shadow-glow` | `0 0 0 1px rgba(16,163,127,.18), 0 18px 60px rgba(16,163,127,.12)` | Rare accent emphasis |

### Depth rules

- Prefer borders and surface contrast over heavy shadows.
- Dark theme uses subtle border contrast more than shadows.
- Modals and command palettes get the strongest elevation.
- Do not stack more than two nested shadow levels.

## 7. Do's and Don'ts

### Do

- Use semantic tokens, not arbitrary one-off colors.
- Make state transitions obvious: pending → running → passed/failed.
- Use concise labels and evidence-oriented copy.
- Show exact command, path, hash, or timestamp when it helps trust.
- Include accessibility states and keyboard/focus behavior.
- Use screenshots or browser checks for visual claims when possible.

### Don't

- Do not clone a real brand exactly from a public DESIGN.md; use it as inspiration/reference.
- Do not mix multiple inspiration brands in one surface without defining a merged system.
- Do not use low-contrast gray text for essential information.
- Do not invent new component shapes if project components already exist.
- Do not hide errors behind generic “Something went wrong”.
- Do not use decorative gradients where hierarchy/spacing would solve the problem.

## 8. Responsive Behavior

### Breakpoints

| Name | Width | Behavior |
|---|---:|---|
| Mobile | `< 640px` | Single column, bottom-safe actions, 44px touch targets |
| Tablet | `640–1023px` | 2-column where useful, collapse sidebars |
| Desktop | `1024–1439px` | Full nav, 12-column dashboard grid |
| Wide | `>= 1440px` | Increase whitespace, do not stretch reading text |

### Responsive rules

- Primary action remains reachable without horizontal scroll.
- Tables become cards or horizontally scroll only when data integrity requires columns.
- Sidebars collapse to drawers or top nav on mobile.
- Preserve status/evidence visibility at all widths.
- Use reduced motion preferences for animations.

## 9. Agent Prompt Guide

### Standard prompt for UI work

> Use `DESIGN.md` and any project-local design docs. Build a precise, calm, premium developer-product UI. Preserve project components and tokens where present. Cover loading, empty, error, success, disabled, and responsive states. Validate visually and report evidence.

### Context summary required before design work

- Product goal:
- Primary user/action:
- Surface/component/page:
- Inspiration or project-local DESIGN.md:
- Active tokens/components:
- Constraints:
- Validation plan:

### Quick token reference

- Accent: `#10A37F` light, `#10B981` dark.
- Radius: 10–12px controls, 14–18px cards.
- Spacing: 4px scale, default padding 16–24px.
- Font: Inter/system sans + SF Mono/monospace.
- Mood: calm command center, not playful/gimmicky.

### When using getdesign.md inspirations

1. Pick one inspiration (`linear.app`, `vercel`, `cursor`, `figma`, etc.) based on the product goal.
2. Add or copy that DESIGN.md into the project root if the project needs a specific visual direction.
3. Treat public DESIGN.md files as reference material, not official brand systems.
4. Merge inspiration with this file by preserving accessibility, state coverage, and project-local constraints.
