import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentWebViewPolicy (§8-A webview allowlist)', () {
    const policy = PaymentWebViewPolicy();

    test('allows Toss payment hosts over https', () {
      expect(policy.isAllowed('https://pay.toss.im/redirect'), isTrue);
      expect(policy.isAllowed('https://api.tosspayments.com/v1'), isTrue);
      expect(policy.isAllowed('https://tosspayments.com'), isTrue);
      expect(policy.isAllowed('https://toss.im'), isTrue);
    });

    test('rejects look-alike / suffix-spoofing hosts', () {
      expect(
        policy.isAllowed('https://tosspayments.com.evil.example/x'),
        isFalse,
      );
      expect(policy.isAllowed('https://nottoss.im/x'), isFalse);
      expect(policy.isAllowed('https://evil.example/tosspayments.com'), isFalse);
    });

    test('rejects non-https schemes', () {
      expect(policy.isAllowed('http://pay.toss.im'), isFalse);
      expect(policy.isAllowed('intent://pay.toss.im'), isFalse);
      expect(policy.isAllowed('javascript:alert(1)'), isFalse);
    });

    test('rejects empty / unparseable urls', () {
      expect(policy.isAllowed(''), isFalse);
      expect(policy.isAllowed('not a url'), isFalse);
    });
  });
}
