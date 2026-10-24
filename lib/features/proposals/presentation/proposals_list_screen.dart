import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/surfaces.dart';
import '../application/proposal_list_controller.dart';
import '../data/proposal.dart';
import 'proposal_detail_screen.dart';
import 'proposal_form_screen.dart';
import 'widgets/proposal_widgets.dart';

class ProposalsListScreen extends ConsumerWidget {
  const ProposalsListScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
    ref.invalidate(proposalListProvider);
  }

  /// Bascule un filtre : un second appui sur la même valeur le retire.
  void _toggle(WidgetRef ref, Map<String, Object?> filters, String key, String value) {
    final next = {...filters};
    next[key] == value ? next.remove(key) : next[key] = value;
    ref.read(proposalListProvider.notifier).setFilters(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(proposalListProvider);
    final notifier = ref.read(proposalListProvider.notifier);
    final filters = state.value?.query.filters ?? const <String, Object?>{};

    return ResourceListScaffold<Proposal>(
      title: 'Propositions freelance',
      searchHint: 'Offre, client, texte…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(proposalListProvider),
      onCreate: () => _open(context, ref, const ProposalFormScreen()),
      emptyIcon: Icons.work_history_outlined,
      emptyTitle: 'Aucune proposition pour l\'instant',
      emptyDescription: 'Ajoutez celles que vous envoyez sur Upwork, Malt… avec le bouton +.',
      filterChips: [
        for (final platform in ProposalPlatform.values)
          ChoiceChip(
            label: Text(platform.label),
            selected: filters['platform'] == platform.wireValue,
            onSelected: (_) => _toggle(ref, filters, 'platform', platform.wireValue),
            showCheckmark: false,
          ),
        for (final status in ProposalStatus.values)
          ChoiceChip(
            label: Text(status.label),
            selected: filters['status'] == status.wireValue,
            onSelected: (_) => _toggle(ref, filters, 'status', status.wireValue),
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, proposal) => GestureDetector(
        // Appui long : changer le statut sans ouvrir la fiche.
        onLongPress: () async {
          final saved = await showProposalStatusSheet(context, ref, proposal);
          if (saved != null) {
            notifier.updateItem((p) => p.id == saved.id, (_) => saved);
          }
        },
        child: ListCardTile(
          onTap: () => _open(context, ref, ProposalDetailScreen(id: proposal.id)),
          leading: InitialsTile(proposal.platform.label),
          title: proposal.jobTitle,
          subtitle: proposal.platformLine,
          meta: proposal.sentAt == null ? '—' : DateFormat('d MMM y', 'fr_FR').format(proposal.sentAt!),
          badge: ProposalStatusBadge(proposal),
        ),
      ),
    );
  }
}
