import 'package:app_kit/app_kit.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChromeController', () {
    test('default state uses the resolver policy and is visible', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(defaultChromeControllerProvider);
      expect(state.policy, const RouteChromePolicy());
      expect(state.visible, isTrue);
    });

    test('onRouteChanged applies the resolved policy', () {
      RouteChromePolicy resolver(String path) => path == '/detail'
          ? const RouteChromePolicy(
              appBarTitle: '상세',
              showBottomNav: false,
            )
          : const RouteChromePolicy(appBarTitle: '홈');

      final provider = chromeControllerProvider(resolver);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(provider.notifier).onRouteChanged('/detail');
      final state = container.read(provider);
      expect(state.policy.appBarTitle, '상세');
      expect(state.policy.showBottomNav, isFalse);
    });

    test('onRouteChanged resets visibility to shown', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier =
          container.read(defaultChromeControllerProvider.notifier);
      expect(
        container.read(defaultChromeControllerProvider).visible,
        isTrue,
      );
      notifier.onScroll(ScrollDirection.reverse);
      expect(
        container.read(defaultChromeControllerProvider).visible,
        isFalse,
      );

      notifier.onRouteChanged('/other');
      expect(container.read(defaultChromeControllerProvider).visible, isTrue);
    });

    test('onScroll reverse hides, forward reveals, idle no-ops', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier =
          container.read(defaultChromeControllerProvider.notifier);
      expect(
        container.read(defaultChromeControllerProvider).visible,
        isTrue,
      );

      notifier.onScroll(ScrollDirection.reverse);
      expect(
        container.read(defaultChromeControllerProvider).visible,
        isFalse,
      );

      notifier.onScroll(ScrollDirection.idle);
      expect(
        container.read(defaultChromeControllerProvider).visible,
        isFalse,
      );

      notifier.onScroll(ScrollDirection.forward);
      expect(container.read(defaultChromeControllerProvider).visible, isTrue);
    });
  });

  group('RouteChromePolicy', () {
    test('copyWith overrides only provided fields', () {
      const base = RouteChromePolicy(appBarTitle: '홈');
      final next = base.copyWith(showBottomNav: false);
      expect(next.appBarTitle, '홈');
      expect(next.showBottomNav, isFalse);
      expect(next.showAppBar, isTrue);
    });

    test('value equality + hashCode', () {
      expect(
        const RouteChromePolicy(appBarTitle: 'a'),
        const RouteChromePolicy(appBarTitle: 'a'),
      );
      expect(
        const RouteChromePolicy(appBarTitle: 'a').hashCode,
        const RouteChromePolicy(appBarTitle: 'a').hashCode,
      );
      expect(
        const RouteChromePolicy(appBarTitle: 'a') ==
            const RouteChromePolicy(appBarTitle: 'b'),
        isFalse,
      );
    });

    test('default resolver returns default policy for any path', () {
      expect(defaultChromePolicyResolver('/x'), const RouteChromePolicy());
    });
  });
}
