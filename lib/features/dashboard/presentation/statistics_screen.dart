import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/env.dart';
import '../../../app/theme/app_palette.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../blog/data/post.dart';
import '../../blog/presentation/post_form_screen.dart';
import '../../celebrations/presentation/congratulations_screen.dart';
import '../../cv_downloads/presentation/cv_downloads_screen.dart';
import '../data/dashboard.dart';
import '../data/dashboard_repository.dart';
import 'widgets/distribution_list.dart';
import 'widgets/stat_tile.dart';
import 'widgets/visits_chart.dart';

/// Statistiques détaillées du site (visites, contenu, relations, répartitions),
/// ouvertes depuis « Tout voir » de l'accueil. Filtrables par période et, pour
/// les contenus les plus vus, par type ([statisticsQueryProvider]).
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(statisticsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: const GlassAppBar(),
      body: dashboard.when(
        // Changer de période garde l'affichage précédent pendant le rechargement.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Impossible de charger les statistiques.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(statisticsProvider), child: const Text('Réessayer')),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(statisticsProvider.future),
          edgeOffset: MediaQuery.paddingOf(context).top,
          child: _StatisticsBody(dashboard: data, reloading: dashboard.isLoading),
        ),
      ),
    );
  }
}

class _StatisticsBody extends ConsumerWidget {
  const _StatisticsBody({required this.dashboard, required this.reloading});

  final Dashboard dashboard;
  final bool reloading;

