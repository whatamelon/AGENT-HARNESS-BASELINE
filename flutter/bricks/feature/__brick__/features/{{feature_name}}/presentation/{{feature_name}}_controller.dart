{{#is_list}}{{#with_domain}}import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:{{package_name}}/features/{{feature_name}}/data/{{feature_name}}_repository.dart';
import 'package:{{package_name}}/features/{{feature_name}}/domain/{{feature_name}}.dart';

/// AsyncNotifier for the {{feature_name}} list. `build` is the initial load;
/// the screen renders `AsyncValue.when(loading/error/data)` so no state is
/// missed. Retry = `ref.invalidate(provider)` (re-runs `build`).
///
/// The repository is injected via `{{feature_name.camelCase()}}RepositoryProvider`
/// so tests can override it with a fake.
class {{feature_name.pascalCase()}}Controller
    extends AsyncNotifier<List<{{feature_name.pascalCase()}}>> {
  @override
  Future<List<{{feature_name.pascalCase()}}>> build() => _fetch();

  Future<List<{{feature_name.pascalCase()}}>> _fetch() async {
    final result = await ref
        .read({{feature_name.camelCase()}}RepositoryProvider)
        .fetchAll();
    return switch (result) {
      Ok(value: final items) => items,
      Err(failure: final f) => throw f,
    };
  }
}

/// Provider for the {{feature_name}} controller.
final AsyncNotifierProvider<{{feature_name.pascalCase()}}Controller,
        List<{{feature_name.pascalCase()}}>>
    {{feature_name.camelCase()}}ControllerProvider =
    AsyncNotifierProvider<{{feature_name.pascalCase()}}Controller,
        List<{{feature_name.pascalCase()}}>>(
  {{feature_name.pascalCase()}}Controller.new,
);{{/with_domain}}{{^with_domain}}import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AsyncNotifier for the {{feature_name}} list (presentation-only slice).
///
/// `build` returns placeholder rows so the slice compiles and runs offline;
/// the screen renders `AsyncValue.when(loading/error/data)`. Replace the body
/// with a repository call (regenerate with `--with_domain true` to scaffold the
/// data/domain layers and a typed entity).
class {{feature_name.pascalCase()}}Controller extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async => const <String>[];
}

/// Provider for the {{feature_name}} controller.
final AsyncNotifierProvider<{{feature_name.pascalCase()}}Controller, List<String>>
    {{feature_name.camelCase()}}ControllerProvider =
    AsyncNotifierProvider<{{feature_name.pascalCase()}}Controller, List<String>>(
  {{feature_name.pascalCase()}}Controller.new,
);{{/with_domain}}{{/is_list}}{{#is_detail}}{{#with_domain}}import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:{{package_name}}/features/{{feature_name}}/data/{{feature_name}}_repository.dart';
import 'package:{{package_name}}/features/{{feature_name}}/domain/{{feature_name}}.dart';

/// AsyncNotifier for the {{feature_name}} detail (single entity, nullable).
/// `build` loads the entity; the screen renders
/// `AsyncValue.when(loading/error/data)` and treats `null` data as empty.
/// Retry = `ref.invalidate(provider)`.
///
/// The repository is injected via `{{feature_name.camelCase()}}RepositoryProvider`
/// so tests can override it with a fake.
class {{feature_name.pascalCase()}}Controller
    extends AsyncNotifier<{{feature_name.pascalCase()}}?> {
  @override
  Future<{{feature_name.pascalCase()}}?> build() => _fetch();

  Future<{{feature_name.pascalCase()}}?> _fetch() async {
    final result = await ref
        .read({{feature_name.camelCase()}}RepositoryProvider)
        .fetchOne();
    return switch (result) {
      Ok(value: final entity) => entity,
      Err(failure: final f) => throw f,
    };
  }
}

/// Provider for the {{feature_name}} controller.
final AsyncNotifierProvider<{{feature_name.pascalCase()}}Controller,
        {{feature_name.pascalCase()}}?>
    {{feature_name.camelCase()}}ControllerProvider =
    AsyncNotifierProvider<{{feature_name.pascalCase()}}Controller,
        {{feature_name.pascalCase()}}?>(
  {{feature_name.pascalCase()}}Controller.new,
);{{/with_domain}}{{^with_domain}}import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AsyncNotifier for the {{feature_name}} detail (presentation-only slice).
///
/// `build` returns a placeholder string so the slice compiles and runs offline;
/// the screen renders `AsyncValue.when(loading/error/data)`. Replace the body
/// with a repository call (regenerate with `--with_domain true` to scaffold the
/// data/domain layers and a typed entity).
class {{feature_name.pascalCase()}}Controller extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => '{{feature_name.titleCase()}}';
}

/// Provider for the {{feature_name}} controller.
final AsyncNotifierProvider<{{feature_name.pascalCase()}}Controller, String?>
    {{feature_name.camelCase()}}ControllerProvider =
    AsyncNotifierProvider<{{feature_name.pascalCase()}}Controller, String?>(
  {{feature_name.pascalCase()}}Controller.new,
);{{/with_domain}}{{/is_detail}}{{#is_form}}import 'package:core/core.dart';
import 'package:ds/ds.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
{{#with_domain}}import 'package:{{package_name}}/features/{{feature_name}}/data/{{feature_name}}_repository.dart';
{{/with_domain}}
/// Form view state: current field values, per-field validation status + helper
/// text, and an in-flight flag for the submit CTA.
@immutable
class {{feature_name.pascalCase()}}FormState {
  const {{feature_name.pascalCase()}}FormState({
    this.values = const <String, String>{},
    this.fieldStatus = const <String, DsFieldStatus>{},
    this.fieldHelper = const <String, String>{},
    this.isSubmitting = false,
  });

  final Map<String, String> values;
  final Map<String, DsFieldStatus> fieldStatus;
  final Map<String, String> fieldHelper;
  final bool isSubmitting;

  {{feature_name.pascalCase()}}FormState copyWith({
    Map<String, String>? values,
    Map<String, DsFieldStatus>? fieldStatus,
    Map<String, String>? fieldHelper,
    bool? isSubmitting,
  }) {
    return {{feature_name.pascalCase()}}FormState(
      values: values ?? this.values,
      fieldStatus: fieldStatus ?? this.fieldStatus,
      fieldHelper: fieldHelper ?? this.fieldHelper,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// Notifier for the {{feature_name}} form. Holds field values + validation,
/// validates on submit, and returns a `Result` so the screen handles failure
/// without throwing. Replace [fieldKeys] and the [submit] validation with the
/// real schema; prefer a typed validator at the boundary for non-trivial forms.
class {{feature_name.pascalCase()}}Controller
    extends Notifier<{{feature_name.pascalCase()}}FormState> {
  /// Field keys rendered as labels (replace with the real form schema).
  static const List<String> fieldKeys = <String>['이름', '연락처'];

  @override
  {{feature_name.pascalCase()}}FormState build() =>
      const {{feature_name.pascalCase()}}FormState();

  /// Updates one field's value and clears its prior validation status.
  void updateField(String key, String value) {
    state = state.copyWith(
      values: <String, String>{...state.values, key: value},
      fieldStatus: <String, DsFieldStatus>{...state.fieldStatus}..remove(key),
      fieldHelper: <String, String>{...state.fieldHelper}..remove(key),
    );
  }

  /// Validates all fields, then submits when valid. On local validation failure
  /// returns `null` (the UI reads per-field status); otherwise returns the
  /// backend submit `Result` (`Ok(null)` on success). Always clears
  /// `isSubmitting` before returning a non-null Result.
  Future<Result<void, AppException>?> submit() async {
    final status = <String, DsFieldStatus>{};
    final helper = <String, String>{};
    for (final key in fieldKeys) {
      final value = state.values[key]?.trim() ?? '';
      if (value.isEmpty) {
        status[key] = DsFieldStatus.error;
        helper[key] = '$key을(를) 입력해 주세요.';
      } else {
        status[key] = DsFieldStatus.success;
      }
    }
    if (status.values.any((s) => s == DsFieldStatus.error)) {
      state = state.copyWith(fieldStatus: status, fieldHelper: helper);
      return null;
    }

    state = state.copyWith(
      fieldStatus: status,
      fieldHelper: helper,
      isSubmitting: true,
    );
{{#with_domain}}    final result = await ref
        .read({{feature_name.camelCase()}}RepositoryProvider)
        .submit(state.values);
    state = state.copyWith(isSubmitting: false);
    return result;
{{/with_domain}}{{^with_domain}}    // Wire a repository here (regenerate with `--with_domain true`).
    state = state.copyWith(isSubmitting: false);
    return const Result.ok(null);
{{/with_domain}}  }
}

/// Provider for the {{feature_name}} controller.
final NotifierProvider<{{feature_name.pascalCase()}}Controller,
        {{feature_name.pascalCase()}}FormState>
    {{feature_name.camelCase()}}ControllerProvider =
    NotifierProvider<{{feature_name.pascalCase()}}Controller,
        {{feature_name.pascalCase()}}FormState>(
  {{feature_name.pascalCase()}}Controller.new,
);{{/is_form}}
