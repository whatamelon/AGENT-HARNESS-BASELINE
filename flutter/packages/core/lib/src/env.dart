import 'package:envied/envied.dart';

part 'env.g.dart';

/// Compile-time environment values, sourced from `.env` at build time via
/// `envied` codegen. Values are obfuscated in the generated `env.g.dart`.
///
/// `.env` is git-ignored; commit only `.env.example` with placeholders.
/// Regenerate after editing `.env`:
///   dart run build_runner build --delete-conflicting-outputs
@Envied(path: '.env', obfuscate: true, useConstantCase: true)
abstract class AppEnv {
  @EnviedField(varName: 'SUPABASE_URL', defaultValue: '')
  static final String supabaseUrl = _AppEnv.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_ANON_KEY', defaultValue: '')
  static final String supabaseAnonKey = _AppEnv.supabaseAnonKey;

  @EnviedField(varName: 'SENTRY_DSN', defaultValue: '')
  static final String sentryDsn = _AppEnv.sentryDsn;

  /// True when a Supabase URL is configured (non-placeholder).
  static bool get hasSupabase => supabaseUrl.isNotEmpty;

  /// True when a Sentry DSN is configured.
  static bool get hasSentry => sentryDsn.isNotEmpty;
}
