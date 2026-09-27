import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_target.dart';
import '../../../shared/widgets/feedback.dart';

/// Boîte de réception : contacts, collaborations et avis (§4.2), en 3
/// segments. Le contenu de chaque segment arrive à l'étape 3 : pour l'instant,
/// cet écran ouvre déjà le bon onglet au tap sur une notification (§4.6).
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  static const _tabs = [
    (icon: Icons.mail_outline_rounded, label: 'Messages'),
    (icon: Icons.handshake_outlined, label: 'Collaborations'),
    (icon: Icons.reviews_outlined, label: 'Avis'),
  ];

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> with SingleTickerProviderStateMixin {
  late final _controller = TabController(length: InboxScreen._tabs.length, vsync: this);

  @override
  void initState() {
    super.initState();
    // Une notification tapée pose une cible en attente (§4.6) : on ouvre son
    // onglet puis on la consomme, pour ne pas la rejouer à la prochaine visite.
    final target = ref.read(pendingPushTargetProvider);
    if (target != null) {
      _controller.index = target.type.inboxTabIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pendingPushTargetProvider.notifier).state = null;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = ref.watch(pendingPushTargetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boîte de réception'),
        bottom: TabBar(
          controller: _controller,
          tabs: [for (final tab in InboxScreen._tabs) Tab(icon: Icon(tab.icon), text: tab.label)],
        ),
      ),
      body: Column(
        children: [
          if (target != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _NotificationBanner(
                target: target,
                onDismiss: () => ref.read(pendingPushTargetProvider.notifier).state = null,
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: const [
                ComingSoon(
                  icon: Icons.mail_outline_rounded,
                  title: 'Messages du formulaire de contact',
                  description: 'Lecture, statuts (Nouveau, Lu, Répondu) : prévu à l\'étape 3.',
                ),
                ComingSoon(
                  icon: Icons.handshake_outlined,
                  title: 'Demandes de collaboration',
                  description: 'Freelance et embauches, avec envoi automatique du CV : prévu à l\'étape 3.',
                ),
                ComingSoon(
                  icon: Icons.reviews_outlined,
                  title: 'Avis à modérer',
                  description: 'Approuver, rejeter, corriger le texte, mettre à la une : prévu à l\'étape 3.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({required this.target, required this.onDismiss});

  final PushTarget target;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: scheme.onSurface, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ouvert depuis une notification : ${target.type.label} #${target.id}. '
              'La fiche détaillée arrive à l\'étape 3.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Fermer',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
