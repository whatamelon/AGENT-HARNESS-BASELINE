/// Production deep-link wiring — binds [AppLinksPort] to `app_links` 7.x.
///
/// SDK-touching; excluded from unit tests (tests fake the port). app_links 7.x
/// API: `getInitialLink() -> Future<Uri?>`, `uriLinkStream -> Stream<Uri>`.
library;

import 'package:app_kit/src/deeplink/deep_link_service.dart';
import 'package:app_links/app_links.dart';

/// [AppLinksPort] over the `app_links` plugin.
class AppLinksAdapter implements AppLinksPort {
  /// Creates an [AppLinksAdapter].
  AppLinksAdapter([AppLinks? appLinks]) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}
