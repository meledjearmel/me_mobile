import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_target.dart';
import 'contacts/contacts_tab.dart';
import 'engagements/engagements_tab.dart';
import 'testimonials/testimonials_tab.dart';

/// Boîte de réception : contacts, collaborations et avis (§4.2), en 3 segments.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boîte de réception'),
        bottom: TabBar(
          controller: _controller,
          tabs: [for (final tab in InboxScreen._tabs) Tab(icon: Icon(tab.icon), text: tab.label)],
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
