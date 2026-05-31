import 'package:mason/mason.dart';

/// Derives per-value booleans from the `archetype` enum so templates can branch
/// with `{{#is_list}}` / `{{#is_detail}}` / `{{#is_form}}` sections.
///
/// mason 0.1.x exposes an `enum` var only as a string (`{{archetype}}`); it does
/// not generate a boolean per value, and mustache has no equality operator. We
/// compute the booleans here once so the screen/controller templates stay flat
/// (three sibling sections, no string comparisons in the view layer).
void run(HookContext context) {
  final archetype = context.vars['archetype'] as String? ?? 'list';
  context.vars = <String, dynamic>{
    ...context.vars,
    'is_list': archetype == 'list',
    'is_detail': archetype == 'detail',
    'is_form': archetype == 'form',
  };
}
