/// Deep-link runtime — SDK-free orchestration over an [AppLinksPort].
///
/// Two entry points, per app_links 7.x:
/// - cold start: `getInitialLink()` once on launch
/// - warm:       `uriLinkStream` for links received while running
///
/// Every inbound URI is routed through the §H-3 [RouteWhitelist] before any
/// navigation. Two URI shapes are handled (shared contract with Lane B server):
/// - semantic deep link `https://{APP_BASE}/<route>` -> whitelist directly
/// - short/referral link `https://{LINK_BASE}/l/<code>` -> server resolve via
///   [LinkResolver], then whitelist the returned route
///
/// The port abstracts `app_links` so this is unit-testable; production wires
/// `AppLinksAdapter` (see `link_wiring.dart`).
library;

import 'dart:async';

import 'package:app_kit/src/deeplink/link_resolver.dart';
import 'package:app_kit/src/deeplink/route_whitelist.dart';
import 'package:core/core.dart' as core;

/// Port over `app_links`. Production: `AppLinksAdapter`. Tests: a fake with a
/// settable initial link and a controllable stream.
abstract class AppLinksPort {
  /// The link that cold-started the app, or `null`. (`getInitialLink` 7.x.)
  Future<Uri?> getInitialLink();

  /// Links received while the app is already running. (`uriLinkStream` 7.x.)
  Stream<Uri> get uriLinkStream;
}

/// Resolves inbound deep links to whitelisted navigation.
class DeepLinkService {
  /// Creates a [DeepLinkService].
  ///
  /// [linkHost] is the short-link host (`{LINK_BASE}`); a URI whose host
  /// matches AND whose path is `/l/<code>` is treated as a server-resolve
  /// link. [resolver] performs that server round-trip. All other links map
  /// directly through [whitelist].
  DeepLinkService({
    required AppLinksPort appLinks,
    required RouteWhitelist whitelist,
    required NavigateToWhitelistedRoute onNavigate,
    LinkResolver? resolver,
    String? linkHost,
    core.AppLogger logger = const core.AppLogger(name: 'deeplink'),
  })  : _appLinks = appLinks,
        _whitelist = whitelist,
        _onNavigate = onNavigate,
        _resolver = resolver,
        _linkHost = linkHost,
        _logger = logger;

  final AppLinksPort _appLinks;
  final RouteWhitelist _whitelist;
  final NavigateToWhitelistedRoute _onNavigate;
  final LinkResolver? _resolver;
  final String? _linkHost;
  final core.AppLogger _logger;

  StreamSubscription<Uri>? _sub;

  /// Handles the cold-start link (once) and subscribes to the warm stream.
  Future<void> start() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      await _handle(initial, source: 'cold');
    }
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handle(uri, source: 'warm')),
    );
  }

  Future<void> _handle(Uri uri, {required String source}) async {
    // Short/referral link -> server resolve (referral is server-trusted).
    if (_isShortLink(uri)) {
      final resolver = _resolver;
      if (resolver == null) {
        _logger.warn('short link received but no resolver wired -> home');
        _onNavigate(_whitelist.resolvePath(null));
        return;
      }
      final code = _shortCode(uri);
      final resolved = await resolver.resolve(code);
      // resolver already passes its server route through the whitelist.
      _onNavigate(resolved);
      return;
    }

    // Semantic deep link -> whitelist the path directly. Referral codes on a
    // direct link are NOT trusted (only the server resolve path may set one).
    final resolved = _whitelist.resolvePath(uri.path);
    if (!resolved.wasAllowed) {
      _logger.warn('deep link route rejected ($source) -> home fallback');
    }
    _onNavigate(resolved);
  }

  bool _isShortLink(Uri uri) {
    final segments = uri.pathSegments;
    final hasShortPath = segments.length >= 2 && segments.first == 'l';
    if (!hasShortPath) return false;
    // If a link host is configured, require it to match (defense in depth).
    if (_linkHost != null && _linkHost.isNotEmpty) {
      return uri.host == _linkHost;
    }
    return true;
  }

  String _shortCode(Uri uri) => uri.pathSegments[1];

  /// Cancels the warm-link subscription.
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}

/// Navigation sink for an already-whitelisted route (bound to the router).
typedef NavigateToWhitelistedRoute = void Function(ResolvedRoute route);
