{{#with_domain}}{{^is_form}}import 'package:flutter/foundation.dart';

/// {{feature_name.titleCase()}} domain entity. Pure Dart, no Flutter/SDK deps;
/// the data layer maps DTOs into this.
@immutable
class {{feature_name.pascalCase()}} {
  const {{feature_name.pascalCase()}}({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is {{feature_name.pascalCase()}} &&
          other.id == id &&
          other.title == title);

  @override
  int get hashCode => Object.hash(id, title);
}
{{/is_form}}{{/with_domain}}