import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';

/// Bandeau d'erreur générale (réseau, 429…), affiché au-dessus d'un formulaire.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: scheme.error)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar rond : la photo de profil quand il y en a une, sinon les initiales
/// sur fond or (aussi en attendant ou en cas d'échec du chargement).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.initials, {super.key, this.size = 44, this.photoUrl});

  final String initials;
  final double size;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(color: colors.onAccent, fontWeight: FontWeight.w700, fontSize: size * 0.36),
      ),
    );

    return ExcludeSemantics(
      child: photoUrl == null
          ? fallback
          : ClipOval(
              child: Image.network(
                photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                    frame == null && !wasSynchronouslyLoaded ? fallback : child,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
    );
  }
}

/// Écran temporaire pour une section prévue dans une étape suivante.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHigh, shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
