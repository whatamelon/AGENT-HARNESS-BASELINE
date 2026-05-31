{{#with_domain}}import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
{{^is_form}}import 'package:{{package_name}}/features/{{feature_name}}/domain/{{feature_name}}.dart';
{{/is_form}}
/// Repository for the {{feature_name}} feature. Returns a `Result` so the
/// controller handles failure without throwing.
///
/// The skeleton ships an in-memory stub so the slice compiles and runs offline.
/// Subclass and override with a real `ApiClient` / Supabase query, then swap the
/// implementation in via `{{feature_name.camelCase()}}RepositoryProvider`.
class {{feature_name.pascalCase()}}Repository {
  const {{feature_name.pascalCase()}}Repository();
{{#is_list}}
  /// Loads the collection. Stub returns an empty list (drives the empty state).
  Future<Result<List<{{feature_name.pascalCase()}}>, AppException>>
      fetchAll() async {
    return const Result.ok(<{{feature_name.pascalCase()}}>[]);
  }
{{/is_list}}{{#is_detail}}
  /// Loads the single entity. Stub returns `null` (drives the empty state).
  Future<Result<{{feature_name.pascalCase()}}?, AppException>> fetchOne() async {
    return const Result.ok(null);
  }
{{/is_detail}}{{#is_form}}
  /// Submits the validated field values. Stub succeeds with no side effect.
  Future<Result<void, AppException>> submit(
    Map<String, String> values,
  ) async {
    return const Result.ok(null);
  }
{{/is_form}}}

/// Provider for the {{feature_name}} repository. Override in tests / when the
/// real data source is wired.
final Provider<{{feature_name.pascalCase()}}Repository>
    {{feature_name.camelCase()}}RepositoryProvider =
    Provider<{{feature_name.pascalCase()}}Repository>(
  (ref) => const {{feature_name.pascalCase()}}Repository(),
);
{{/with_domain}}