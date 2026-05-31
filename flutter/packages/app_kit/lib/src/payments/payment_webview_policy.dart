/// §8-A webview hardening for the payment surface.
///
/// The Toss `PaymentMethodWidget`/`AgreementWidget` render a webview that loads
/// only Toss-issued HTML and, for bank/card app hand-off, custom schemes the
/// SDK handles internally. The app layer never feeds an arbitrary URL into that
/// webview. This policy is the explicit, testable allow-set the host consults
/// before forwarding ANY external redirect (e.g. a deep-link return from an
/// external bank app via `PaymentWidget.handlePaymentRedirect`): only Toss
/// payment domains are accepted; everything else is dropped.
///
/// Pure and SDK-free so it is fully unit-testable (mirrors `route_whitelist`).
library;

/// Allow-set of Toss payment host suffixes the payment webview may load.
///
/// Matching is suffix-based on the URL host so `pay.toss.im`,
/// `api.tosspayments.com`, etc. are accepted while a look-alike like
/// `tosspayments.com.evil.example` is rejected (the host must END WITH a
/// dotted form of an allowed suffix, or equal it exactly).
class PaymentWebViewPolicy {
  /// Creates a [PaymentWebViewPolicy] with the default Toss allow-set.
  const PaymentWebViewPolicy({
    this.allowedHostSuffixes = const <String>{
      'tosspayments.com',
      'toss.im',
    },
  });

  /// Allowed host suffixes (lower-cased, no leading dot).
  final Set<String> allowedHostSuffixes;

  /// Whether [url] points at an allowed Toss payment host over HTTPS.
  ///
  /// Rejects non-HTTPS, unparseable, or non-allowlisted hosts. Used as the
  /// guard before forwarding any externally-sourced redirect into the active
  /// Toss payment window.
  bool isAllowed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.toLowerCase() != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    for (final suffix in allowedHostSuffixes) {
      final s = suffix.toLowerCase();
      if (host == s || host.endsWith('.$s')) return true;
    }
    return false;
  }
}
