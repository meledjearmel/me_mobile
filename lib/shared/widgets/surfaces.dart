import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../app/theme/app_theme.dart';

/// Carte de base de la refonte : fond carte, grand rayon, sans bordure ni ombre.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = AppTheme.radius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? context.appColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Titre de section avec lien facultatif à droite (« Voir tout »).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              minimumSize: const Size(48, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// Pastille ronde encre avec flèche diagonale : « ouvrir ».
class ArrowBadge extends StatelessWidget {
  const ArrowBadge({super.key, this.size = 38, this.icon = Icons.north_east_rounded});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: context.appColors.onAccent, shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.45, color: Colors.white),
      ),
    );
  }
}

/// Initiales dans un carré arrondi, pour les lignes de liste (messages, demandes…).
class InitialsTile extends StatelessWidget {
  const InitialsTile(this.name, {super.key, this.size = 42});

  final String name;
  final double size;

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        child: Text(initialsOf(name), style: theme.textTheme.labelLarge?.copyWith(fontSize: size * 0.32)),
      ),
    );
  }
}

/// Point or signalant un élément non lu.
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key, this.size = 8});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: context.appColors.accent, shape: BoxShape.circle),
    );
  }
}

/// Ligne de liste en carte : visuel à gauche, titre (point or si non lu),
/// méta à droite (date), sous-titre sur une ligne et pastille facultative.
class ListCardTile extends StatelessWidget {
  const ListCardTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.meta,
    this.badge,
    this.unread = false,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final String? meta;
  final Widget? badge;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return SurfaceCard(
      radius: 20,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (unread) ...[const UnreadDot(), const SizedBox(width: 6)],
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (meta != null) ...[
                      const SizedBox(width: 8),
                      Text(meta!, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                    ],
                  ],
                ),
                if (subtitle?.isNotEmpty == true || badge != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ),
                      if (badge != null) ...[const SizedBox(width: 8), badge!],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icône dans un carré arrondi, pendant de [InitialsTile] pour les éléments sans nom.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 42});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, size: size * 0.48, color: theme.colorScheme.onSurface),
    );
  }
}

/// Sélecteur segmenté en pilule piloté par un [TabController] : le segment
/// actif est plein (encre le jour, or la nuit), avec un compteur facultatif.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({super.key, required this.controller, required this.labels, this.counts});

  final TabController controller;
  final List<String> labels;
  final List<int>? counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(color: scheme.surfaceContainer, shape: const StadiumBorder()),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: _Segment(
                  label: labels[i],
                  count: counts?[i] ?? 0,
                  selected: controller.index == i,
                  onTap: () => controller.animateTo(i),
                  selectedColor: scheme.primary,
                  onSelectedColor: scheme.onPrimary,
                  mutedColor: scheme.onSurfaceVariant,
                  badgeColor: colors.accent,
                  onBadgeColor: colors.onAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
    required this.onSelectedColor,
    required this.mutedColor,
    required this.badgeColor,
    required this.onBadgeColor,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color onSelectedColor;
  final Color mutedColor;
  final Color badgeColor;
  final Color onBadgeColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: count > 0 ? '$label, $count à traiter' : label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: ShapeDecoration(
            color: selected ? selectedColor : Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(color: selected ? onSelectedColor : mutedColor),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(color: badgeColor, shape: const StadiumBorder()),
                  child: Text(
                    '$count',
                    style: text.labelSmall?.copyWith(color: onBadgeColor, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Champ de recherche en pilule, sur fond carte.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onSubmitted;

  /// Filtrage à la frappe, pour les listes déjà chargées en mémoire.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          isDense: true,
          filled: true,
          fillColor: context.appColors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: BorderSide(color: context.appColors.accent, width: 1.5)),
          suffixIcon: value.text.isEmpty
              ? const Icon(Icons.search_rounded)
              : IconButton(
                  tooltip: 'Effacer la recherche',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    controller.clear();
                    onSubmitted('');
                  },
                ),
        ),
      ),
    );
  }
}
