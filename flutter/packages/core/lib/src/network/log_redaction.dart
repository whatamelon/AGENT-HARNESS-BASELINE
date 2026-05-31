/// PII / secret redaction for network logging.
///
/// Applied before any request/response detail reaches the logger so tokens,
/// emails, and phone numbers never land in logs (§8-A security).
library;

/// Masks sensitive substrings in a free-form [input] string.
///
/// Redacts: bearer/authorization tokens, email addresses, and KR phone numbers.
/// Pure and allocation-cheap; safe to call on every log line.
String redactSensitive(String input) {
  var out = input;
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

final RegExp _bearer = RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*');
final RegExp _email = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
final RegExp _phone = RegExp(r'\b01[016789][-\s]?\d{3,4}[-\s]?\d{4}\b');
final RegExp _apiKeyHeader =
    RegExp(r'(apikey|authorization|cookie)\s*:\s*\S+', caseSensitive: false);
