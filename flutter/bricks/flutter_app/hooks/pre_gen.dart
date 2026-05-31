import 'package:mason/mason.dart';

/// Derives convenience vars the templates need but mustache cannot compute:
/// - `home_key`: the first tab's `key` (used for the route-whitelist home
///   fallback and the initial location).
///
/// Also normalizes `tabs` to a list of maps so the template iteration is stable
/// regardless of how the caller passed `--tabs` (JSON array or config file).
void run(HookContext context) {
  final vars = context.vars;
  final tabs = (vars['tabs'] as List<dynamic>?) ?? const <dynamic>[];

  if (tabs.isEmpty) {
    throw Exception(
      'flutter_app brick needs at least one tab (each {key,label,icon}).',
    );
  }

  final firstTab = tabs.first;
  final homeKey = firstTab is Map
      ? (firstTab['key']?.toString() ?? 'home')
      : firstTab.toString();
  final homeLabel = firstTab is Map
      ? (firstTab['label']?.toString() ?? homeKey)
      : homeKey;

  context.vars = {
    ...vars,
    'home_key': homeKey,
    'home_label': homeLabel,
  };
}
