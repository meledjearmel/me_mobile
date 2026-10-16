import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';

/// Rendu d'un badge de statut, le même pour un statut donné sur tous les
/// écrans (voir `statusTone`) : plein (or), secondaire, contour ou rouge.
enum StatusTone { filled, secondary, outline, danger }

/// Pastille de statut discrète (§3.6 : libellés français à afficher).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.color, this.prominent = false}) : tone = null;

  /// Badge de statut d'une ligne de liste, rendu selon [tone].
  const StatusBadge.tone(this.label, StatusTone this.tone, {super.key}) : color = null, prominent = false;

  final String label;

  /// Quand il est donné, il remplace [color] et [prominent].
  final StatusTone? tone;

  /// Couleur d'accent ; par défaut neutre (comme le back-office web).
  final Color? color;

  /// Un brouillon doit être « très visible » (§3.6) : fond plein plutôt que discret.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600);
    if (tone != null) {
      final (background, foreground, border) = switch (tone!) {
        StatusTone.filled => (colors.accent, colors.onAccent, null),
        StatusTone.secondary => (colors.second, colors.onSecond, null),
        StatusTone.outline => (Colors.transparent, colors.muted, colors.muted),
        StatusTone.danger => (AppPalette.danger.withValues(alpha: 0.14), AppPalette.danger, null),
      };
      return Container(
        padding: EdgeInsets.symmetric(horizontal: border == null ? 10 : 9, vertical: border == null ? 4 : 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Text(label, style: textStyle?.copyWith(color: foreground)),
      );
    }
    // Sans couleur imposée : la couleur secondaire de la palette, discrète.
    final tint = color ?? colors.onSecond;
    final background = prominent
        ? tint
        : color == null
        ? colors.second
        : tint.withValues(alpha: 0.14);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: prominent ? _onTint(tint) : tint, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _onTint(Color tint) => tint.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

/// Puce de filtre (statut, type…) en pilule : fond carte, or une fois
/// sélectionnée — utilisée dans les barres de filtre des listes (§3.3).
class PillFilterChip extends StatelessWidget {
  const PillFilterChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.accent : colors.card,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? colors.onAccent : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
