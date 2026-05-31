# State management (locked)

> Foundational decision for the Flutter harness. This is a **lock**, not a
> preference. The largest risk to it is not a deliberate library switch — it is
> AI-agent pattern drift (an LLM mixing in legacy Riverpod APIs or GetX from its
> training data). The lock is enforced structurally, not by convention alone.

## The lock

**Riverpod 3.x is the single, locked state-management foundation of this
harness.** (Resolved: `flutter_riverpod ^3.0.0` in `packages/core` and
`packages/app_kit`; lockfile pins `flutter_riverpod 3.3.1` / `riverpod 3.2.1`.)

Riverpod is load-bearing across the whole harness:

- the **bricks** (`bricks/flutter_app`, `bricks/feature`) generate
  `ProviderScope` + Notifier wiring,
- **core's cross-cutting state** (`authStateProvider`, the §8-B one-way auth
  boundary) is a `NotifierProvider`,
- the **router** (`app_kit/.../router/app_router.dart`) reads
  `authStateProvider` for redirect/refresh,
- generated **feature slices** assume Notifier-based controllers.

Switching the state library would force a rewrite of bricks + core cross-cutting
state + router + every generated slice simultaneously. **Therefore changing the
state-management foundation is forbidden** without re-planning the whole harness.

## Conventions

### Async / server state — `AsyncNotifier` + `AsyncValue` + `.when`

Server-backed and otherwise-async state uses `AsyncNotifier<T>` (or an async
`Notifier` exposing `AsyncValue<T>`). Consume it with exhaustive pattern
matching:

```dart
final user = ref.watch(userControllerProvider);
return user.when(
  data: (u) => UserView(u),
  loading: () => const LoadingView(),
  error: (e, st) => ErrorView(e),
);
```

Do not hand-roll `isLoading`/`error`/`data` booleans alongside the value — let
`AsyncValue` model the three states. This keeps every async surface consistent
and makes loading/error/empty states impossible to forget.

### Synchronous state — `Notifier`

Pure synchronous state uses `Notifier<T>` over an immutable state class with
`copyWith` + value equality. Current canonical examples:

- `packages/core/.../auth/auth_state.dart` — `AuthController extends
  Notifier<AuthState>`, exposed as a `NotifierProvider`.
- `packages/app_kit/.../payments/payment_controller.dart` — `PaymentController
  extends Notifier<PaymentState>`.

State classes are `@immutable`, never mutated in place; transitions produce a
new instance (matches the global immutability rule).

### Dependency injection — Riverpod only

DI is **Riverpod `ProviderScope` override** and nothing else. The §8-B boundary
pattern (app overrides `authStateProvider` with a Supabase-backed controller) is
the model: consumers read a provider; the composition root supplies the
implementation via override.

**A second DI container (GetIt, `package:provider`, etc.) is forbidden.** One
graph, one override mechanism.

## Forbidden (legacy / competing) — enforced

These are hard-failed by `tool/guard_state_mgmt.sh` (see below). They are
superseded in Riverpod 3.x by `Notifier`/`AsyncNotifier`, or are competing
stacks:

| Banned | Use instead |
| --- | --- |
| `StateProvider`, `StateProviderFamily` | `Notifier` + `NotifierProvider` |
| `StateNotifier`, `StateNotifierProvider` | `Notifier` / `AsyncNotifier` + their providers |
| `ChangeNotifierProvider` | `Notifier` + `NotifierProvider` |
| `package:get/`, `package:getx` (GetX) | Riverpod |
| `package:provider/` (provider DI) | Riverpod `ProviderScope` override |

## Code generation — deferred (not yet)

`riverpod_generator` / `@riverpod` code generation is **deferred** for now.
Controllers are written **manually** (`extends Notifier` / `AsyncNotifier`,
hand-declared `NotifierProvider`). Rationale: avoid adding build pipeline
variables (`build_runner` / `custom_lint` / `riverpod_lint`) before the 7/2
store submission (build-freeze decision).

The legacy-API ban makes the eventual move to codegen **painless**: because no
code uses `StateNotifier`/`StateProvider`, migrating to `@riverpod`-generated
`Notifier`/`AsyncNotifier` is a mechanical, post-launch step with no semantic
rewrite. Lint-package adoption (`riverpod_lint` via `custom_lint`) is the
intended successor to the grep guard once the build pipeline can absorb it.

## Enforcement

Two structural gates, no new dependencies:

1. **`tool/guard_state_mgmt.sh`** — greps shipped library code
   (`packages/*/lib`, `apps/*/lib`; excludes `bricks/`, `*.g.dart`,
   `*.freezed.dart`, generated dirs, and comment lines) for the banned
   identifiers/imports above, using identifier word-boundaries so legitimate
   symbols that merely *contain* a banned substring (`authStateProvider`
   contains `StateProvider`) are not false-flagged. Non-zero exit on any
   violation.
   - **Recommended melos registration** (root `pubspec.yaml` `melos.scripts`,
     owned by the cache lane — not registered here):
     ```yaml
     guard:state:
       description: Fail if legacy Riverpod / 2nd state-DI library leaks into lib/.
       run: bash tool/guard_state_mgmt.sh
     ```
2. **`analysis_options.yaml`** — escalates the already-enabled async lints
   `discarded_futures` and `unawaited_futures` to `error` (a dropped Future in a
   Notifier/AsyncNotifier is the most common async-state drift), surfaces
   `avoid_dynamic_calls` as a `warning` (a `dynamic` leak defeats
   `AsyncValue<T>` typing), and enables `avoid_futureor_void` (hides async-state
   transitions in method signatures). No `custom_lint`/`riverpod_lint`
   dev-dependency is added (deferred with codegen).

> The newly-added seam inventory (other harness seams) is maintained by a
> separate lane; this document covers the state-management section only.
