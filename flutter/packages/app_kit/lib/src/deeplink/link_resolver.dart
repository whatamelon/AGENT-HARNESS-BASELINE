/// Short-link / referral resolver — server round-trip via core's `ApiClient`.
///
/// When an installed app receives `https://{LINK_BASE}/l/<code>`, it asks the
/// server to resolve the code to a real in-app route:
///   GET {LINK_BASE}/functions/v1/link-resolve?code=<code>
///   -> 200 { "route": "/park/...", "referralCode"?: "..." }
///
/// The returned route is STILL passed through the §H-3 [RouteWhitelist] (the
/// server is trusted, but the client enforces its own allow-set as defense in
/// depth). The `referralCode` is server-trusted and attached only when the
/// route is allowed — the client never fabricates a referral code.
///
/// `auth` is optional: referral resolution must work for logged-out users.
library;

import 'package:app_kit/src/deeplink/route_whitelist.dart';
import 'package:core/core.dart' as core;

/// Path of the resolve Edge Function (joined onto the ApiClient base URL).
const String kLinkResolvePath = '/functions/v1/link-resolve';

/// Resolves short codes to whitelisted routes.
class LinkResolver {
  /// Creates a [LinkResolver].
  LinkResolver({
    required core.ApiClient apiClient,
    required RouteWhitelist whitelist,
    core.AppLogger logger = const core.AppLogger(name: 'deeplink.resolve'),
  })  : _api = apiClient,
        _whitelist = whitelist,
        _logger = logger;

  final core.ApiClient _api;
  final RouteWhitelist _whitelist;
  final core.AppLogger _logger;

  /// Resolves [code] to a [ResolvedRoute]. On any failure (network, malformed
  /// response, empty code) returns the whitelist home fallback so the user is
  /// never left on a dead screen.
  Future<ResolvedRoute> resolve(String code) async {
    if (code.isEmpty) {
      return _whitelist.resolvePath(null);
    }
    final result = await _api.get<Map<String, dynamic>>(
      kLinkResolvePath,
      query: <String, Object?>{'code': code},
    );
    return result.fold(
      _onResolved,
      (failure) {
        _logger.warn('link resolve failed: ${failure.runtimeType} -> home');
        return _whitelist.resolvePath(null);
      },
    );
  }

  ResolvedRoute _onResolved(Map<String, dynamic> body) {
    final route = body['route'];
    final referral = body['referralCode'] ?? body['referral_code'];
    if (route is! String || route.isEmpty) {
      _logger.warn('link resolve returned no route -> home');
      return _whitelist.resolvePath(null);
    }
    // Even a server route is whitelisted (§H-3 defense in depth). Referral is
    // server-trusted and only survives if the route is allowed.
    return _whitelist.resolvePath(
      route,
      referralCode: referral is String && referral.isNotEmpty ? referral : null,
    );
  }
}
