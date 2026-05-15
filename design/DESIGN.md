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
- Never assume a foreground/background pair is safe because it works in one theme. Verify the computed color pair in both `light` and `dark`.
- Avoid semantic inversions like `background: var(--text)` with `color: white`; theme switches can turn the background light while the foreground stays light.
- Primary CTA text may switch between light and dark text per theme. The role is "readable action text", not "always white text".
- Every visible text node must meet at least `4.5:1` contrast in automated visual checks; critical protocol/verification copy should target `7:1+`.

### Dark mode contrast non-regression gate

Before claiming any UI/design change is complete, run the same visual check under both browser color schemes:

```bash
pnpm lint && pnpm build && pnpm test:visual
```

The visual check must:

- Capture `artifacts/design-loop-home-light.png` and `artifacts/design-loop-home-dark.png`.
- Audit computed foreground/background contrast for visible text in both themes.
- Fail on any visible text below `4.5:1`.
- Report the lowest contrast pairs in `artifacts/visual-check.json`.
- Explicitly verify high-risk protocol/evidence panels where white text appears on dark surfaces.

### Responsive non-regression gate

The same visual check must also run a viewport matrix, not a single desktop screenshot:

| Viewport | Size | Purpose |
|---|---:|---|
| Mobile | `390×844` | iPhone-class one-column layout and touch targets |
| Tablet | `768×1024` | Tablet/tall two-column transition checks |
| Desktop | `1024×768` | Compact laptop width |
| Wide | `1440×1200` | Primary desktop/wide evidence |

Each viewport must be checked in both light and dark mode. The harness should fail when:

- The page introduces horizontal overflow.
- Core sections (`main`, `nav`, `#verification`, `#scenario`, `#states`, `#protocol`) are missing, hidden, or horizontally clipped.
- Mobile/tablet interactive targets are smaller than `44×44px`.
- Desktop interactive targets are smaller than `36px` high.
- Responsive screenshots are not produced for every viewport/theme pair.

### Keyboard focus non-regression gate

Keyboard accessibility is a visual quality requirement, not a separate cleanup task. The same visual check must tab through the primary interactive targets in the intended order:

1. `View proof`
2. `Run scenario`
3. `Inspect states`

The harness should fail when:

- Focus order differs from the intentional DOM/action order above.
- A focused target is hidden, clipped, or not visibly reachable.
- `:focus-visible` is not active after keyboard navigation.
- The focus indicator is missing, too subtle, or thinner than `2px` when no equivalent shadow/ring exists.
- Focusable elements regress below the same touch-target requirements enforced by the responsive gate.

### Automated accessibility non-regression gate

The visual check must also run an axe accessibility scan for every viewport/theme scenario. This catches semantic and assistive-technology regressions that screenshots cannot see.

The harness should fail when:

- `axeAudit.violations` is not empty for any viewport/theme pair.
- A landmark is nested incorrectly or lacks a clear accessible label.
- Links, buttons, form controls, or regions lack accessible names.
- Heading structure, document language, ARIA usage, or name/role/value semantics regress.
- The scan is accidentally run against a stale local server instead of the current build. Without `BASE_URL`, the harness must start its own ephemeral `next start` server.

### Reduced motion non-regression gate

The visual check must also run every viewport/theme scenario in a `prefers-reduced-motion: reduce` browser context. Motion may still exist in the default experience, but reduced-motion users must get a stable, non-moving interface.

The harness should fail when:

- The reduced-motion media query does not match in the audit context.
- `html` keeps `scroll-behavior: smooth`.
- Visible elements keep nonzero transition or animation duration/delay.
- Loading/status pulse animations keep running.
- Hover/focus interactions move or resize targets (`translate`, `transform`, or measured box changes).
- Tailwind/custom motion variables keep applying hover movement after reduced-motion overrides.

### Forced colors / high contrast non-regression gate

The visual check must also run every viewport/theme scenario in a `forced-colors: active` browser context. This protects users who rely on OS high-contrast palettes where gradients, shadows, token colors, and decorative fills can be overridden.

The harness should fail when:

