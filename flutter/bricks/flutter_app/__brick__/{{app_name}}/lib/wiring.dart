import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart';

/// {{app_title}} integration seams.
///
/// This file is the single place where the skeleton meets the real backend.
/// It ships with ZERO secrets: every key lives in `.env` (git-ignored) or is
/// passed via `--dart-define` at build time. Commit only `.env.example`.
///
/// ── Supabase (auth + data) ───────────────────────────────────────────────
/// `initAppBackends()` calls `app_kit`'s `initSupabaseSecure()`, which reads
/// `SUPABASE_URL` / `SUPABASE_ANON_KEY` from `AppEnv` (only the public
/// anon/publishable key — never `service_role`) and wires the H-5 secure
/// session + PKCE storage so the refresh token is never persisted in plaintext
/// `shared_preferences`. With no env it is a safe no-op (returns `false`) so
/// the skeleton boots offline.
///
/// To enable real auth, add an override to the `bootstrap` `ProviderScope`:
///   authStateProvider.overrideWith(
///     (ref) => SupabaseAuthController(...),  // from package:app_kit
///   )
/// The router already listens to `authStateProvider` (read-only) and the P3
/// redirect seam in `buildAppRouter` flips on once a real session arrives.
///
/// ── Toss Payments ─────────────────────────────────────────────────────────
/// Pass the Toss client key via `--dart-define=TOSS_CLIENT_KEY=...` (test key
/// in dev/staging, live key only in prod CI). Wire `TossPaymentBackend` from
/// `package:app_kit/app_kit.dart` behind `paymentControllerProvider`. The live
/// PG flow stays flag-OFF until the merchant contract is approved.
///
/// ── Firebase Cloud Messaging (push) ───────────────────────────────────────
/// Generate `firebase_options.dart` with the FlutterFire CLI (git-ignored) and
/// call `initFirebaseMessaging(...)` from `package:app_kit/app_kit.dart` here.
/// Until then push is disabled and the skeleton renders no push UI.
Future<void> initAppBackends() async {
  // Secure init only: H-5 session + PKCE storage. No-op without env
  // (placeholder-only skeleton). Reads the public anon key from `AppEnv` when
  // present; never embeds a secret.
  await initSupabaseSecure(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  // Firebase seam (placeholder): once `firebase_options.dart` exists, call
  //   await Firebase.initializeApp(options: ...);
  //   await initFirebaseMessaging(...);
}

/// To apply Riverpod overrides at boot (real auth / push / payments), pass them
/// to the [bootstrap] `ProviderScope`. The skeleton boots with none (it runs on
/// the `core` stubs); add e.g. `authStateProvider.overrideWith(...)` there when
/// wiring the real backend — see the integration notes above.
