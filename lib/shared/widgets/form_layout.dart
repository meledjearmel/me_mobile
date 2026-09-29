import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import 'surfaces.dart';

/// Briques communes des formulaires de la refonte : en-tête, tuiles
/// d'infos clés, sections en cartes repliables et barre d'enregistrement fixe.

/// Grand titre du formulaire et ligne secondaire (type, état…).
class FormHeader extends StatelessWidget {
  const FormHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

/// Rangée de 2 à 4 infos clés séparées par des filets, dans une seule carte.
class KeyFacts extends StatelessWidget {
  const KeyFacts({super.key, required this.facts});

  final List<({String value, String label})> facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (index, fact) in facts.indexed) ...[
              if (index > 0) VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                  child: Column(
                    children: [
                      Text(fact.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        fact.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section de formulaire en carte, repliable. Une section qui contient une
/// erreur de validation se rouvre d'elle-même pour que l'erreur reste visible.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.summary,
    this.initiallyExpanded = true,
    this.hasError = false,
  });

  final String title;

  /// Résumé affiché à côté du titre (nombre d'éléments, par exemple).
  final String? summary;
  final List<Widget> children;
  final bool initiallyExpanded;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        // La clé change quand une erreur apparaît : la tuile se reconstruit ouverte.
        key: PageStorageKey('$title-$hasError'),
        initiallyExpanded: initiallyExpanded || hasError,
        maintainState: true,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Row(
          children: [
            Flexible(child: Text(title, style: theme.textTheme.titleSmall)),
            if (summary != null) ...[
              const SizedBox(width: 8),
              Text(summary!, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (hasError) ...[
              const SizedBox(width: 8),
              Icon(Icons.error_outline_rounded, size: 18, color: theme.colorScheme.error),
            ],
          ],
        ),
        children: [
          for (final (index, child) in children.indexed) ...[if (index > 0) const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}

/// Bouton principal fixé en bas de l'écran, avec progression d'envoi facultative.
class SaveBar extends StatelessWidget {
  const SaveBar({super.key, required this.onPressed, required this.saving, this.label = 'Enregistrer', this.progress});

  final VoidCallback? onPressed;
  final bool saving;
  final String label;

  /// Progression d'un envoi de fichiers (0 à 1), `null` si aucun envoi.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    // Pilule en verre : la page reste visible à travers le bouton.
    final fill = theme.colorScheme.primary.withValues(alpha: 0.78);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null) ...[
            LinearProgressIndicator(value: progress, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 10),
          ],
          DecoratedBox(
            decoration: const ShapeDecoration(
              shape: StadiumBorder(),
              shadows: [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving ? null : onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: fill,
                      disabledBackgroundColor: fill,
                      disabledForegroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.fromLTRB(24, 0, 8, 0),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(label)),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark ? colors.onAccent : colors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: saving
                              ? Padding(
                                  padding: const EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: theme.brightness == Brightness.dark ? colors.accent : colors.onAccent,
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_forward_rounded,
                                  color: theme.brightness == Brightness.dark ? colors.accent : colors.onAccent,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
