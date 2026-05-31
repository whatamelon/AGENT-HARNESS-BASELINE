import 'dart:async';
import 'dart:typed_data';

import 'package:app_kit/src/network/auth_refresh_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter that 401s the first time a given path is seen and 200s once the
/// request carries the retry marker, so the interceptor's retry-after-refresh
/// path is exercised end-to-end.
class _RefreshAwareAdapter implements HttpClientAdapter {
  _RefreshAwareAdapter({this.alwaysUnauthorized = false});

  /// When true, even retried requests 401 (proves no infinite loop).
  final bool alwaysUnauthorized;

  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    final retried = options.extra[kRetriedExtraKey] == true;
    if (alwaysUnauthorized || !retried) {
      return ResponseBody.fromString('unauthorized', 401);
    }
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Builds a primary Dio (carrying the interceptor) + a retry Dio sharing the
/// same adapter, with injected refresh/token/unrecoverable callbacks.
///
/// When [refreshGate] is supplied, the refresh callback awaits it before
/// completing — letting a test hold the single refresh open while multiple
/// concurrent 401s pile onto the latch (proving they collapse onto one call).
({
  Dio dio,
  _RefreshAwareAdapter adapter,
  List<String> events,
}) _buildClient({
  required bool refreshSucceeds,
  bool alwaysUnauthorized = false,
  Future<void>? refreshGate,
}) {
  final adapter = _RefreshAwareAdapter(alwaysUnauthorized: alwaysUnauthorized);
  final events = <String>[];
  String? token = 'old-token';

  final retryDio = Dio()..httpClientAdapter = adapter;
  final dio = Dio()..httpClientAdapter = adapter;

  dio.interceptors.add(
    AuthRefreshInterceptor(
      refresh: () async {
        events.add('refresh');
        if (refreshGate != null) await refreshGate;
        if (refreshSucceeds) {
          token = 'new-token';
          return true;
        }
        return false;
      },
      currentToken: () => token,
      onUnrecoverable: () async => events.add('unrecoverable'),
      retryDio: retryDio,
    ),
  );

  return (dio: dio, adapter: adapter, events: events);
}

void main() {
  group('AuthRefreshInterceptor', () {
    test('refreshes once and retries the original request', () async {
      final c = _buildClient(refreshSucceeds: true);

      final res = await c.dio.get<Map<String, dynamic>>('/protected');

      expect(res.statusCode, 200);
      expect(res.data?['ok'], true);
      // 1 refresh, original 401 + retried 200 = 2 transport calls.
      expect(c.events.where((e) => e == 'refresh').length, 1);
      expect(c.adapter.requestCount, 2);
    });

    test('single-flight: 2 concurrent 401s trigger exactly ONE refresh',
        () async {
      // The gate holds the refresh open so BOTH 401s reach the latch before it
      // resolves — the realistic concurrent case. Without single-flight this
      // would issue two refreshes.
      final gate = Completer<void>();
      final c = _buildClient(refreshSucceeds: true, refreshGate: gate.future);

      final inFlight = Future.wait(<Future<Response<dynamic>>>[
        c.dio.get<Map<String, dynamic>>('/a'),
        c.dio.get<Map<String, dynamic>>('/b'),
      ]);

      // Let both requests 401 and enter the shared-refresh latch, then release.
      // A real (non-zero) delay guarantees both error handlers have run and
      // both have awaited the shared latch before the single refresh resolves.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      final results = await inFlight;

      for (final r in results) {
        expect(r.statusCode, 200);
      }
      // Both 401s collapse onto a single refresh call.
      expect(c.events.where((e) => e == 'refresh').length, 1);
    });

    test('refresh failure invokes onUnrecoverable and propagates', () async {
      final c = _buildClient(refreshSucceeds: false);

      await expectLater(
        c.dio.get<dynamic>('/protected'),
        throwsA(isA<DioException>()),
      );
      expect(c.events, contains('unrecoverable'));
      // Refreshed once, never retried (refresh failed) -> original 401 only.
      expect(c.adapter.requestCount, 1);
    });

    test('no infinite loop when the retried request 401s again', () async {
      // refresh "succeeds" but the server keeps 401ing even the retried call.
      final c = _buildClient(refreshSucceeds: true, alwaysUnauthorized: true);

      await expectLater(
        c.dio.get<dynamic>('/protected'),
        throwsA(isA<DioException>()),
      );
      // original 401 + ONE retried 401 = 2 transport calls, then it stops.
      expect(c.adapter.requestCount, 2);
      expect(c.events.where((e) => e == 'refresh').length, 1);
      expect(c.events, contains('unrecoverable'));
    });
  });
}
