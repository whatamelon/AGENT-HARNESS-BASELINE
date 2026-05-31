/// §H-3 route whitelist — the privilege-escalation firewall for every inbound
/// route (deep links AND push payloads).
///
/// Any externally-supplied location (app_links URI, FCM payload `route`) is
/// untrusted. It is mapped through a per-app whitelist that the app injects
/// (park != onyu); anything not explicitly allowed falls back to the app home.
/// This blocks an attacker from crafting e.g. `/admin/*` links that would
/// otherwise deep-link a user straight into a privileged surface.
///
/// The whitelist holds only *route shapes*, never live data. The app owns the
/// allow-set so the same client package serves both apps with different
/// surfaces. Pure and SDK-free so it is fully unit-testable.
library;

import 'package:meta/meta.dart';

/// A resolved, trusted in-app destination produced by [RouteWhitelist].
///
/// [route] is always an allowed path (or the home fallback). [referralCode] is
/// only ever populated by the *server* resolve step (link_resolver); the client
/// never trusts a referral code lifted directly off an inbound URI.
@immutable
class ResolvedRoute {
  /// Creates a [ResolvedRoute].
  const ResolvedRoute({
    required this.route,
    this.referralCode,
    this.wasAllowed = true,
  });

  /// The trusted in-app path to navigate to.
  final String route;

  /// Server-trusted referral code, or `null`. Never lifted from a raw link.
  final String? referralCode;

  /// `false` when the inbound route was rejected and [route] is the home
  /// fallback (exposed for logging/metrics; navigation uses [route] either way).
  final bool wasAllowed;

  @override
  bool operator ==(Object other) =>
      other is ResolvedRoute &&
      other.route == route &&
      other.referralCode == referralCode &&
      other.wasAllowed == wasAllowed;

  @override
  int get hashCode => Object.hash(route, referralCode, wasAllowed);

  @override
  String toString() {
    final referral = referralCode == null ? 'no' : 'yes';
    return 'ResolvedRoute(route: $route, referral: $referral, '
        'allowed: $wasAllowed)';
  }
}

/// Maps untrusted inbound paths to trusted in-app routes (§H-3).
///
/// Construction is app-owned: pass the set of allowed path prefixes plus the
/// [homeFallback] for rejected/unknown paths. Matching is prefix-based on the
/// normalized path so `/park/contract/123` is allowed by an `/park/contract`
/// prefix, while `/admin/users` is rejected unless `/admin` is explicitly
/// allowed.
@immutable
class RouteWhitelist {
  /// Creates a [RouteWhitelist].
  ///
  /// [allowedPrefixes] are matched against the normalized inbound path; a path
  /// is allowed when it equals or is a sub-path of any prefix. [homeFallback]
  /// is returned for anything not allowed.
  RouteWhitelist({
    required Set<String> allowedPrefixes,
    required this.homeFallback,
  }) : _allowedPrefixes =
            allowedPrefixes.map(_normalize).toSet();

  final Set<String> _allowedPrefixes;

  /// The path returned when an inbound route is not allowed.
  final String homeFallback;

  /// Resolves an inbound [path] (already extracted from a URI or payload) to a
  /// trusted route. [referralCode] is the *server-trusted* referral, passed
  /// through untouched only when [path] itself is allowed.
  ResolvedRoute resolvePath(String? path, {String? referralCode}) {
    final normalized = _normalize(path ?? '');
    if (normalized.isEmpty) {
      return ResolvedRoute(route: homeFallback, wasAllowed: false);
    }
    if (_isAllowed(normalized)) {
      return ResolvedRoute(
        route: normalized,
        referralCode: referralCode,
      );
    }
    // Rejected: drop any referral too — a disallowed route must not smuggle a
    // referral payload through.
    return ResolvedRoute(route: homeFallback, wasAllowed: false);
  }

  bool _isAllowed(String path) {
    for (final prefix in _allowedPrefixes) {
      if (path == prefix) return true;
      if (path.startsWith('$prefix/')) return true;
    }
    return false;
  }

  /// Strips query/fragment, collapses duplicate slashes, and removes any
  /// trailing slash so matching is stable. Returns `''` for non-absolute or
  /// empty input (which then falls back to home).
  static String _normalize(String raw) {
    var path = raw.trim();
    if (path.isEmpty) return '';
    // Drop scheme/host if a full URL slipped through; keep only the path.
    final uri = Uri.tryParse(path);
    final isFullUrl = uri != null &&
        uri.path.isNotEmpty &&
        (uri.hasScheme || raw.contains('://'));
    if (isFullUrl) {
      path = uri.path;
    } else {
      // Strip a bare query/fragment from a path-only string.
      final q = path.indexOf('?');
      if (q != -1) path = path.substring(0, q);
      final h = path.indexOf('#');
      if (h != -1) path = path.substring(0, h);
    }
    if (!path.startsWith('/')) return '';
    // Decode percent-encodings so `%2e%2e` cannot smuggle a `..` past the
    // dot-segment resolver below (H-3: an encoded traversal is still a
    // traversal). Malformed escapes leave the path untouched (still rejected
    // downstream by the absolute-path / dot-segment checks).
    try {
      path = Uri.decodeComponent(path);
    } on FormatException {
      // Keep the raw path; an undecodable escape simply won't match a prefix.
    }
    if (!path.startsWith('/')) return '';
    // Collapse `//` before resolving so empty segments don't confuse the walk.
    path = path.replaceAll(RegExp('/+'), '/');
    // RFC 3986 remove_dot_segments BEFORE matching: resolve `..`/`.` so that
    // `/park/contract/../admin` can never slip through the prefix whitelist as
    // an allowed `/park/contract*` route (H-3 privilege-escalation firewall).
    final segs = path.split('/');
    final out = <String>[];
    for (final s in segs) {
      if (s == '..') {
        if (out.length > 1) out.removeLast();
      } else if (s == '.') {
        // skip
      } else {
        out.add(s);
      }
    }
    path = out.join('/');
    if (path.isEmpty) path = '/';
    // Strip trailing slash (but keep root `/`).
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }
}
