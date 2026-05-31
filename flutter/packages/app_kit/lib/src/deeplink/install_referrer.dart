/// Android deferred deep-link seam — Play Install Referrer.
///
/// Deferred deep linking on Android: a user without the app taps a referral
/// link, installs from Play, and the `?referrer=<code>` survives the install.
/// On first launch we read it once and resolve the code through [LinkResolver]
/// (same server contract as a warm short link), then navigate via the
/// whitelist.
///
/// iOS has NO supported deferred mechanism (§6) — Apple removed the
/// IDFA/clipboard paths; the fallback is a manual code entry screen
/// (app-owned). This file is therefore Android-only by contract.
///
/// The actual Play Install Referrer read is behind [InstallReferrerReader] so
/// this is unit-testable and adds no heavy native dependency to the package.
/// Production wires it to the `android_play_install_referrer` plugin in the app
/// layer (P4-integration), or via `link_wiring.dart` once the plugin is added.
library;

import 'package:app_kit/src/deeplink/deep_link_service.dart';
import 'package:app_kit/src/deeplink/link_resolver.dart';
import 'package:core/core.dart' as core;

// DI seam (faked in unit tests); intentionally a single-method port.
// ignore_for_file: one_member_abstracts

/// Reads the raw Play Install Referrer string once after install.
///
/// Production: wrap `android_play_install_referrer`
/// (`AndroidPlayInstallReferrer.installReferrer` -> `installReferrer`).
/// Returns `null` on iOS, second launch, or when the plugin is unavailable.
abstract class InstallReferrerReader {
  /// The referrer string (e.g. `referrer=ABC123&utm_source=...`) or `null`.
  Future<String?> read();
}

/// A no-op reader for non-Android / pre-integration builds. Always `null`.
class NoopInstallReferrerReader implements InstallReferrerReader {
  /// Creates a [NoopInstallReferrerReader].
  const NoopInstallReferrerReader();

  @override
  Future<String?> read() async => null;
}

/// Handles Android deferred deep links from the install referrer.
class InstallReferrerHandler {
  /// Creates an [InstallReferrerHandler].
  InstallReferrerHandler({
    required InstallReferrerReader reader,
    required LinkResolver resolver,
    required NavigateToWhitelistedRoute onNavigate,
    core.AppLogger logger = const core.AppLogger(name: 'deeplink.referrer'),
  })  : _reader = reader,
        _resolver = resolver,
        _onNavigate = onNavigate,
        _logger = logger;

  final InstallReferrerReader _reader;
  final LinkResolver _resolver;
  final NavigateToWhitelistedRoute _onNavigate;
  final core.AppLogger _logger;

  /// Reads the install referrer once and, if it carries a `referrer` code,
  /// resolves + navigates. Idempotency (run-once) is the caller's job — gate on
  /// a persisted "deferred link consumed" flag in the app (P4-integration).
  Future<void> handleOnce() async {
    final raw = await _reader.read();
    if (raw == null || raw.isEmpty) return;
    final code = _extractCode(raw);
    if (code == null || code.isEmpty) {
      _logger.info('install referrer present but no resolvable code');
      return;
    }
    final resolved = await _resolver.resolve(code);
    _onNavigate(resolved);
  }

  /// Extracts the `referrer` value from a `key=value&...` install-referrer
  /// string. Returns `null` when absent.
  static String? _extractCode(String raw) {
    // The referrer string is query-encoded; parse it as a query.
    final params = Uri.splitQueryString(raw);
    final referrer = params['referrer'];
    if (referrer == null || referrer.isEmpty) return null;
    // `referrer` may itself be a code or a nested query (`code=ABC&...`).
    if (referrer.contains('=')) {
      final nested = Uri.splitQueryString(referrer);
      return nested['code'] ?? referrer;
    }
    return referrer;
  }
}
