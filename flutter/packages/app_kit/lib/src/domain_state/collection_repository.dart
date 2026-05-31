/// Abstract port for a remotely-backed keyed collection (cart, wishlist).
///
/// Generic and app-agnostic: the item type is supplied by the app. Concrete
/// implementations talk to Supabase / the Next.js BFF and translate
/// transport/server errors into `AppException` subtypes (e.g.
/// `ConflictException` for version conflicts). The harness ships only the
/// contract.
library;

import 'package:core/core.dart';

/// Port returning `Result`s for a keyed collection's CRUD operations.
///
/// Money-safety: implementations must treat any monetary fields on [T] as
/// server-authoritative. The client never computes authoritative totals; it
/// only renders what [fetch]/[upsert] return.
abstract class CollectionRepository<T> {
  /// Loads the full collection for the current actor.
  Future<Result<List<T>, AppException>> fetch();

  /// Inserts or updates a single [item], returning the server-confirmed value.
  ///
  /// The confirmed value may differ from [item] (server-assigned id, normalized
  /// quantity, recomputed price), so callers must reconcile against it rather
  /// than assuming the optimistic input is authoritative.
  Future<Result<T, AppException>> upsert(T item);

  /// Removes the item identified by [key].
  Future<Result<void, AppException>> remove(String key);
}
