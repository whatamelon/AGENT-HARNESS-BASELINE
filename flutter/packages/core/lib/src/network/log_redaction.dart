/// PII / secret redaction for network logging.
///
/// Applied before any request/response detail reaches the logger so tokens,
/// emails, and phone numbers never land in logs (§8-A security).
library;

/// Masks sensitive substrings in a free-form [input] string.
///
/// Redacts: bearer/authorization tokens, raw JWTs (`eyJ…`), email addresses,
/// KR phone numbers, and apikey headers.
/// Pure and allocation-cheap; safe to call on every log line.
String redactSensitive(String input) {
  var out = input;
  // JWT first: catches bare tokens before the Bearer pattern strips its prefix.
  out = out.replaceAll(_jwt, '***JWT***');
  out = out.replaceAll(_bearer, 'Bearer ***');
  out = out.replaceAll(_email, '***@***');
  out = out.replaceAll(_phone, '***-****-****');
  out = out.replaceAll(_apiKeyHeader, r'$1: ***');
  return out;
}

/// Returns a copy of [headers] with sensitive values masked.
Map<String, Object?> redactHeaders(Map<String, Object?> headers) {
  return <String, Object?>{
    for (final entry in headers.entries)
      entry.key: _isSensitiveHeader(entry.key) ? '***' : entry.value,
  };
}

bool _isSensitiveHeader(String name) {
  final lower = name.toLowerCase();
  return lower == 'authorization' ||
      lower == 'apikey' ||
      lower == 'cookie' ||
      lower == 'set-cookie';
}

// Matches a bare JWT (header.payload.signature) that appears in free-form text.
// Pattern: eyJ<base64url-10+>.<base64url-10+>.<base64url-0+>
// Runs before _bearer so a "Bearer eyJ…" is caught here first, then the
// residual "Bearer ***" form is masked by _bearer (double-masking is harmless).
final RegExp _jwt = RegExp(
  r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]*',
);
final RegExp _bearer = RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*');
final RegExp _email = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
final RegExp _phone = RegExp(r'\b01[016789][-\s]?\d{3,4}[-\s]?\d{4}\b');
final RegExp _apiKeyHeader =
    RegExp(r'(apikey|authorization|cookie)\s*:\s*\S+', caseSensitive: false);
