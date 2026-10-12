import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../shared/widgets/surfaces.dart';
import '../../data/github_repositories.dart';

/// Période affichée par la carte « Mon activité ».
enum ActivityRange {
  week('Semaine', 7),
  month('Mois', 30),
  year('Année', null);

  const ActivityRange(this.label, this.days);

  final String label;

  /// Nombre de derniers jours retenus ; `null` : tout le calendrier.
  final int? days;

  List<ContributionDay> slice(List<ContributionDay> calendar) {
    final n = days;
    return n == null || calendar.length <= n ? calendar : calendar.sublist(calendar.length - n);
  }
}

/// Grille en semaines commençant le lundi : cases `null` devant le premier
/// jour pour l'aligner sur sa colonne (mois) ou sa ligne (année).
List<ContributionDay?> mondayAligned(List<ContributionDay> days) =>
    days.isEmpty ? const [] : [for (var i = 1; i < days.first.date.weekday; i++) null, ...days];

/// Découpe en semaines de 7 cases, du lundi au dimanche (colonnes de l'année).
List<List<ContributionDay?>> weeks(List<ContributionDay> days) {
  final cells = mondayAligned(days);
  return [
    for (var i = 0; i < cells.length; i += 7) [for (var j = i; j < i + 7; j++) j < cells.length ? cells[j] : null],
  ];
}

/// Couleur d'un niveau de 0 à 4 : neutre discret, puis jaune → brique.
Color contributionColor(BuildContext context, int level) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  if (level <= 0) {
    return theme.colorScheme.onSurface.withValues(alpha: dark ? 0.10 : 0.07);
  }
  const light = [Color(0xFFF3CF5A), Color(0xFFE9A93B), Color(0xFFDF7A3C), Color(0xFFBF4527)];
  // Thème sombre : un peu moins lumineux, pour ne pas éblouir sur fond nuit.
  const night = [Color(0xFFC9A945), Color(0xFFC98E2F), Color(0xFFC6662F), Color(0xFFA83C22)];
  return (dark ? night : light)[level.clamp(1, 4) - 1];
}

/// Carte « Mon activité » : contributions GitHub de la semaine, du mois ou de
/// l'année. Un appui sur un jour en donne le détail, dépôts privés nommés.
class ContributionActivityCard extends StatefulWidget {
  const ContributionActivityCard({super.key, required this.calendar});

  /// `null` sans jeton GitHub côté serveur.
  final List<ContributionDay>? calendar;

  @override
  State<ContributionActivityCard> createState() => _ContributionActivityCardState();
}

class _ContributionActivityCardState extends State<ContributionActivityCard> {
  ActivityRange _range = ActivityRange.week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final calendar = widget.calendar;

    if (calendar == null) {
      return SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mon activité', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Ajoute un jeton GitHub (GITHUB_TOKEN) côté serveur pour voir ton activité.', style: muted),
          ],
        ),
      );
    }

    final days = _range.slice(calendar);
    final total = days.fold<int>(0, (sum, d) => sum + d.count);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mon activité', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('$total contribution${total > 1 ? 's' : ''}', key: const Key('activity-total'), style: muted),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ActivityRange>(
              showSelectedIcon: false,
              segments: [for (final r in ActivityRange.values) ButtonSegment(value: r, label: Text(r.label))],
              selected: {_range},
              onSelectionChanged: (selection) => setState(() => _range = selection.first),
            ),
          ),
          const SizedBox(height: 16),
          switch (_range) {
            ActivityRange.week => _WeekBars(days: days),
            ActivityRange.month => _MonthGrid(days: days),
            ActivityRange.year => _YearGrid(days: days),
          },
        ],
      ),
    );
  }
}

void _showDay(BuildContext context, ContributionDay day) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      final date = DateFormat('EEEE d MMMM y', 'fr_FR').format(day.date);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${date[0].toUpperCase()}${date.substring(1)}', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                day.count == 0 ? 'Aucune contribution' : '${day.count} contribution${day.count > 1 ? 's' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (day.repositories.isNotEmpty) const SizedBox(height: 12),
              for (final repo in day.repositories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(repo.fullName, overflow: TextOverflow.ellipsis)),
                      if (repo.isPrivate) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('privé', style: theme.textTheme.labelSmall),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Text('${repo.count}', style: theme.textTheme.labelLarge),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.size});

  final ContributionDay? day;
  final double size;

  @override
  Widget build(BuildContext context) {
    final day = this.day;
    if (day == null) {
      return SizedBox.square(dimension: size);
    }
    return GestureDetector(
      onTap: () => _showDay(context, day),
      child: Container(
        key: ValueKey('day-${day.date.toIso8601String().substring(0, 10)}'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: contributionColor(context, day.level),
          borderRadius: BorderRadius.circular(size / 4),
        ),
      ),
    );
  }
}

/// 7 barres, une par jour, avec le nombre au-dessus et le jour abrégé.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});

  final List<ContributionDay> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = days.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    const barMax = 96.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showDay(context, day),
              child: Column(
                children: [
                  Text('${day.count}', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Container(
                    key: ValueKey('day-${day.date.toIso8601String().substring(0, 10)}'),
                    height: max == 0 ? 4 : 4 + (barMax - 4) * day.count / max,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: contributionColor(context, day.level),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('E', 'fr_FR').format(day.date).replaceAll('.', ''),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 30 derniers jours en 7 colonnes, lundi en premier.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.days});

  final List<ContributionDay> days;

  static const _labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cells = mondayAligned(days);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final size = ((constraints.maxWidth - gap * 6) / 7).clamp(0.0, 40.0);
        return Center(
          child: SizedBox(
            width: size * 7 + gap * 6,
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final label in _labels)
                  SizedBox(
                    width: size,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                for (final day in cells) _DayCell(day: day, size: size),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// L'année : 7 lignes (lundi → dimanche) sur ~53 colonnes, défilable,
/// ouverte sur les semaines récentes.
class _YearGrid extends StatelessWidget {
  const _YearGrid({required this.days});

  final List<ContributionDay> days;

  @override
  Widget build(BuildContext context) {
    const size = 12.0;
    const gap = 3.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Inversé : la position initiale est la fin, soit les semaines récentes.
      reverse: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final week in weeks(days))
            Padding(
              padding: const EdgeInsets.only(right: gap),
              child: Column(
                children: [
                  for (final day in week)
                    Padding(
                      padding: const EdgeInsets.only(bottom: gap),
                      child: _DayCell(day: day, size: size),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
