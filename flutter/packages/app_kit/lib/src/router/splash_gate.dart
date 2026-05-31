/// Minimal splash screen shown while auth status is unknown (session restore
/// in flight), per §5.3.
///
/// This screen has *no routing logic*: the router redirect owns "hold on splash
/// while unknown, then leave". It is a brand-neutral, light-mode-only
/// placeholder that simply avoids a flash-of-login during cold start. Apps may
/// override the visual via their own route, but the package ships this default
/// so the redirect always has a destination.
library;

import 'package:flutter/material.dart';

/// Brand-neutral light-mode splash placeholder.
///
/// Renders a centered progress indicator on the theme surface. No logo, no
/// decorative label, no dark variant.
class SplashScreen extends StatelessWidget {
  /// Creates a [SplashScreen].
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
