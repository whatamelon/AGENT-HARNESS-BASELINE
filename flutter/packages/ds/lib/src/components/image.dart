import 'package:ds/src/gen/dimens.dart';
import 'package:ds/src/gen/motion.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// A fixed-ratio image with consistent loading/fallback handling
/// (DESIGN-COMPONENTS §9). Wraps the network image in an [AspectRatio] so the
/// box never collapses or distorts: while loading it shows a `surfaceAlt`
/// placeholder, on error (or a null/empty url) it shows a muted fallback icon,
/// and the loaded image fades in with `Motion.base`.
///
/// Token-only: `surfaceAlt` placeholder, `textSubtle` fallback icon, [Radii.sm]
/// corners, `Motion.base` fade.
class DsImage extends StatelessWidget {
  const DsImage({
    required this.url,
    this.aspectRatio = 1,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticLabel,
    super.key,
  });

  /// Convenience for a square thumbnail (1:1).
  const DsImage.thumbnail({
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticLabel,
    super.key,
  }) : aspectRatio = 1;

  /// Image source. Null or empty renders the fallback (never a broken box).
  final String? url;

  /// Width / height ratio. Fixed so the layout never jumps (e.g. 1, 16 / 9).
  final double aspectRatio;
  final BoxFit fit;

  /// Corner radius; defaults to [Radii.sm].
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final radius = borderRadius ?? BorderRadius.circular(Radii.sm);
    final hasUrl = url != null && url!.isNotEmpty;

    return Semantics(
      label: semanticLabel,
      image: true,
      child: ClipRRect(
        borderRadius: radius,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ColoredBox(
            color: c.surfaceAlt,
            child: hasUrl
                ? Image.network(
                    url!,
                    fit: fit,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        return AnimatedOpacity(
                          opacity: 1,
                          duration: Motion.baseDuration,
                          curve: Motion.baseCurve,
                          child: child,
                        );
                      }
                      return _Placeholder(color: c.surfaceAlt);
                    },
                    errorBuilder: (context, error, stack) =>
                        _Fallback(color: c.textSubtle),
                  )
                : _Fallback(color: c.textSubtle),
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder — flat token surface, no spinner noise.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(color: color);
}

/// Error / empty-url fallback — centered muted icon on the placeholder surface.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Center(child: Icon(Icons.image_not_supported_outlined, color: color));
}