  void _openCvDownloads(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CvDownloadsScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(statisticsQueryProvider);
    final setQuery = ref.read(statisticsQueryProvider.notifier);
    final content = dashboard.content;
    final distribution = dashboard.distribution;
    const gap = SizedBox(height: 28);
    const small = SizedBox(height: 8);

    return PageListView(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: FormHeader(title: 'Statistiques', subtitle: 'Visites, contenu et relations du site'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            expandedInsets: EdgeInsets.zero,
            segments: [for (final p in dashboardPeriods) ButtonSegment(value: p.days, label: Text(p.label))],
            selected: {query.days},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => setQuery.state = (days: selection.first, type: query.type),
          ),
        ),
        SizedBox(height: 3, child: reloading ? const LinearProgressIndicator(minHeight: 3) : null),
        const SizedBox(height: 17),
        const SectionHeader('Visites'),
        small,
        _VisitsCard(visits: dashboard.visits),
        if (dashboard.visits.topPages.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BarListCard(
            title: 'Pages les plus vues',
            items: [for (final page in dashboard.visits.topPages) (label: page.path, count: page.count)],
          ),
        ],
        if (dashboard.visits.bySource.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BarListCard(
            title: 'Provenance des visiteurs',
            items: [
              for (final source in dashboard.visits.bySource) (label: _sourceLabel(source.label), count: source.count),
            ],
          ),
        ],
        if (dashboard.visits.byDevice.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BarListCard(
            title: 'Appareils',
            items: [
              for (final device in dashboard.visits.byDevice) (label: _deviceLabel(device.label), count: device.count),
            ],
          ),
        ],
        // Toujours affichée quand un type est choisi : la liste filtrée peut être vide.
        if (dashboard.visits.topContent.isNotEmpty || query.type != null) ...[
          const SizedBox(height: 10),
          _TopContentCard(
            items: dashboard.visits.topContent,
            type: query.type,
            onTypeChanged: (type) => setQuery.state = (days: query.days, type: type),
          ),
        ],
        if (dashboard.conversions.goals.isNotEmpty) ...[
          gap,
          const SectionHeader('Conversions'),
          const SizedBox(height: 4),
          Text(
            '${dashboard.conversions.periodLabel} · rapportées aux visiteurs uniques',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          small,
          _Grid(
            children: [
              for (final goal in dashboard.conversions.goals)
                StatTile(value: goal.count, label: goal.label, caption: '${_percent(goal.rate)} des visiteurs'),
            ],
          ),
        ],
        gap,
        const SectionHeader('Contenu'),
        small,
        _Grid(
          children: [
            StatTile(
              value: content.projects.published,
              label: 'Projets publiés',
              caption: '${content.projects.featured} à la une',
            ),
            StatTile(
              value: content.projects.openSource,
              label: 'Open source',
              caption: '${content.projects.archived} archivés',
            ),
            StatTile(value: content.skills, label: 'Compétences'),
            StatTile(value: content.technologies, label: 'Technologies'),
            StatTile(value: content.domains, label: 'Domaines'),
            StatTile(value: content.yearsOfExperience, label: 'Ans d\'expérience'),
            StatTile(value: content.experiences, label: 'Expériences'),
            StatTile(value: content.educations, label: 'Formations'),
            StatTile(value: content.referencesOnCv, label: 'Références sur CV'),
          ],
        ),
        gap,
        const SectionHeader('Relations'),
        small,
        _Grid(
          children: [
            StatTile(
              value: content.testimonials.approved,
              label: 'Avis approuvés',
              caption: '${content.testimonials.featured} à la une',
            ),
            StatTile(
              value: content.testimonials.pending,
              label: 'Avis en attente',
              caption: '${content.testimonials.rejected} rejetés',
            ),
            StatTile(value: content.engagements.freelance, label: 'Demandes freelance'),
            StatTile(value: content.engagements.hiring, label: 'Demandes d\'embauche'),
            StatTile(value: content.engagements.cvSent, label: 'CV envoyés'),
            StatTile(value: content.contacts, label: 'Messages reçus'),
          ],
        ),
        const SizedBox(height: 10),
        CongratulationsCard(
          count: content.congratulations,
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CongratulationsScreen())),
        ),
        gap,
        const SectionHeader('Blog'),
        const SizedBox(height: 4),
        Text(
          '${dashboard.blog.periodLabel} · lectures depuis le début',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        small,
        _Grid(
          children: [
            StatTile(value: dashboard.blog.viewsTotal, label: 'Lectures'),
            StatTile(
              value: dashboard.blog.reactionsPeriod,
              label: 'Réactions',
              caption: '${dashboard.blog.reactionsTotal} au total',
            ),
            StatTile(
              value: dashboard.blog.commentsPeriod,
              label: 'Commentaires',
              caption: '${dashboard.blog.commentsTotal} au total',
            ),
            StatTile(
              value: dashboard.blog.commentsPending,
              label: 'À modérer',
              caption: '${dashboard.blog.commentsApproved} approuvés · ${dashboard.blog.commentsRejected} rejetés',
            ),
          ],
        ),
        if (dashboard.blog.reactionsByType.any((r) => r.count > 0)) ...[
          const SizedBox(height: 10),
          _BarListCard(
            title: 'Réactions',
            items: [for (final r in dashboard.blog.reactionsByType) (label: _reactionLabel(r.label), count: r.count)],
          ),
        ],
        if (dashboard.blog.topPosts.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BlogTopPostsCard(posts: dashboard.blog.topPosts),
        ],
        gap,
        SectionHeader('CV téléchargés', actionLabel: 'Tout voir', onAction: () => _openCvDownloads(context)),
        small,
        CvDownloadsCard(summary: dashboard.cvDownloads, onTap: () => _openCvDownloads(context)),
        if (distribution.skillsByDomain.isNotEmpty ||
            distribution.projectsByDomain.isNotEmpty ||
            distribution.technologiesByCategory.isNotEmpty) ...[
          gap,
          const SectionHeader('Répartition'),
          small,
          if (distribution.projectsByDomain.isNotEmpty)
            _DistributionCard(
              title: 'Projets par domaine',
              child: DomainDistributionList(items: distribution.projectsByDomain),
            ),
          if (distribution.skillsByDomain.isNotEmpty)
            _DistributionCard(
              title: 'Compétences par domaine',
              child: DomainDistributionList(items: distribution.skillsByDomain),
            ),
          if (distribution.technologiesByCategory.isNotEmpty)
            _DistributionCard(
              title: 'Technologies par catégorie',
              child: CategoryDistributionList(items: distribution.technologiesByCategory),
            ),
        ],
      ],
    );
  }
}

String _reactionLabel(String wire) {
  final type = PostReactionType.fromWire(wire);
  return type == null ? wire : '${type.emoji}  ${type.label}';
}

String _sourceLabel(String source) => source == 'direct' ? 'Accès direct' : source;

String _deviceLabel(String device) => switch (device) {
  'desktop' => 'Ordinateur',
  'mobile' => 'Mobile',
  'inconnu' => 'Inconnu',
  'tablet' => 'Tablette',
  _ => device,
};

/// « 2,5 % », à la française.
String _percent(double rate) => '${NumberFormat('#,##0.#', 'fr_FR').format(rate)} %';

