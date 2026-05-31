import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/gen/typography.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// Shared empty/error/loading shell (DESIGN-COMPONENTS §12). Reused by other
/// components (e.g. `DsList`) so every state is consistent and Korean-first.
enum DsStateVariant {
  /// No data — neutral icon + "결과가 없습니다" tone.
  empty,

  /// Recoverable failure — danger-tinted icon + retry affordance.
  error,

  /// In-flight — spinner. No icon/title noise.
  loading,
}

/// A centered status view with icon, title, optional message, and an optional
/// retry action. Token-only; Korean copy by default (no English eyebrow/dummy).
class DsStateView extends StatelessWidget {
  const DsStateView({
    required this.variant,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel = '다시 시도',
    super.key,
  });

  /// Empty state with sensible Korean defaults.
  const DsStateView.empty({
    this.title = '결과가 없습니다',
    this.message,
    super.key,
  })  : variant = DsStateVariant.empty,
        onRetry = null,
        retryLabel = '다시 시도';

  /// Error state with a retry affordance and Korean defaults.
  const DsStateView.error({
    this.title = '문제가 발생했어요',
    this.message = '잠시 후 다시 시도해 주세요.',
    this.onRetry,
    this.retryLabel = '다시 시도',
    super.key,
  }) : variant = DsStateVariant.error;

  /// Loading state — spinner only.
  const DsStateView.loading({super.key})
      : variant = DsStateVariant.loading,
        title = null,
        message = null,
        onRetry = null,
        retryLabel = '다시 시도';

  final DsStateVariant variant;
  final String? title;
  final String? message;

  /// Retry handler — only meaningful for [DsStateVariant.error].
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    if (variant == DsStateVariant.loading) {
      return Semantics(
        label: '불러오는 중',
        liveRegion: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.x8),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(c.textMuted),
            ),
          ),
        ),
      );
    }

    final isError = variant == DsStateVariant.error;
    final icon = isError ? Icons.error_outline : Icons.inbox_outlined;

    return Semantics(
      container: true,
      label: title,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.x8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: c.textSubtle),
              if (title != null) ...[
                const SizedBox(height: Space.x4),
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: DsType.title3.copyWith(color: c.text),
                ),
              ],
              if (message != null) ...[
                const SizedBox(height: Space.x2),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: DsType.bodySm.copyWith(color: c.textMuted),
                ),
              ],
              if (isError && onRetry != null) ...[
                const SizedBox(height: Space.x4),
                OutlinedButton(
                  onPressed: onRetry,
                  child: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
