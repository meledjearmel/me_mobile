import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/resource_list_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/review_invitation_list_controller.dart';
import '../../data/review_invitation.dart';
import 'review_invitation_form_screen.dart';
import 'testimonial_edit_screen.dart';

/// Copie le lien d'une demande d'avis dans le presse-papiers.
Future<void> copyInvitationLink(BuildContext context, ReviewInvitation invitation) async {
  await Clipboard.setData(ClipboardData(text: invitation.url));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié.')));
  }
}

/// Ouvre l'app de messagerie avec un e-mail prérempli contenant le lien,
/// dans la langue de la demande.
Future<void> emailInvitationLink(ReviewInvitation invitation) {
  final english = invitation.locale == 'en';
  final greeting = invitation.name?.isNotEmpty == true
      ? (english ? 'Hello ${invitation.name},' : 'Bonjour ${invitation.name},')
      : (english ? 'Hello,' : 'Bonjour,');
  final body = english
      ? '$greeting\n\nWould you share a few words about our work together? '
            'This personal link opens a short form:\n${invitation.url}\n\nThank you!'
      : '$greeting\n\nAccepteriez-vous de laisser quelques mots sur notre collaboration ? '
            'Ce lien personnel ouvre un court formulaire :\n${invitation.url}\n\nMerci !';
  return launchUrl(
    Uri(
      scheme: 'mailto',
      path: invitation.email ?? '',
      query: _encodeQuery({'subject': english ? 'Your feedback' : 'Votre avis', 'body': body}),
    ),
  );
}

// `Uri.queryParameters` encode les espaces en « + », mal lus par certaines
// apps de messagerie : on encode à la main en %20.
String _encodeQuery(Map<String, String> params) =>
    params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

/// Demandes d'avis : liens personnels à usage unique vers le formulaire d'avis.
class ReviewInvitationsScreen extends ConsumerWidget {
  const ReviewInvitationsScreen({super.key});

  static const _statuses = [null, 'pending', 'used', 'expired'];

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ReviewInvitationFormScreen()));
    ref.invalidate(reviewInvitationListProvider);
  }

  Future<void> _openActions(BuildContext context, WidgetRef ref, ReviewInvitation invitation) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(invitation.displayName),
              subtitle: Text(invitation.url, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            if (invitation.testimonialId != null)
              ListTile(
                leading: const Icon(Icons.rate_review_outlined),
                title: const Text('Voir l\'avis reçu'),
                onTap: () => Navigator.pop(context, 'open'),
              ),
            if (invitation.status == ReviewInvitationStatus.pending) ...[
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copier le lien'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Envoyer par e-mail'),
                onTap: () => Navigator.pop(context, 'email'),
              ),
            ],
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
              title: const Text('Supprimer la demande'),
              subtitle: const Text('Le lien cesse de fonctionner ; un avis reçu reste en place.'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    switch (action) {
      case 'open':
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => TestimonialEditScreen(id: invitation.testimonialId!)));
      case 'copy':
        await copyInvitationLink(context, invitation);
      case 'email':
        await emailInvitationLink(invitation);
      case 'delete':
        try {
          await ref.read(reviewInvitationRepositoryProvider).delete(invitation.id);
          ref.read(reviewInvitationListProvider.notifier).removeItem((i) => i.id == invitation.id);
        } on ApiException catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reviewInvitationListProvider);
    final notifier = ref.read(reviewInvitationListProvider.notifier);
    final current = state.value?.query.filters['status'] as String?;

    return ResourceListScaffold<ReviewInvitation>(
      title: 'Demandes d\'avis',
      searchHint: 'Nom, e-mail, mémo…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(reviewInvitationListProvider),
      onCreate: () => _create(context, ref),
      emptyIcon: Icons.forward_to_inbox_outlined,
      emptyTitle: 'Aucune demande pour l\'instant',
      emptyDescription: 'Créez un lien personnel avec le bouton + et envoyez-le à un client ou un collègue.',
      filterChips: [
        for (final status in _statuses)
          ChoiceChip(
            label: Text(status == null ? 'Toutes' : ReviewInvitationStatus.fromWire(status).label),
            selected: current == status,
            onSelected: (_) => notifier.setFilters({'status': status}),
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, invitation) => ListTile(
        onTap: () => _openActions(context, ref, invitation),
        leading: CircleAvatar(child: Text(invitation.locale.toUpperCase(), style: const TextStyle(fontSize: 12))),
        title: Text(invitation.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            invitation.subject ?? 'Avis général',
            if (invitation.note?.isNotEmpty == true) invitation.note!,
            if (invitation.status == ReviewInvitationStatus.pending && invitation.expiresAt != null)
              'expire le ${DateFormat('d MMM', 'fr_FR').format(invitation.expiresAt!)}',
            if (invitation.usedAt != null) 'reçu ${relativeDate(invitation.usedAt!)}',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: StatusBadge(invitation.status.label, prominent: invitation.status == ReviewInvitationStatus.used),
      ),
    );
  }
}
