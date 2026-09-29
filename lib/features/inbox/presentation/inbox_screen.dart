import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_target.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../dashboard/data/dashboard_repository.dart';
import 'contacts/contacts_tab.dart';
import 'engagements/engagements_tab.dart';
import 'testimonials/testimonials_tab.dart';

/// Boîte de réception : contacts, collaborations et avis (§4.2), en 3 segments.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  static const _tabs = [(label: 'Messages'), (label: 'Demandes'), (label: 'Avis')];

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> with SingleTickerProviderStateMixin {
  late final _controller = TabController(length: InboxScreen._tabs.length, vsync: this);
  int? _autoOpenContactId;
  int? _autoOpenEngagementId;
  int? _autoOpenTestimonialId;

  @override
  void initState() {
    super.initState();
    // Une notification tapée pose une cible en attente (§4.6) : on ouvre son
    // onglet (et directement son détail) puis on la consomme.
    final target = ref.read(pendingPushTargetProvider);
    if (target != null) {
      _controller.index = target.type.inboxTabIndex;
      switch (target.type) {
        case PushResourceType.contact:
          _autoOpenContactId = target.id;
        case PushResourceType.engagement:
          _autoOpenEngagementId = target.id;
        case PushResourceType.testimonial:
          _autoOpenTestimonialId = target.id;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pendingPushTargetProvider.notifier).state = null;
      });
    } else {
      final tabIndex = ref.read(initialInboxTabProvider);
      if (tabIndex != null) {
        _controller.index = tabIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(initialInboxTabProvider.notifier).state = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todo = ref.watch(dashboardProvider).value?.todo;
    // Même ordre que InboxScreen._tabs (voir aussi PushResourceType.inboxTabIndex).
    final counts = [todo?.contacts ?? 0, todo?.engagements ?? 0, todo?.testimonials ?? 0];

    return Scaffold(
      // Titre et sélecteur flottent : les listes défilent dessous.
      extendBodyBehindAppBar: true,
      appBar: GlassHeader(
        height: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Boîte de réception',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedTabs(
                controller: _controller,
                labels: [for (final tab in InboxScreen._tabs) tab.label],
                counts: counts,
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [
          ContactsTab(autoOpenId: _autoOpenContactId),
          EngagementsTab(autoOpenId: _autoOpenEngagementId),
          TestimonialsTab(autoOpenId: _autoOpenTestimonialId),
        ],
      ),
    );
  }
}
