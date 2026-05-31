import 'dart:developer' as developer;

/// Severity levels, ordered from least to most severe.
enum LogLevel { debug, info, warn, error }

/// Lightweight structured logger with PII redaction.
///
/// Real sinks (Sentry breadcrumbs, file, remote) are wired in P3; for P0 this
/// emits via `dart:developer.log` and always redacts sensitive patterns before
/// the message leaves the process.
class AppLogger {
  const AppLogger({this.name = 'app', this.minLevel = LogLevel.debug});

  /// Logical channel name attached to every record.
  final String name;

  /// Records below this level are dropped.
  final LogLevel minLevel;

  void debug(String message) => _log(LogLevel.debug, message);

  void info(String message) => _log(LogLevel.info, message);

  void warn(String message) => _log(LogLevel.warn, message);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message, error: error, stackTrace: stackTrace);

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;
    developer.log(
      redact(message),
      name: '$name/${level.name}',
      level: _developerLevel(level),
      error: error == null ? null : redact('$error'),
      stackTrace: stackTrace,
    );
  }

  int _developerLevel(LogLevel level) => switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warn => 900,
        LogLevel.error => 1000,
      };

  /// Masks emails, phone numbers, and bearer/JWT-like tokens.
  ///
  /// Stub for P0 — pattern set is intentionally small and conservative.
  /// Hardened in P3 alongside the observability pipeline.
  static String redact(String input) {
    return input
        .replaceAll(_emailPattern, '[redacted-email]')
        .replaceAll(_tokenPattern, '[redacted-token]')
        .replaceAll(_phonePattern, '[redacted-phone]');
  }

  static final RegExp _emailPattern = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
  );

  // Bearer tokens and JWT-shaped strings (three base64url segments).
  static final RegExp _tokenPattern = RegExp(
    r'(?:[Bb]earer\s+[A-Za-z0-9._\-]+)|(?:eyJ[A-Za-z0-9._\-]{10,})',
  );

  // Korean/international phone numbers, loosely matched.
  static final RegExp _phonePattern = RegExp(
    r'(?:\+?\d{1,3}[\s\-]?)?(?:0?1[\s\-]?\d{1,2}[\s\-]?)?\d{3,4}[\s\-]\d{4}',
  );
}
