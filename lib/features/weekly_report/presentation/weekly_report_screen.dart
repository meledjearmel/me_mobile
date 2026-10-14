import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/weekly_report.dart';

final _day = DateFormat('d MMMM', 'fr_FR');

/// Rapport de la semaine : aperçu des 7 derniers jours, envoi chaque lundi
/// matin à l'email du profil, et envoi immédiat après confirmation.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  late Future<WeeklyReportState> _future = _load();
  bool _withHighlights = false;
  bool _toggling = false;
  bool _sending = false;

  WeeklyReportRepository get _repository => ref.read(weeklyReportRepositoryProvider);

  Future<WeeklyReportState> _load() => _repository.get(highlights: _withHighlights);

  void _reload({bool? highlights}) => setState(() {
    _withHighlights = highlights ?? _withHighlights;
    _future = _load();
  });

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _toggling = true);
    try {
      await _repository.setEnabled(enabled);
      _toast(enabled ? 'Le rapport partira chaque lundi matin.' : 'Rapport hebdomadaire désactivé.');
      _reload();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) {
        setState(() => _toggling = false);
      }
    }
  }

  Future<void> _send() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Envoyer le rapport maintenant ?'),
        content: const Text(
          'Il part tout de suite à l\'email de ton profil, même s\'il est désactivé ou déjà envoyé cette semaine.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _sending = true);
    try {
      final status = await _repository.sendNow();
      _toast(switch (status) {
        'sent' => 'Rapport envoyé.',
        'no_recipient' => 'Aucun email sur le profil : rapport non envoyé.',
        _ => 'Rapport non envoyé ($status).',
      });
      if (status == 'sent') {
        _reload();
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(),
      body: FutureBuilder<WeeklyReportState>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_withHighlights) ...[
                    const SizedBox(height: 12),
                    const Text('L\'IA prépare les points à retenir…'),
                  ],
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error is ApiException ? (snapshot.error! as ApiException).message : 'Erreur.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Réessayer')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: _body(context, snapshot.data!),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, WeeklyReportState state) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final report = state.report;
    final change = report.change;

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );

    final todo = report.todo;
    final todoLines = [
      if (todo.contacts > 0) ('Messages à traiter', todo.contacts),
      if (todo.engagements > 0) ('Demandes à traiter', todo.engagements),
      if (todo.appointments > 0) ('Rendez-vous à confirmer', todo.appointments),
      if (todo.testimonials > 0) ('Témoignages à modérer', todo.testimonials),
      if (todo.comments > 0) ('Commentaires à modérer', todo.comments),
      if (todo.drafts > 0) ('Brouillons à relire', todo.drafts),
      if (todo.revisions > 0) ('Révisions IA à relire', todo.revisions),
    ];

    return ListView(
      padding: pageInsets(context),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FormHeader(
            title: 'Rapport de la semaine',
            subtitle: report.from == null || report.to == null
                ? 'Les 7 derniers jours'
                : 'Du ${_day.format(report.from!)} au ${_day.format(report.to!)}',
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recevoir chaque lundi matin'),
                subtitle: const Text('À l\'email de ton profil.'),
                value: state.enabled,
                onChanged: _toggling ? null : _setEnabled,
              ),
              Text(
                state.sentAt == null ? 'Jamais envoyé.' : 'Dernier envoi ${relativeDate(state.sentAt!)}.',
                style: muted,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text('Envoyer maintenant'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (report.highlights != null)
          FormSection(
            title: 'À retenir',
            children: [
              for (final point in report.highlights!)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(point)),
                  ],
                ),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: () => _reload(highlights: true),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              _withHighlights ? 'Points à retenir indisponibles, réessayer' : 'Ajouter les points à retenir (IA)',
            ),
          ),
        const SizedBox(height: 12),
        KeyFacts(
          facts: [
            (value: '${report.visits}', label: 'Visites'),
            (value: '${report.visitors}', label: 'Visiteurs'),
            (value: change == null ? '—' : '${change > 0 ? '+' : ''}$change %', label: 'vs semaine d\'avant'),
          ],
        ),
        if (report.topContent.isNotEmpty || report.sources.isNotEmpty) ...[
          const SizedBox(height: 12),
          FormSection(
            title: 'Audience',
            children: [
              for (final content in report.topContent) line(content.title, '${content.visits}'),
              if (report.sources.isNotEmpty) ...[
                Text('Provenance', style: theme.textTheme.labelLarge),
                for (final source in report.sources)
                  line(source.label == 'direct' ? 'Accès direct' : source.label, '${source.count}'),
              ],
            ],
          ),
        ],
        const SizedBox(height: 12),
        FormSection(
          title: 'Demandes',
          summary: '${report.requestsTotal}',
          children: [
            line('Messages', '${report.contacts}'),
            line('Freelance', '${report.freelance}'),
            line('Embauche', '${report.hiring}'),
            line('Rendez-vous demandés', '${report.appointments}'),
            line('Rendez-vous à venir (7 j)', '${report.upcomingAppointments}'),
            for (final estimate in report.estimates)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(estimate.subject ?? 'Estimation', style: theme.textTheme.titleSmall),
                    if (estimate.estimate != null) Text(estimate.estimate!, style: muted),
                    if (estimate.aiHours != null)
                      Text(
                        'IA : ${estimate.aiHours}${estimate.aiBilling == null ? '' : ' · ${estimate.aiBilling == 'hourly' ? 'à l\'heure' : 'forfait'}'}',
                        style: muted,
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FormSection(
          title: 'Candidatures et CV',
          children: [
            line('Pages créées', '${report.applicationsCreated}'),
            line('CV téléchargés', '${report.cvDownloads}'),
            for (final application in report.applicationsViewed)
              line(
                '${application.company}${application.firstTime ? ' · 1re ouverture' : ''}',
                '${application.views} vue${application.views > 1 ? 's' : ''} · ${application.cvDownloads} CV',
              ),
          ],
        ),
        const SizedBox(height: 12),
        FormSection(
          title: 'Blog',
          children: [
            line('Articles publiés', '${report.postsPublished}'),
            line('Commentaires', '${report.comments}'),
            line('Réactions', '${report.reactions}'),
            line('Nouveaux abonnés', '${report.newSubscribers} (${report.subscribers} au total)'),
          ],
        ),
        const SizedBox(height: 12),
        FormSection(
          title: 'À faire',
          summary: '${todoLines.fold(0, (sum, l) => sum + l.$2)}',
          children: [
            if (todoLines.isEmpty)
              Text('Rien n\'attend.', style: muted)
            else
              for (final (label, count) in todoLines) line(label, '$count'),
          ],
        ),
      ],
    );
  }
}
