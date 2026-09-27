import 'package:flutter/material.dart';

/// Pastille de statut discrète (§3.6 : libellés français à afficher).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.color, this.prominent = false});

  final String label;

  /// Couleur d'accent ; par défaut neutre (comme le back-office web).
  final Color? color;

  /// Un brouillon doit être « très visible » (§3.6) : fond plein plutôt que discret.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: prominent ? tint : tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: prominent ? _onTint(tint) : tint,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Color _onTint(Color tint) => tint.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

/// Puce de filtre (statut, type…), cochée ou non — utilisée dans les barres de
/// filtre des listes (§3.3).
class PillFilterChip extends StatelessWidget {
  const PillFilterChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(color: selected ? scheme.onSurface : scheme.onSurfaceVariant),
    );
  }
}
