import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mirror of `dart run tool/gen_tokens.dart --check`: fail if any committed
/// generated file drifts from tokens.json. Keeps the drift gate inside the
/// normal `flutter test` run as well as CI.
void main() {
  test('generated token files are not stale (run tokens:gen if this fails)',
      () {
    final root = _packageRoot();
    final result = Process.runSync(
      'dart',
      ['run', 'tool/gen_tokens.dart', '--check'],
      workingDirectory: root,
    );
    expect(
      result.exitCode,
      0,
      reason: 'Token drift:\n${result.stdout}\n${result.stderr}',
    );
  });
}

/// Resolve the ds package root from the test file location.
String _packageRoot() {
  final dir = Directory.current;
  // `flutter test` runs with cwd = package root already, but be defensive.
  if (File('${dir.path}/tokens/tokens.json').existsSync()) return dir.path;
  final candidate = Directory('${dir.path}/packages/ds');
  if (candidate.existsSync()) return candidate.path;
  return dir.path;
}
