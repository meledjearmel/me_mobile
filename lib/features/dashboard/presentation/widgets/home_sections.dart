import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/push/push_target.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../billing/presentation/documents_list_screen.dart' show formatMoney;
import '../../../inbox/data/appointment.dart';
import '../../data/dashboard.dart';
import 'recent_section.dart';
import 'visits_chart.dart';

/// Évolution d'un volume face à la période précédente : « ▲ 18 % », « ▼ 3 »,
/// « = stable », ou `null` sans comparaison possible.
({String label, bool? up})? describeTrend(TrendValue? trend) {
  if (trend == null || (trend.current == 0 && trend.previous == 0)) {
    return null;
  }
  final diff = trend.current - trend.previous;
  if (diff == 0) {
    return (label: '= stable', up: null);
  }
  final arrow = diff > 0 ? '▲' : '▼';
  // En pourcentage seulement quand la base est assez grande pour qu'il ait un sens.
  final text = trend.previous >= 10 ? '${(diff.abs() / trend.previous * 100).round()} %' : '${diff.abs()}';
  return (label: '$arrow $text', up: diff > 0);
}

class _TrendText extends StatelessWidget {
  const _TrendText(this.trend, {this.suffix = ''});

  final TrendValue? trend;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final described = describeTrend(trend);
    if (described == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final color = switch (described.up) {
      true => context.appColors.success,
      false => theme.colorScheme.error,
      null => theme.colorScheme.onSurfaceVariant,
    };
    return Text(
      '${described.label}$suffix',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
    );
  }
}

/// Carte « Aujourd'hui » : prochains rendez-vous, encaissé sur la période et
/// factures en retard. Rien quand il n'y a ni rendez-vous ni facturation.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.dashboard, required this.onAppointmentTap, required this.onBillingTap});

  final Dashboard dashboard;
  final ValueChanged<int> onAppointmentTap;
  final VoidCallback onBillingTap;

  @override
  Widget build(BuildContext context) {
    final agenda = dashboard.agenda.take(3).toList();
    final billing = dashboard.billing;
    final collected = billing.byCurrency.where((c) => c.collected > 0).toList();
    final overdue = billing.overdueInvoices;
    if (agenda.isEmpty && collected.isEmpty && overdue.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final colors = context.appColors;
    final hasBilling = collected.isNotEmpty || overdue.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SurfaceCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('À venir', style: theme.textTheme.titleMedium),
            if (agenda.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Aucun rendez-vous prévu.', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ),
            for (final item in agenda)
              InkWell(
                onTap: () => onAppointmentTap(item.id),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(color: colors.highlight, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Text(_dayLabel(item.startsAt), style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                            Text(DateFormat.Hm('fr_FR').format(item.startsAt), style: theme.textTheme.labelLarge),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [item.name, item.company].whereType<String>().join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                            Text(
                              [
                                if (item.type != null) item.type!,
                                if (item.location != null) AppointmentLocation.fromWire(item.location).label,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      ),
                      if (item.isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(99)),
                          child: Text(
                            'À confirmer',
                            style: theme.textTheme.labelSmall?.copyWith(color: colors.onAccent),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (hasBilling) ...[
              const Divider(height: 20),
              InkWell(
                onTap: onBillingTap,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    for (final c in collected)
                      _MoneyRow(
                        label: 'Encaissé sur ${dashboard.billing.periodDays ?? 30} j',
                        value: formatMoney(c.collected, c.currency),
                      ),
                    if (overdue.isNotEmpty)
                      _MoneyRow(
                        label: overdue.length > 1 ? 'Factures en retard' : 'Facture en retard',
                        value: _overdueSummary(overdue),
                        color: theme.colorScheme.error,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _overdueSummary(List<OverdueInvoice> overdue) {
    final byCurrency = <String, int>{};
    for (final invoice in overdue) {
      byCurrency.update(invoice.currency, (sum) => sum + invoice.total, ifAbsent: () => invoice.total);
    }
    return '${overdue.length} · ${byCurrency.entries.map((e) => formatMoney(e.value, e.key)).join(' + ')}';
  }

  static String _dayLabel(DateTime at) {
    final now = DateTime.now();
    final days = DateTime(at.year, at.month, at.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    return switch (days) {
      0 => "Auj.",
      1 => 'Demain',
      _ => DateFormat('E d', 'fr_FR').format(at),
    };
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Text(value, style: theme.textTheme.labelLarge?.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Visites de la période en grand, leur tendance et la courbe.
class AudienceCard extends StatelessWidget {
  const AudienceCard({super.key, required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visits = dashboard.visits;
    final days = dashboard.trends?.periodDays ?? visits.periodDays ?? 30;

    return SurfaceCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visites sur $days jours',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Text(
            NumberFormat.decimalPattern('fr_FR').format(visits.period),
            style: theme.textTheme.headlineMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          _TrendText(dashboard.trends?['visits'], suffix: ' vs $days j précédents'),
          const SizedBox(height: 10),
          SizedBox(height: 72, child: VisitsChart(daily: visits.daily, height: 72)),
        ],
      ),
    );
  }
}

/// Tuile chiffre + libellé + tendance face à la période précédente.
class TrendTile extends StatelessWidget {
  const TrendTile({super.key, required this.label, required this.trend});

  final String label;
  final TrendValue? trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            '${trend?.current ?? 0}',
            style: theme.textTheme.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 2),
          _TrendText(trend),
        ],
      ),
    );
  }
}

/// Un élément du fil « Activité récente », avec le type qui choisit l'écran à ouvrir.
typedef ActivityItem = ({PushResourceType type, RecentItem item});

/// Messages, demandes et avis récents réunis en un seul fil, du plus récent au plus ancien.
List<ActivityItem> recentActivity(DashboardRecent recent, {int limit = 6}) {
  final items = <ActivityItem>[
    for (final c in recent.contacts)
      (
        type: PushResourceType.contact,
        item: (id: c.id, title: c.name, subtitle: 'Message · ${c.subject ?? ''}', isNew: c.isNew, at: c.at),
      ),
    for (final e in recent.engagements)
      (
        type: PushResourceType.engagement,
        item: (
          id: e.id,
          title: e.name,
          subtitle: ['Demande', e.company, e.subject].whereType<String>().join(' · '),
          isNew: e.isNew,
          at: e.at,
        ),
      ),
    for (final t in recent.testimonials)
      (
        type: PushResourceType.testimonial,
        item: (id: t.id, title: t.name, subtitle: 'Avis · ${t.excerpt}', isNew: true, at: t.at),
      ),
  ];
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  items.sort((a, b) => (b.item.at ?? epoch).compareTo(a.item.at ?? epoch));
  return items.take(limit).toList();
}

class ActivityFeed extends StatelessWidget {
  const ActivityFeed({super.key, required this.items, required this.onTap, required this.onSeeAll});

  final List<ActivityItem> items;
  final void Function(PushResourceType type, int id) onTap;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Activité récente', actionLabel: items.isEmpty ? null : 'Boîte de réception', onAction: onSeeAll),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'Rien de reçu pour l\'instant.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (final (index, entry) in items.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            RecentTile(item: entry.item, onTap: () => onTap(entry.type, entry.item.id)),
          ],
      ],
    );
  }
}
