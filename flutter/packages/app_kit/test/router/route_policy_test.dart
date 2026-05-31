import 'package:app_kit/src/router/route_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteAuthPolicy', () {
    test('defaults to /login and /splash paths', () {
      final policy = RouteAuthPolicy(levelFor: (_) => RouteAuthLevel.public);
      expect(policy.loginPath, '/login');
      expect(policy.splashPath, '/splash');
    });

    test('custom paths are honored', () {
      final policy = RouteAuthPolicy(
        levelFor: (_) => RouteAuthLevel.protected,
        loginPath: '/auth/sign-in',
        splashPath: '/boot',
      );
      expect(policy.loginPath, '/auth/sign-in');
      expect(policy.splashPath, '/boot');
    });

    test('levelFor maps paths to levels', () {
      RouteAuthLevel resolve(String path) {
        if (path.startsWith('/onyu/emergency')) return RouteAuthLevel.public;
        if (path.startsWith('/park/payment')) return RouteAuthLevel.stepUp;
        return RouteAuthLevel.protected;
      }

      final policy = RouteAuthPolicy(levelFor: resolve);
      expect(policy.levelFor('/onyu/emergency'), RouteAuthLevel.public);
      expect(policy.levelFor('/park/payment/confirm'), RouteAuthLevel.stepUp);
      expect(policy.levelFor('/park/mypage'), RouteAuthLevel.protected);
    });
  });
}
