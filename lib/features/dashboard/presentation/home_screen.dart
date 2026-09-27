import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/push/push_service.dart';
import '../../../core/push/push_target.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session_controller.dart';
import '../data/dashboard.dart';
import '../data/dashboard_repository.dart';
import '../data/health_labels.dart';
import 'widgets/distribution_list.dart';
import 'widgets/health_checklist.dart';
import 'widgets/recent_section.dart';
import 'widgets/stat_tile.dart';
import 'widgets/visits_chart.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Après la connexion (pas au premier lancement à froid) et à chaque
    // démarrage tant que la session est ouverte : le jeton FCM a pu changer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(pushServiceProvider).registerForCurrentSession(context);
      }
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 5 ? 'Bonsoir' : 'Bonjour';
  }

  void _openInboxTab(int index) {
    ref.read(initialInboxTabProvider.notifier).state = index;
    context.go('/inbox');
  }

  void _openContact(int id) {
    ref.read(pendingPushTargetProvider.notifier).state = PushTarget(type: PushResourceType.contact, id: id);
    context.go('/inbox');
  }

  void _openEngagement(int id) {
    ref.read(pendingPushTargetProvider.notifier).state = PushTarget(type: PushResourceType.engagement, id: id);
    context.go('/inbox');
  }

  void _openTestimonial(int id) {
    ref.read(pendingPushTargetProvider.notifier).state = PushTarget(type: PushResourceType.testimonial, id: id);
    context.go('/inbox');
  }

  void _openHealthItem(HealthItem item) {
    final destination = healthLabels[item.key]?.destination;
    if (destination == 'Avis') {
      _openInboxTab(2);
    } else {
      // Profil / Références / Projets : écrans prévus aux étapes 4-6.
      context.go('/content');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).value;
    final dashboard = ref.watch(dashboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  InitialsAvatar(user?.initials ?? '?'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        Text(user?.firstName ?? '', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                  const AppLogo(height: 20),
                ],
              ),
              const SizedBox(height: 24),
              dashboard.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      const Text('Impossible de charger le tableau de bord.'),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: () => ref.invalidate(dashboardProvider), child: const Text('Réessayer')),
                    ],
                  ),
                ),
                data: (data) => _DashboardBody(
                  dashboard: data,
                  onTodoTap: _openInboxTab,
                  onContactTap: _openContact,
                  onEngagementTap: _openEngagement,
                  onTestimonialTap: _openTestimonial,
                  onHealthTap: _openHealthItem,
                  onSeeAllContacts: () => _openInboxTab(0),
                  onSeeAllEngagements: () => _openInboxTab(1),
                  onSeeAllTestimonials: () => _openInboxTab(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.dashboard,
    required this.onTodoTap,
    required this.onContactTap,
    required this.onEngagementTap,
    required this.onTestimonialTap,
    required this.onHealthTap,
    required this.onSeeAllContacts,
    required this.onSeeAllEngagements,
    required this.onSeeAllTestimonials,
  });

  final Dashboard dashboard;
  final ValueChanged<int> onTodoTap;
  final ValueChanged<int> onContactTap;
  final ValueChanged<int> onEngagementTap;
  final ValueChanged<int> onTestimonialTap;
  final ValueChanged<HealthItem> onHealthTap;
  final VoidCallback onSeeAllContacts;
  final VoidCallback onSeeAllEngagements;
  final VoidCallback onSeeAllTestimonials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todo = dashboard.todo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('À traiter', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TodoCard(
                icon: Icons.mail_outline_rounded,
                count: todo.contacts,
                label: 'Messages',
                onTap: () => onTodoTap(0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodoCard(
                icon: Icons.handshake_outlined,
                count: todo.engagements,
                label: 'Collaborations',
                onTap: () => onTodoTap(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodoCard(
                icon: Icons.reviews_outlined,
                count: todo.testimonials,
                label: 'Avis',
                onTap: () => onTodoTap(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${dashboard.visits.total}', style: theme.textTheme.headlineMedium),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'visites sur ${dashboard.visits.periodDays} jours',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        Text(
          'Aujourd\'hui : ${dashboard.visits.today} · FR ${dashboard.visits.french} · EN ${dashboard.visits.english}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        VisitsChart(daily: dashboard.visits.daily),
        if (dashboard.visits.topPages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final page in dashboard.visits.topPages)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${page.path} · ${page.count}', style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ],
        const SizedBox(height: 28),
        Text('Contenu', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        SizedBox(
          height: 78,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              StatTile(value: dashboard.content.projects.published, label: 'Projets publiés'),
              const SizedBox(width: 8),
              StatTile(value: dashboard.content.projects.featured, label: 'Projets à la une'),
              const SizedBox(width: 8),
              StatTile(value: dashboard.content.skills, label: 'Compétences'),
              const SizedBox(width: 8),
              StatTile(value: dashboard.content.technologies, label: 'Technologies'),
              const SizedBox(width: 8),
              StatTile(value: dashboard.content.domains, label: 'Domaines'),
              const SizedBox(width: 8),
              StatTile(value: dashboard.content.experiences, label: 'Expériences'),
              const SizedBox(width: 8),
              StatTile(value: dashboard.content.educations, label: 'Formations'),
              const SizedBox(width: 8),
              StatTile(value: dashboard.content.referencesOnCv, label: 'Références sur CV'),
              const SizedBox(width: 8),
              StatTile(value: dashboard.content.yearsOfExperience, label: 'Ans d\'expérience'),
              const SizedBox(width: 8),
              StatTile(value: dashboard.content.testimonials.approved, label: 'Avis approuvés'),
              const SizedBox(width: 8),
              StatTile(value: dashboard.content.engagements.cvSent, label: 'CV envoyés'),
              const SizedBox(width: 8),
              StatTile(value: dashboard.content.congratulations, label: 'Félicitations'),
            ],
          ),
        ),
        if (dashboard.distribution.skillsByDomain.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Compétences par domaine', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          DomainDistributionList(items: dashboard.distribution.skillsByDomain),
        ],
        if (dashboard.distribution.projectsByDomain.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Projets par domaine', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          DomainDistributionList(items: dashboard.distribution.projectsByDomain),
        ],
        if (dashboard.distribution.technologiesByCategory.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Technologies par catégorie', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          CategoryDistributionList(items: dashboard.distribution.technologiesByCategory),
        ],
        const SizedBox(height: 28),
        Text('À compléter', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        HealthChecklist(items: dashboard.health, onTap: onHealthTap),
        const SizedBox(height: 28),
        RecentSection(
          title: 'Derniers messages',
          items: [
            for (final c in dashboard.recent.contacts)
              (id: c.id, title: c.name, subtitle: c.subject ?? '', isNew: c.isNew, at: c.at),
          ],
          onTapItem: onContactTap,
          onSeeAll: onSeeAllContacts,
          emptyLabel: 'Aucun message pour l\'instant.',
        ),
        const SizedBox(height: 20),
        RecentSection(
          title: 'Dernières demandes',
          items: [
            for (final e in dashboard.recent.engagements)
              (
                id: e.id,
                title: e.name,
                subtitle: [e.company, e.subject].whereType<String>().join(' · '),
                isNew: e.isNew,
                at: e.at,
              ),
          ],
          onTapItem: onEngagementTap,
          onSeeAll: onSeeAllEngagements,
          emptyLabel: 'Aucune demande pour l\'instant.',
        ),
        const SizedBox(height: 20),
        RecentSection(
          title: 'Avis en attente',
          items: [
            for (final t in dashboard.recent.testimonials)
              (id: t.id, title: t.name, subtitle: t.excerpt, isNew: true, at: t.at),
          ],
          onTapItem: onTestimonialTap,
          onSeeAll: onSeeAllTestimonials,
          emptyLabel: 'Aucun avis en attente.',
        ),
      ],
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({required this.icon, required this.count, required this.label, required this.onTap});

  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTodo = count > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: hasTodo ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(
                '$count',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
