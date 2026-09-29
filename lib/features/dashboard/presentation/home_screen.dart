import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../profile/application/profile_providers.dart';
import '../../../shared/widgets/glass.dart';
import '../../../app/theme/app_palette.dart';
import '../../../core/push/push_service.dart';
import '../../../core/push/push_target.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../auth/application/session_controller.dart';
import '../data/dashboard.dart';
import '../data/dashboard_repository.dart';
import '../data/health_labels.dart';
import 'widgets/health_checklist.dart';
import 'widgets/recent_section.dart';
import 'statistics_screen.dart';
import 'widgets/stat_tile.dart';

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
    final muted = theme.colorScheme.onSurfaceVariant;
    final now = DateTime.now();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar.statusOnly(),
      // Builder : les marges lues sous le Scaffold tiennent compte des barres flottantes.
      body: Builder(
        builder: (context) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardProvider.future),
          child: ListView(
            padding: pageInsets(context, horizontal: 20, top: 12),
            children: [
              Row(
                children: [
                  InitialsAvatar(user?.initials ?? '?', photoUrl: ref.watch(profileProvider).value?.photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting()},', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                        Text(user?.firstName ?? '', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                  const AppLogo(height: 18),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                toBeginningOfSentenceCase(DateFormat.EEEE('fr_FR').format(now)),
                style: theme.textTheme.headlineMedium,
              ),
              Text(
                DateFormat.MMMMd('fr_FR').format(now),
                style: theme.textTheme.headlineMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 20),
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
    final content = dashboard.content;
    const gap = SizedBox(height: 28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TodoCard(todo: dashboard.todo, onTap: onTodoTap),
        gap,
        SectionHeader(
          'En bref',
          actionLabel: 'Tout voir',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const StatisticsScreen())),
        ),
        const SizedBox(height: 8),
        _TileGrid(
          children: [
            StatTile(
              value: content.projects.published,
              label: 'Projets publiés',
              caption: '${content.projects.featured} à la une',
            ),
            StatTile(value: content.engagements.cvSent, label: 'CV envoyés'),
            StatTile(
              value: content.testimonials.approved,
              label: 'Avis approuvés',
              caption: content.testimonials.pending > 0 ? '${content.testimonials.pending} en attente' : null,
            ),
            StatTile(value: content.yearsOfExperience, label: 'Ans d\'expérience'),
          ],
        ),
        const SizedBox(height: 10),
        CongratulationsCard(count: content.congratulations),
        gap,
        const SectionHeader('À compléter'),
        const SizedBox(height: 8),
        HealthChecklist(items: dashboard.health, onTap: onHealthTap),
        gap,
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
        gap,
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
        gap,
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

/// Carte or « À traiter » : total en grand, une ligne par type, chacune
/// ouvrant l'onglet correspondant de la boîte de réception.
class _TodoCard extends StatelessWidget {
  const _TodoCard({required this.todo, required this.onTap});

  final DashboardTodo todo;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    if (todo.total == 0) {
      return SurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: colors.success),
            const SizedBox(width: 12),
            const Expanded(child: Text('Rien à traiter, la boîte de réception est à jour.')),
          ],
        ),
      );
    }

    final onGold = colors.onAccent;
    final rows = [
      (label: 'Messages non lus', count: todo.contacts, tab: 0),
      (label: 'Demandes de collaboration', count: todo.engagements, tab: 1),
      (label: 'Avis en attente', count: todo.testimonials, tab: 2),
    ].where((r) => r.count > 0).toList();

    return SurfaceCard(
      color: colors.accent,
      radius: 28,
      padding: const EdgeInsets.all(18),
      onTap: () => onTap(rows.first.tab),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('À traiter', style: theme.textTheme.titleMedium?.copyWith(color: onGold)),
                    Text(
                      'Ce qui attend ta réponse',
                      style: theme.textTheme.bodySmall?.copyWith(color: onGold.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              const ArrowBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Text('${todo.total}', style: theme.textTheme.displayMedium?.copyWith(color: onGold, height: 1)),
          const SizedBox(height: 12),
          for (final row in rows) ...[
            Material(
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(row.tab),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(row.label, style: theme.textTheme.labelLarge?.copyWith(color: onGold)),
                      ),
                      Text('${row.count}', style: theme.textTheme.labelLarge?.copyWith(color: onGold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

/// Grille à deux colonnes dont chaque ligne prend la hauteur de sa plus haute tuile.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});

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
