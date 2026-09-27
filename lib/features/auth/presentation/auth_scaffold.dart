import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../../shared/widgets/app_logo.dart';

/// Mise en page commune aux écrans de connexion : bandeau « ciel » du site
/// avec le monogramme, puis le formulaire sur une carte.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.child, this.leading});

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Scaffold(
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: colors.hero,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 48, child: leading),
                      const SizedBox(height: 16),
                      AppLogo(height: 36, color: colors.onHero),
                      const SizedBox(height: 28),
                      Text(title, style: theme.textTheme.displaySmall?.copyWith(color: colors.onHero)),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(color: colors.onHero.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: SafeArea(top: false, child: child),
            ),
          ],
        ),
      ),
    );
  }
}
