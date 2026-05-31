/// Local persistence for a guest (pre-login) collection over
/// `shared_preferences`.
///
/// Generic and app-agnostic: `T` is the domain item type. Items persist as a
/// list of JSON strings via caller-supplied `encode`/`decode` closures, so the
/// store never depends on any concrete cart/wishlist type.
///
/// Storage choice: guest cart/wishlist data is NON-SENSITIVE (no PII, no
/// credentials), so plain prefs are appropriate. Secrets and tokens must NOT
/// be stored here — use secure storage in core for those.
///
/// The prefs instance is injected so tests use an in-memory fake via
/// `SharedPreferences.setMockInitialValues({})`.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Persists a guest collection list under a single `shared_preferences` key.
class GuestCollectionStore<T> {
  /// Creates a store bound to a prefs instance and a storage [key].
  GuestCollectionStore(
    this._prefs, {
    required this.key,
    required this.encode,
    required this.decode,
  });

  final SharedPreferences _prefs;

  /// The `shared_preferences` key under which the encoded list is stored.
  final String key;

  /// Serializes a single item to a JSON string for persistence.
  final String Function(T item) encode;

  /// Deserializes a single JSON string back into an item.
  final T Function(String raw) decode;

  /// Loads the persisted items. Returns an empty list when nothing is stored.
  Future<List<T>> load() async {
    final raw = _prefs.getStringList(key);
    if (raw == null) return <T>[];
    return raw.map(decode).toList(growable: false);
  }

  /// Persists [items], replacing any previously stored value.
  Future<void> save(List<T> items) async {
    final raw = items.map(encode).toList(growable: false);
    await _prefs.setStringList(key, raw);
  }

  /// Removes the persisted value entirely (e.g. after merging into a logged-in
  /// account).
  Future<void> clear() async {
    await _prefs.remove(key);
  }
}
