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
import '../../celebrations/presentation/congratulations_screen.dart';
import '../../blog/presentation/post_form_screen.dart';
import '../../cv_downloads/presentation/cv_downloads_screen.dart';
import '../../billing/presentation/widgets/reminders_card.dart';
import '../data/dashboard.dart';
import '../data/dashboard_repository.dart';
import '../data/health_labels.dart';
import '../../billing/presentation/documents_list_screen.dart';
import '../../content/professional_references/presentation/professional_references_list_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../projects/presentation/projects_list_screen.dart';
import 'widgets/health_checklist.dart';
import 'widgets/home_sections.dart';
import 'statistics_screen.dart';
import 'widgets/review_cards.dart';

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
        _openPendingHomeTarget(ref.read(pendingPushTargetProvider));
      }
    });
  }

  /// Notification consommée par l'accueil, puis effacée : « Nouvelles
  /// félicitations » ouvre leur historique en marquant l'envoi visé, « CV
  /// téléchargé » ouvre les téléchargements sur le détail de celui-ci.
  void _openPendingHomeTarget(PushTarget? target) {
    final Widget screen;
    switch (target?.type) {
      case PushResourceType.congratulation:
        screen = CongratulationsScreen(highlightId: target!.id);
      case PushResourceType.cvDownload:
        screen = CvDownloadsScreen(openId: target!.id);
      case PushResourceType.postReaction:
        screen = PostFormScreen(id: target!.id);
      default:
        return;
    }
    ref.read(pendingPushTargetProvider.notifier).state = null;
    ref.invalidate(dashboardProvider);
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 5 ? 'Bonsoir' : 'Bonjour';
  }

  void _openInboxTab(int index) {
    ref.read(initialInboxTabProvider.notifier).state = index;
    context.go('/inbox');
  }

  /// Ouvre l'élément dans la boîte de réception, comme une notification.
  void _openItem(PushResourceType type, int id) {
    ref.read(pendingPushTargetProvider.notifier).state = PushTarget(type: type, id: id);
    context.go('/inbox');
  }

  void _openHealthItem(HealthItem item) {
    final Widget screen;
    switch (healthLabels[item.key]?.destination) {
      case 'Avis':
        _openInboxTab(2);
        return;
      case 'Profil':
        screen = const ProfileScreen();
      case 'Références':
        screen = const ProfessionalReferencesListScreen();
      case 'Projets':
        screen = const ProjectsListScreen();
      default:
        context.go('/content');
        return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    // Accueil déjà monté (app en arrière-plan) : la cible arrive après coup.
    ref.listen(pendingPushTargetProvider, (_, target) => _openPendingHomeTarget(target));
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
          onRefresh: () {
            ref.invalidate(documentRemindersProvider);
            return ref.refresh(dashboardProvider.future);
          },
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
              // Échec d'une actualisation : on garde les dernières données, avec un bandeau.
              if (dashboard.hasError && dashboard.hasValue)
                _StaleBanner(onRetry: () => ref.invalidate(dashboardProvider)),
              dashboard.when(
                skipError: true,
                loading: () => const _DashboardSkeleton(),
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
                  onItemTap: _openItem,
                  onHealthTap: _openHealthItem,
                  onSeeInbox: () => context.go('/inbox'),
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
    required this.onItemTap,
    required this.onHealthTap,
    required this.onSeeInbox,
  });

  final Dashboard dashboard;
  final ValueChanged<int> onTodoTap;
  final void Function(PushResourceType type, int id) onItemTap;
  final ValueChanged<HealthItem> onHealthTap;
  final VoidCallback onSeeInbox;

  @override
  Widget build(BuildContext context) {
    final trends = dashboard.trends;
    const gap = SizedBox(height: 28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TodoCard(todo: dashboard.todo, onTap: onTodoTap),
        TodayCard(
          dashboard: dashboard,
          onAppointmentTap: (id) => onItemTap(PushResourceType.appointment, id),
          onBillingTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DocumentsListScreen())),
        ),
        const SizedBox(height: 10),
        ReviewCards(todo: dashboard.todo),
        // Devis sans réponse et factures en retard ; rien tant qu'aucune relance n'est suggérée.
        const RemindersCard(),
        gap,
        SectionHeader(
          'En bref',
          actionLabel: 'Tout voir',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const StatisticsScreen())),
        ),
        const SizedBox(height: 8),
        AudienceCard(dashboard: dashboard),
        const SizedBox(height: 10),
        _TileGrid(
          children: [
            TrendTile(label: 'Visiteurs uniques', trend: trends?['visitors']),
            TrendTile(label: 'Demandes de collab.', trend: trends?['engagements']),
            TrendTile(label: 'Messages reçus', trend: trends?['contacts']),
            TrendTile(label: 'Rendez-vous demandés', trend: trends?['appointments']),
          ],
        ),
        const SizedBox(height: 10),
        CvDownloadsCard(
          summary: dashboard.cvDownloads,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CvDownloadsScreen())),
        ),
        const SizedBox(height: 10),
        CongratulationsCard(
          count: dashboard.content.congratulations,
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CongratulationsScreen())),
        ),
        gap,
        ActivityFeed(items: recentActivity(dashboard.recent), onTap: onItemTap, onSeeAll: onSeeInbox),
        gap,
        const SectionHeader('À compléter'),
        const SizedBox(height: 8),
        HealthChecklist(items: dashboard.health, onTap: onHealthTap),
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
      (label: 'Rendez-vous à confirmer', count: todo.appointments, tab: 3),
      (label: 'Commentaires à modérer', count: todo.comments, tab: 4),
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

/// Bandeau discret quand l'actualisation échoue alors que des données sont affichées.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text('Hors ligne : dernières données affichées.', style: theme.textTheme.bodySmall)),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

/// Squelette de l'accueil au premier chargement : la forme des cartes, en pulsation.
class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton();

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    Widget block(double height, {double radius = 24}) => Container(
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
    );

    return Semantics(
      label: 'Chargement en cours',
      child: FadeTransition(
        opacity: _controller.drive(Tween(begin: 0.5, end: 1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            block(190, radius: 28),
            const SizedBox(height: 10),
            block(130),
            const SizedBox(height: 28),
            block(160),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: block(92, radius: 22)),
                const SizedBox(width: 10),
                Expanded(child: block(92, radius: 22)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