- The forced-colors media query does not match in the audit context.
- Visible text falls below `4.5:1` after forced-colors overrides.
- Key UI boundaries marked with `data-forced-colors-boundary` lose a visible 1px+ border.
- Decorative background images or gradients remain active in forced-colors mode.
- Keyboard focus order or focus-visible indicators regress under forced-colors.
- Forced-colors screenshots are not produced for every viewport/theme pair.

### Text zoom / large text reflow non-regression gate

The visual check must also run every viewport/theme scenario with simulated browser text zoom at `150%` and `200%`. This protects users who increase text size without changing the layout viewport.

The harness should fail when:

- The page introduces horizontal overflow at `150%` or `200%` text zoom.
- Core sections (`main`, `nav`, `#verification`, `#scenario`, `#states`, `#protocol`) are missing, hidden, or horizontally clipped.
- Primary interactive targets become undersized or clipped.
- Cards, attestation panels, code blocks, or protocol rows refuse to reflow within the viewport.
- `200%` text-zoom screenshots are not produced for every viewport/theme pair.

Implementation rules:

- Use `min-w-0` on grid/flex children that contain long copy.
- Let navigation and CTA groups wrap instead of forcing a single row.
- Prefer one-column metrics/cards on narrow viewports.
- Allow code/log panels to scroll horizontally only when the content is inherently unbreakable.

### Content overflow / localization stress non-regression gate

The visual check must also replace representative UI copy with long Korean, English, hashes, file paths, command strings, and unbroken identifiers. This catches real production failures from pasted logs, localization expansion, long machine names, and proof hashes.

The harness should fail when:

- Stress content creates page-level horizontal overflow.
- Core sections or stressed text targets become horizontally clipped.
- CTA/link targets become clipped or undersized.
- Any element creates unapproved horizontal scrolling.
- Approved horizontal scrolling is not explicitly marked with `data-horizontal-scroll-ok` for inherently unbreakable code/log content.
- Content stress screenshots are not produced for every viewport/theme pair.

Implementation rules:

- Mark high-risk copy nodes with `data-content-stress` so the harness can mutate them.
- Use `min-w-0` on nested grid/flex cards, not just their parents.
- Use `overflow-wrap: anywhere` for user/content-driven text, hashes, machine names, and labels.
- Keep code/log wells visually contained; if horizontal scrolling is intentional, isolate it to the code well.

### Visual density / hit-area separation non-regression gate

The visual check must also measure spacing between intentionally dense groups and visible interactive hit targets. Screenshots can miss "almost touching" controls, stacked card collisions, and CTA groups that technically fit but feel cramped or error-prone.

The harness should fail when:

- Fewer than five density groups are audited.
- Direct children inside a marked `data-density-group` overlap.
- Direct children inside a marked `data-density-group` fall below that group's `data-density-min` spacing.
- Visible links/CTAs overlap or have less than `8px` separation from each other.
- Density evidence is missing from any viewport/theme scenario.

Implementation rules:

- Mark high-risk groups with `data-density-group` and a numeric `data-density-min`.
- Use real CSS `gap`, wrapping, and responsive grid behavior instead of relying on visual intention.
- Preserve enough spacing between primary/secondary CTAs for touch and pointer accuracy.
- Audit density in every light/dark and mobile/tablet/desktop/wide scenario, not only the hero screenshot.

### Interactive state visual matrix non-regression gate

The visual check must also prove that primary interactions have distinct `default`, `hover`, and `active` states, and that non-clickable `loading` / `disabled` controls are semantically and visually different. A polished screenshot is not enough if buttons do not visibly respond or disabled controls look tappable.

The harness should fail when:

- Fewer than three `data-interaction-probe` targets are audited.
- A probed CTA/link has no visible style delta on hover.
- A probed CTA/link has no visible style delta on active press.
- Loading controls lack `aria-busy="true"`, a visible busy indicator, a disabled busy state, or a `wait` cursor.
- Disabled controls lack the `disabled` attribute, `aria-disabled="true"`, or a `not-allowed` cursor.
- Loading and disabled states collapse into the same visual treatment.

