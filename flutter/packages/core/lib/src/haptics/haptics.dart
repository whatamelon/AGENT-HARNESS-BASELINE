/// SDK-neutral semantic haptic feedback port.
///
/// Mirrors the `analytics_sink.dart` convention: nothing here imports a
/// platform haptics SDK, so the boundary stays one-way and the wiring stays
/// testable. Callers speak in *intent* ("this was a selection", "this action
/// succeeded") rather than in concrete `lightImpact()/heavyImpact()` calls, so
/// the physical mapping can evolve (e.g. real iOS notification haptics via a
/// plugin) without touching call sites. The harness ships `NoopHaptics`
/// (default), `PlatformHaptics` (wiring), and `ThrottlingHaptics` (decorator).
library;

/// Curated semantic haptic intents. Keep this set small — every value must
/// earn its place, otherwise haptics become noise. Map UI events onto the
/// closest intent rather than inventing per-screen variants.
enum HapticIntent {
  /// A discrete selection changed: chip/tab/toggle switch, segment change,
  /// picker tick. The lightest, most frequent feedback.
  selection,

  /// A light, transient touch: tap acknowledgement, sheet snap, pull-to-refresh
  /// trigger. Slightly more substantial than [selection].
  light,

  /// A primary action was committed: submit, confirm, add-to-cart, save.
  medium,

  /// A consequential/heavy action: irreversible or high-stakes commit
  /// (delete, final purchase). Use sparingly.
  heavy,

  /// A successful outcome: operation completed as the user intended.
  success,

  /// A cautionary outcome: the user should pay attention (validation warning,
  /// soft limit reached) but nothing failed.
  warning,

  /// A failed outcome: the operation could not complete (network error,
  /// rejected input).
  error,
}

/// SDK-neutral haptics port. Implementations turn a [HapticIntent] into actual
/// device feedback (or discard it).
///
/// All methods are async to match SDK shapes but must never throw — haptics is
/// best-effort decoration and must not break the calling flow.
abstract class Haptics {
  /// Performs the feedback for [intent].
  Future<void> perform(HapticIntent intent);

  /// Convenience: [HapticIntent.selection].
  Future<void> selection() => perform(HapticIntent.selection);

  /// Convenience: [HapticIntent.light].
  Future<void> light() => perform(HapticIntent.light);

  /// Convenience: [HapticIntent.medium].
  Future<void> medium() => perform(HapticIntent.medium);

  /// Convenience: [HapticIntent.heavy].
  Future<void> heavy() => perform(HapticIntent.heavy);

  /// Convenience: [HapticIntent.success].
  Future<void> success() => perform(HapticIntent.success);

  /// Convenience: [HapticIntent.warning].
  Future<void> warning() => perform(HapticIntent.warning);

  /// Convenience: [HapticIntent.error].
  Future<void> error() => perform(HapticIntent.error);
}
