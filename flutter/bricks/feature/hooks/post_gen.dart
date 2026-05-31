import 'dart:io';

import 'package:mason/mason.dart';

/// Tidies the generated feature slice (mason runs this with the output dir as
/// the working directory):
/// - Deletes empty `.dart` files (e.g. the domain/data stubs that render empty
///   when `with_domain` is false) and prunes the now-empty directories.
/// - Normalizes each remaining `.dart` file to end with exactly one trailing
///   newline (mustache section tags can leave a trailing blank line).
void run(HookContext context) {
  final featureName = context.vars['feature_name'] as String;
  final withDomain = context.vars['with_domain'] as bool? ?? false;
  final archetype = context.vars['archetype'] as String? ?? 'list';

  final featureDir = Directory('features/$featureName');
  if (!featureDir.existsSync()) return;

  for (final entity in featureDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    if (content.trim().isEmpty) {
      entity.deleteSync();
      continue;
    }
    final normalized = '${content.trimRight()}\n';
    if (normalized != content) entity.writeAsStringSync(normalized);
  }

  // Prune empty layer dirs (domain/data left empty when with_domain is false).
  for (final dir in <String>['domain', 'data', 'presentation']) {
    final d = Directory('features/$featureName/$dir');
    if (d.existsSync() && d.listSync().isEmpty) d.deleteSync();
  }

  context.logger
    ..info('')
    ..success('Generated feature: features/$featureName '
        '[$archetype] '
        '(${withDomain ? 'domain + data + presentation' : 'presentation only'})')
    ..info('Register the route per the snippet at the bottom of '
        '${featureName}_screen.dart.');
}
