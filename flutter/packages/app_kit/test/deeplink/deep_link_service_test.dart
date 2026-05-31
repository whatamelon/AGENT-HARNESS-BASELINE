import 'dart:async';
import 'dart:typed_data';

import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart' as core;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake `app_links` port: settable cold-start link + controllable warm stream.
class _FakeAppLinks implements AppLinksPort {
  _FakeAppLinks({this.initial});
  Uri? initial;
  final _stream = StreamController<Uri>.broadcast();

  void emit(Uri uri) => _stream.add(uri);

  @override
  Future<Uri?> getInitialLink() async => initial;

  @override
  Stream<Uri> get uriLinkStream => _stream.stream;

  Future<void> dispose() => _stream.close();
}

/// Dio adapter returning a canned JSON body (for LinkResolver).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);
  final String body;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

RouteWhitelist _whitelist() => RouteWhitelist(
      allowedPrefixes: const {'/park/contract', '/onyu/guide'},
      homeFallback: '/park',
    );

void main() {
  group('DeepLinkService', () {
    late List<ResolvedRoute> navigations;

    setUp(() => navigations = []);

    test('cold start (getInitialLink) routes a semantic deep link', () async {
      final appLinks = _FakeAppLinks(
        initial: Uri.parse('https://yipark.app/park/contract/1'),
      );
      addTearDown(appLinks.dispose);
      final service = DeepLinkService(
        appLinks: appLinks,
        whitelist: _whitelist(),
        onNavigate: navigations.add,
      );
      addTearDown(service.dispose);

      await service.start();
      expect(navigations.single.route, '/park/contract/1');
      expect(navigations.single.wasAllowed, isTrue);
    });

    test('warm stream (uriLinkStream) routes a semantic deep link', () async {
      final appLinks = _FakeAppLinks();
      addTearDown(appLinks.dispose);
      final service = DeepLinkService(
        appLinks: appLinks,
        whitelist: _whitelist(),
        onNavigate: navigations.add,
      );
      addTearDown(service.dispose);

      await service.start();
      appLinks.emit(Uri.parse('https://yipark.app/onyu/guide/step3'));
      await Future<void>.delayed(Duration.zero);

      expect(navigations.single.route, '/onyu/guide/step3');
    });

    test('whitelist rejects a privileged deep link -> home (§H-3)', () async {
      final appLinks = _FakeAppLinks(
        initial: Uri.parse('https://yipark.app/admin/users'),
      );
      addTearDown(appLinks.dispose);
      final service = DeepLinkService(
        appLinks: appLinks,
        whitelist: _whitelist(),
        onNavigate: navigations.add,
      );
      addTearDown(service.dispose);

      await service.start();
      expect(navigations.single.route, '/park');
      expect(navigations.single.wasAllowed, isFalse);
    });

    test('short link /l/<code> calls the resolver and uses its route',
        () async {
      final adapter = _FakeAdapter(
        '{"route":"/park/contract/77","referralCode":"REF9"}',
      );
      final api = core.ApiClient(dio: Dio()..httpClientAdapter = adapter);
      final resolver =
          LinkResolver(apiClient: api, whitelist: _whitelist());

      final appLinks = _FakeAppLinks(
        initial: Uri.parse('https://link.yipark.app/l/abc123'),
      );
      addTearDown(appLinks.dispose);
      final service = DeepLinkService(
        appLinks: appLinks,
        whitelist: _whitelist(),
        onNavigate: navigations.add,
        resolver: resolver,
        linkHost: 'link.yipark.app',
      );
      addTearDown(service.dispose);

      await service.start();

      expect(adapter.lastOptions?.path, kLinkResolvePath);
      expect(adapter.lastOptions?.queryParameters['code'], 'abc123');
      expect(navigations.single.route, '/park/contract/77');
      // Referral code is server-trusted and survives the allowed route.
      expect(navigations.single.referralCode, 'REF9');
    });

    test('short link with no resolver wired falls back to home', () async {
      final appLinks = _FakeAppLinks(
        initial: Uri.parse('https://link.yipark.app/l/zzz'),
      );
      addTearDown(appLinks.dispose);
      final service = DeepLinkService(
        appLinks: appLinks,
        whitelist: _whitelist(),
        onNavigate: navigations.add,
        linkHost: 'link.yipark.app',
      );
      addTearDown(service.dispose);

      await service.start();
      expect(navigations.single.route, '/park');
    });
  });

  group('LinkResolver', () {
    test('whitelists even the server route (§H-3 defense in depth)', () async {
      final adapter = _FakeAdapter('{"route":"/admin/root"}');
      final api = core.ApiClient(dio: Dio()..httpClientAdapter = adapter);
      final resolver = LinkResolver(
        apiClient: api,
        whitelist: RouteWhitelist(
          allowedPrefixes: const {'/park'},
          homeFallback: '/park',
        ),
      );

      final resolved = await resolver.resolve('code1');
      expect(resolved.route, '/park');
      expect(resolved.wasAllowed, isFalse);
    });

    test('empty code returns the home fallback without a call', () async {
      final adapter = _FakeAdapter('{"route":"/park/contract"}');
      final api = core.ApiClient(dio: Dio()..httpClientAdapter = adapter);
      final resolver = LinkResolver(
        apiClient: api,
        whitelist: _whitelist(),
      );

      final resolved = await resolver.resolve('');
      expect(resolved.route, '/park');
      expect(adapter.lastOptions, isNull);
    });
  });
}