class _VisitsCard extends StatelessWidget {
  const _VisitsCard({required this.visits});

  final DashboardVisits visits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(visits.periodLabel, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          const SizedBox(height: 4),
          Text(
            '${visits.period}',
            style: theme.textTheme.displaySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          Text(
            '${visits.period == 1 ? 'visite' : 'visites'} · ${visits.visitors} '
            '${visits.visitors == 1 ? 'visiteur unique' : 'visiteurs uniques'}',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          // Avec « Tout », le total est déjà le chiffre principal.
          if (visits.periodDays != null)
            Text(
              '${visits.total} ${visits.total == 1 ? 'visite' : 'visites'} depuis le début',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          const SizedBox(height: 16),
          VisitsChart(daily: visits.daily),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniFact(value: visits.today, label: 'Aujourd\'hui'),
              _MiniFact(value: visits.french, label: 'En français'),
              _MiniFact(value: visits.english, label: 'En anglais'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniFact extends StatelessWidget {
  const _MiniFact({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: theme.textTheme.titleMedium),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Liste classée (pages, provenances, appareils), chaque barre
/// proportionnelle à la plus grande valeur.
class _BarListCard extends StatelessWidget {
  const _BarListCard({required this.title, required this.items});

  final String title;
  final List<({String label, int count})> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final max = items.map((i) => i.count).fold<int>(1, (a, b) => a > b ? a : b);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          for (final (index, item) in items.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${item.count}', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.count / max,
                minHeight: 6,
                color: colors.accent,
                backgroundColor: theme.colorScheme.surfaceContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Articles et projets les plus vus : visites, visiteurs uniques et provenance.
/// Le type est filtré par l'API (paramètre `type`) : le top 8 est calculé
/// après le filtre.
class _TopContentCard extends StatelessWidget {
  const _TopContentCard({required this.items, required this.type, required this.onTypeChanged});

  final List<TopContent> items;

  /// `null` : tous ; sinon `post` ou `project`.
  final String? type;
  final ValueChanged<String?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Articles et projets les plus vus', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final (value, label) in const [(null, 'Tous'), ('post', 'Articles'), ('project', 'Projets')])
                PillFilterChip(label: label, selected: type == value, onTap: () => onTypeChanged(value)),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Aucune visite sur cette période.', style: muted),
            ),
          const SizedBox(height: 4),
          for (final item in items)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              // Ouvre la page sur le site (chemin relatif renvoyé par l'API).
              onTap: item.url.isEmpty
                  ? null
                  : () => launchUrl(Uri.parse('${Env.siteUrl}${item.url}'), mode: LaunchMode.externalApplication),
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Row(
                  children: [
                    Icon(item.isPost ? Icons.article_outlined : Icons.work_outline_rounded, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            '${item.visitors} visiteur${item.visitors > 1 ? 's' : ''} · ${_sourceLabel(item.topSource)}',
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${item.visits}', style: theme.textTheme.labelLarge),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Articles les plus engagés sur la période ; un tap ouvre l'article.
class _BlogTopPostsCard extends StatelessWidget {
  const _BlogTopPostsCard({required this.posts});

  final List<BlogTopPost> posts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Articles les plus engagés', style: theme.textTheme.titleSmall),
          for (final post in posts)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => PostFormScreen(id: post.id))),
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Row(
                  children: [
                    const Icon(Icons.article_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            '${post.reactions} réaction${post.reactions > 1 ? 's' : ''} · '
                            '${post.comments} commentaire${post.comments > 1 ? 's' : ''}',
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${post.views} lect.', style: theme.textTheme.labelLarge),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Grille à deux colonnes dont chaque ligne prend la hauteur de sa plus haute tuile.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 10),
                Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Carte pleine largeur des félicitations reçues, avec un trophée.
class CongratulationsCard extends StatelessWidget {
  const CongratulationsCard({super.key, required this.count, this.onTap});

  final int count;

  /// Ouvre l'historique des félicitations.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return SurfaceCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Félicitations', style: theme.textTheme.bodySmall?.copyWith(color: colors.muted)),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: theme.textTheme.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                const SizedBox(height: 2),
                Text(
                  'reçues sur le site',
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          ExcludeSemantics(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
              child: Icon(Icons.emoji_events_rounded, size: 32, color: colors.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}
