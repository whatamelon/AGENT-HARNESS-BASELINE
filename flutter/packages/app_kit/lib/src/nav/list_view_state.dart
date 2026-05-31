/// Category-2 "view intent" state: filters, sort, query, and a *semantic*
/// scroll anchor for a list route.
///
/// This is the §3.1 route-scoped intent provider. It holds the user's *intent*
/// (what they chose to see) — never server data. Keeping intent in a
/// route-scoped provider (not widget `setState`) is what lets a list survive a
/// detail push + back, a tab swap, and (later) a process restart: the list
/// Element can die, but the intent in the `ProviderContainer` does not.
///
/// §8-B boundary: this file MUST NOT import anything from `core` auth or
/// `src/auth/`. View intent is orthogonal to who is signed in.
library;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:meta/meta.dart';

/// Immutable snapshot of a list route's view intent.
///
/// All fields describe *intent*, not server results:
/// - [filters]: active filter key -> value selections.
/// - [sort]: the chosen sort key (`''` = default order).
/// - [query]: the current search text (`''` = no search).
/// - [scrollAnchor]: the *semantic* first-visible item id, NOT a pixel offset.
///   A pixel offset is meaningless once the underlying list changes; an item id
///   lets a restore jump to the right row only after re-validation confirms the
///   item still exists.
@immutable
class ListViewState {
  /// Creates a [ListViewState]. Defaults represent an untouched list (no
  /// filters, default sort, no query, no remembered anchor).
  const ListViewState({
    this.filters = const {},
    this.sort = '',
    this.query = '',
    this.scrollAnchor,
  });

  /// Active filter key -> value selections.
  final Map<String, String> filters;

  /// The chosen sort key (`''` keeps the default order).
  final String sort;

  /// The current search text (`''` means no active search).
  final String query;

  /// Semantic first-visible item id (NOT a pixel offset), or `null`.
  final String? scrollAnchor;

  /// Returns a copy with the provided overrides.
  ///
  /// Pass `clearScrollAnchor: true` to reset [scrollAnchor] to `null` (a plain
  /// `scrollAnchor: null` cannot distinguish "unset" from "no change").
  ListViewState copyWith({
    Map<String, String>? filters,
    String? sort,
    String? query,
    String? scrollAnchor,
    bool clearScrollAnchor = false,
  }) {
    return ListViewState(
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      query: query ?? this.query,
      scrollAnchor:
          clearScrollAnchor ? null : (scrollAnchor ?? this.scrollAnchor),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ListViewState &&
      mapEquals(other.filters, filters) &&
      other.sort == sort &&
      other.query == query &&
      other.scrollAnchor == scrollAnchor;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(
          filters.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        sort,
        query,
        scrollAnchor,
      );
}

/// Route-scoped notifier for a single list route's [ListViewState].
///
/// The family argument is the route key (e.g. `'/park/shop'`), supplied via the
/// constructor (Riverpod 3 family-notifier shape), so each list route gets an
/// independent, addressable intent slice. All mutations return a new
/// [ListViewState] via `copyWith` (no in-place mutation).
class ListViewStateNotifier extends Notifier<ListViewState> {
  /// Creates the notifier for [routeKey] (the family argument).
  ListViewStateNotifier(this.routeKey);

  /// The route key this slice belongs to (the family argument).
  final String routeKey;

  @override
  ListViewState build() => const ListViewState();

  /// Sets a single [key] -> [value] filter, preserving the rest.
  void setFilter(String key, String value) {
    state = state.copyWith(filters: {...state.filters, key: value});
  }

  /// Removes the filter under [key], preserving the rest.
  void removeFilter(String key) {
    state = state.copyWith(
      filters: <String, String>{
        for (final entry in state.filters.entries)
          if (entry.key != key) entry.key: entry.value,
      },
    );
  }

  /// Clears all filters, keeping sort/query/anchor.
  void clearFilters() => state = state.copyWith(filters: const {});

  /// Sets the [sort] key.
  void setSort(String sort) => state = state.copyWith(sort: sort);

  /// Sets the search [query] text.
  void setQuery(String query) => state = state.copyWith(query: query);

  /// Remembers the semantic scroll anchor [id]. Pass `null` to forget it.
  void rememberAnchor(String? id) {
    state = id == null
        ? state.copyWith(clearScrollAnchor: true)
        : state.copyWith(scrollAnchor: id);
  }
}

/// Route-scoped view-intent provider, keyed by route key.
///
/// `isAutoDispose: true` keeps idle list intents from leaking, while a hot
/// browse-loop route can pin its slice alive via `ref.keepAlive()` in the
/// derived data provider (§13.3 keepAlive primitive). The intent itself never
/// triggers a server fetch; an app-layer data provider watches this and derives
/// the request from it (§3.1).
final NotifierProviderFamily<ListViewStateNotifier, ListViewState, String>
    listViewStateProvider =
    NotifierProvider.family<ListViewStateNotifier, ListViewState, String>(
  ListViewStateNotifier.new,
  isAutoDispose: true,
);
