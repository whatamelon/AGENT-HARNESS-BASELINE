# Flutter harness bricks

Mason bricks that scaffold new apps and feature slices wired to the harness
packages (`core` / `ds` / `app_kit`). Generated code uses only those packages'
public APIs, the ANDS design tokens (no raw colors), a single Material icon set,
Korean copy, and ships **zero secrets** (placeholder `.env.example` only).

## Setup (once)

```bash
dart pub global activate mason_cli
export PATH="$HOME/.pub-cache/bin:$PATH"   # if mason isn't on PATH
cd <harness-root>                          # the dir holding mason.yaml
mason get                                  # resolve the path bricks
```

`mason.yaml` registers both bricks from `bricks/`. Re-run `mason get` after
pulling brick changes.

## Brick 1 — `flutter_app` (new app)

Scaffolds a complete app under `apps/<app_name>/`: flavor entrypoints
(`main_dev/staging/prod`), `bootstrap` (observability + guarded zone + Supabase
init seam), `MaterialApp.router` over a go_router `StatefulShellRoute`, a
route→chrome policy map, an §H-3 deep-link/push route whitelist, one minimal
`ds` screen per tab, and a `wiring.dart` integration seam (Supabase / Toss /
Firebase — placeholders only).

### Variables

| var | type | meaning |
|-----|------|---------|
| `app_name` | string | package + directory name, `snake_case` (e.g. `park_app`) |
| `app_title` | string | Korean display title (MaterialApp / OS task switcher) |
| `brand_seed` | string | ARGB hex seed for `buildTheme` (e.g. `0xFF0095A9`) |
| `org_domain` | string | org root (informational; deep-link note) |
| `bundle_id` | string | bundle id (e.g. `com.example.app`) |
| `tabs` | array | bottom-nav tabs: each `{key, label, icon}` — `key` is a `snake_case` route segment, `label` the Korean nav label, `icon` a Material icon base name (e.g. `home`, `event`, `person`) rendered as `Icons.<icon>` / `Icons.<icon>_outlined` |
| `haptics_enabled` | boolean | default `true`. When `true`, `bootstrap` overrides `hapticsProvider` with `ThrottlingHaptics(PlatformHaptics(...))` so `ds`/app call sites get real taptic feedback out of the box. When `false`, no override is added and the `core` default `NoopHaptics` stays — the app boots with zero haptics code paths (not a greyed stub). |

The `tabs` array is easiest to pass via a JSON config file (`-c`):

```jsonc
// park_app.json
{
  "app_name": "park_app",
  "app_title": "용인공원",
  "brand_seed": "0xFF2E7D6B",
  "org_domain": "yiparkc.com",
  "bundle_id": "com.yiparkc.park",
  "tabs": [
    { "key": "home",        "label": "홈",   "icon": "home" },
    { "key": "contract",    "label": "계약", "icon": "description" },
    { "key": "reservation", "label": "예약", "icon": "event" },
    { "key": "mypage",      "label": "마이", "icon": "person" }
  ]
}
```

```bash
mason make flutter_app -o apps/ -c park_app.json
```

(`-o apps/` is the parent; the brick creates the `apps/<app_name>/` subdir.)

### After generation (manual steps the post-gen hook prints)

1. Add `  - apps/<app_name>` to the **root `pubspec.yaml`** `workspace:` list.
2. From the repo root: `melos bootstrap` (or `flutter pub get`).
3. Verify: `cd apps/<app_name> && flutter analyze && flutter test`.
4. (optional) Full platform scaffolding + real web icons:
   `cd apps/<app_name> && flutter create --platforms=web,android,ios .`
   (Regenerates only `web/android/ios`; leaves `lib/` and `pubspec.yaml` intact.)
5. Wire real backends in `lib/wiring.dart` (Supabase / Toss / Firebase).

The brick ships a minimal `web/` so `flutter build web` works before step 4.

## Brick 2 — `feature` (feature slice)

Scaffolds a feature-first slice under `<app>/lib/features/<feature_name>/`:
a `ds`-based `ConsumerWidget` screen + a Riverpod controller, and — when
`with_domain` is true — a `domain/` (entity) and `data/` (repository over
`Result`/`ApiClient`/Supabase) layer. When `with_domain` is false the empty
domain/data stubs are pruned (presentation-only 2-layer slice).

Pick a screen **`archetype`** so repeated screens come out consistent:

| archetype | screen | controller | data shape (`with_domain`) |
|-----------|--------|------------|----------------------------|
| `list` (default) | `DsList` over a collection, loading/empty/error states + retry | `AsyncNotifier<List<T>>` (renders via `AsyncValue.when`) | `fetchAll() → Result<List<T>, AppException>` |
| `detail` | single entity: header → `DsCard` body → **one** sticky bottom CTA | `AsyncNotifier<T?>` | `fetchOne() → Result<T?, AppException>` |
| `form` | multi-field `DsTextField` + per-field validation status + submit | `Notifier<…FormState>` (`fieldKeys`, `fieldStatus`, `isSubmitting`, `submit()`) | `submit(Map<String,String>) → Result<void, AppException>` |

Conventions baked in:

- **list / detail** use `AsyncNotifier` + `AsyncValue.when(loading/error/data)`
  so no state is missed (retry = `ref.invalidate(provider)`). No hand-rolled
  `{items,isLoading,error}` triples.
- **detail** ships exactly one sticky CTA (global anti-slop rule: one decision
  area per screen).
- **form** validates per field (`DsFieldStatus.error`/`success` + Korean
  helper) and `submit()` returns `Future<Result<void, AppException>?>` — `null`
  means local validation blocked the submit (the UI reads field status),
  otherwise it is the backend submit result.
- **form** has no domain entity; with `with_domain` it gets only the submit-side
  repository.

mason 0.1.x exposes `enum` vars only as a string, so a `pre_gen` hook derives
`is_list` / `is_detail` / `is_form` booleans for the templates to branch on.

### Variables

| var | type | meaning |
|-----|------|---------|
| `package_name` | string | host app package name (`snake_case`) — must match the app's `pubspec` `name` (used for `package:` imports between slice files) |
| `feature_name` | string | feature / route segment, `snake_case` (e.g. `reservation`) |
| `archetype` | enum | `list` \| `detail` \| `form` (default `list`) — see table above |
| `with_domain` | bool | include `domain/` + `data/` layers (light clean architecture) |

```bash
# list slice, presentation-only
mason make feature -o apps/park_app/lib \
  --package_name park_app --feature_name reservation \
  --archetype list --with_domain false

# detail slice with domain + data
mason make feature -o apps/park_app/lib \
  --package_name park_app --feature_name reservation \
  --archetype detail --with_domain true

# form slice with a submit-side repository
mason make feature -o apps/park_app/lib \
  --package_name park_app --feature_name contact \
  --archetype form --with_domain true
```

`-o <app>/lib` so files land under `<app>/lib/features/<feature_name>/`.

Register the new route by following the snippet at the bottom of
`<feature_name>_screen.dart` (add a `ShellBranch` or `GoRoute`, a chrome policy
case, and the whitelist prefix in the app's `app.dart`).

## Gates honored by the generated code

- ANDS tokens only (`ds`), single Material icon set, Korean copy, no dead
  affordances.
- No secrets in the bricks or generated output — `.env` is git-ignored; only
  placeholder `.env.example` is committed.
- Generated apps depend only on `core` / `ds` / `app_kit` public APIs (no
  `src/` imports).
- `flutter analyze` clean, smoke test green, `flutter build web` succeeds.
