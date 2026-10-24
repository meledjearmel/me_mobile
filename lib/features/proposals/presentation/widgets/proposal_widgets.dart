import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/widgets/ai_badge.dart';
import '../../../../shared/widgets/status_tones.dart';
import '../../data/proposal.dart';
import '../../data/proposal_repository.dart';

/// Statut d'une proposition, avec le badge IA d'un brouillon rédigé par l'IA.
class ProposalStatusBadge extends StatelessWidget {
  const ProposalStatusBadge(this.proposal, {super.key});

  final Proposal proposal;

  @override
  Widget build(BuildContext context) {
    return StatusWithAiBadge(
      draftedBy: proposal.draftedBy,
      isDraft: proposal.status == ProposalStatus.draft,
      status: TypedStatusBadge(type: 'proposal', status: proposal.status.wireValue, label: proposal.status.label),
    );
  }
}

/// Copie la proposition et les réponses aux questions, prêtes à coller sur la plateforme.
Future<void> copyProposal(BuildContext context, Proposal proposal) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: proposal.clipboardText));
  messenger.showSnackBar(const SnackBar(content: Text('Proposition copiée.')));
}

/// Changement rapide de statut : feuille des statuts, puis `PUT` de l'objet complet.
/// Renvoie la proposition enregistrée, ou `null` si rien n'a changé.
Future<Proposal?> showProposalStatusSheet(BuildContext context, WidgetRef ref, Proposal proposal) async {
  final messenger = ScaffoldMessenger.of(context);
  final target = await showModalBottomSheet<ProposalStatus>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              proposal.jobTitle,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final status in ProposalStatus.values)
            ListTile(
              title: Text(status.label),
              trailing: status == proposal.status ? const Icon(Icons.check_rounded) : null,
              enabled: status != proposal.status,
              onTap: () => Navigator.pop(context, status),
            ),
        ],
      ),
    ),
  );
  if (target == null || target == proposal.status) {
    return null;
  }
  try {
    final saved = await ref.read(proposalRepositoryProvider).updateStatus(proposal, target);
    messenger.showSnackBar(SnackBar(content: Text('Statut : ${target.label}.')));
    return saved;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  }
}