Implementation rules:

- Mark primary interactive targets with `data-interaction-probe`.
- Use explicit `hover:` and `active:` styles; do not rely on browser defaults.
- Use semantic disabled/loading attributes in addition to visual styling.
- Keep interaction-state samples inside the same viewport/theme matrix as contrast, layout, keyboard, reduced-motion, forced-colors, text-zoom, content-stress, and density checks.

### Visual hierarchy / section priority non-regression gate

The visual check must also prove that the page has an intentional information hierarchy. A page can pass contrast, spacing, and accessibility checks while still feeling flat if the hero, primary action, evidence panel, and secondary sections compete at the same visual weight.

The harness should fail when:

- There is not exactly one visible `h1`.
- The hero title is not meaningfully larger than section and protocol titles.
- Section titles are not meaningfully larger than card titles.
- The primary action is visually too similar to the secondary action or page background.
- The primary action is too small relative to the secondary action.
- The secondary action loses its outline treatment.
- The verification/evidence panel loses elevation.
- The hero title starts too low in the first viewport.

Implementation rules:

- Mark hierarchy-critical elements with `data-visual-priority`.
- Preserve a clear type ramp: hero > section/protocol > card.
- Preserve a clear action ramp: primary filled CTA > secondary outlined CTA > nav utility link.
- Audit hierarchy in every viewport/theme scenario, because mobile type wrapping can flatten priority even when desktop looks correct.

### Copy quality / anti-generic text non-regression gate

The visual check must also audit operator-facing copy. A page can look premium while saying nothing specific; the loop should reject generic AI/SaaS filler, vague state text, and claims without evidence or recovery paths.

The harness should fail when:

- Fewer than 24 `data-copy-quality` targets are audited.
- Copy contains banned generic phrases such as "learn more", "seamless", "revolutionary", "next-gen", "powerful solution", or "AI-powered".
- Hero, feature, state, section, or protocol copy lacks concrete domain/evidence language.
- Feature bodies do not include at least two concrete anchors such as `DESIGN.md`, Claude Code, Codex, screenshots, hashes, build results, or machine portability.
- Error state copy does not name the failure and include a recovery path such as `Run getdesign doctor`.
- Loading, empty, and success states do not explain what is happening, what absence means, or what artifact was verified.
- Protocol steps do not start with operator verbs (`Load`, `Generate`, `Run`, `Compare`).
- Evidence copy omits concrete command status or a sha256 prefix.

Implementation rules:

- Mark meaningful UI copy with `data-copy-quality`.
- Prefer concrete nouns, artifacts, tools, hashes, counts, and recovery actions over generic adjectives.
- State copy must tell the operator what happened and what to do next.
- Keep the same copy audit inside every viewport/theme scenario so visual-only edits cannot bypass language quality.

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
- **IRON LAW — no decorative eyebrow/kicker:** never place an ALL-CAPS micro eyebrow/kicker label directly above a section or page heading (e.g. `NOTIFICATION CENTER`, `CONTACT`, `DELIVERY DETAILS`). The heading + spacing carries the section; a repeated micro header reads as auto-generated AI tone, not editorial. Applies even if a project-local DESIGN.md still recommends "ALL CAPS eyebrow" — this global law wins and the project doc must be updated to match.
- **IRON LAW — localized UI labels:** UI label text defaults to the product's primary language (Korean for these projects). Non-functional/decorative English labels are prohibited. Exceptions only: proper nouns (brand/model names like `BMW`, `GT3`), user-invisible technical tokens (code, API, URL, env keys), and short universally-adopted abbreviations used inside a localized phrase (`CEO 픽`). See global rule `~/.config/claude-sync/claude/rules/no-decorative-eyebrow.md`.

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

> Use `DESIGN.md` and any project-local design docs. Build a precise, calm, premium developer-product UI. Preserve project components and tokens where present. Cover loading, empty, error, success, disabled, and responsive states. Validate visually in both light and dark mode, fail on visible text contrast below 4.5:1, and report screenshot/DOM evidence.

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
