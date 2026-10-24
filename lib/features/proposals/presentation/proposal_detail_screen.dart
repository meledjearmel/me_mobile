import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../application/proposal_list_controller.dart';
import '../data/proposal.dart';
import '../data/proposal_repository.dart';
import 'proposal_form_screen.dart';
import 'widgets/proposal_widgets.dart';

/// Fiche d'une proposition : texte à copier, statut, offre et notes.
class ProposalDetailScreen extends ConsumerStatefulWidget {
  const ProposalDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ProposalDetailScreen> createState() => _ProposalDetailScreenState();
}

class _ProposalDetailScreenState extends ConsumerState<ProposalDetailScreen> {
  late Future<Proposal> _future = _load();

  Future<Proposal> _load() => ref.read(proposalRepositoryProvider).get(widget.id);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _replace(Proposal updated) {
    setState(() => _future = Future.value(updated));
    ref.read(proposalListProvider.notifier).updateItem((p) => p.id == updated.id, (_) => updated);
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context)
        .push<Object?>(MaterialPageRoute(builder: (context) => ProposalFormScreen(id: widget.id)));
    if (!mounted) {
      return;
    }
    if (result == ProposalFormScreen.deleted) {
      Navigator.of(context).pop();
    } else if (result is Proposal) {
      _replace(result);
    }
  }

  Future<void> _changeStatus(Proposal proposal) async {
    final saved = await showProposalStatusSheet(context, ref, proposal);
    if (saved != null && mounted) {
      _replace(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        actions: [IconButton(tooltip: 'Modifier', onPressed: _edit, icon: const Icon(Icons.edit_outlined))],
      ),
      body: FutureBuilder<Proposal>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error is ApiException ? (snapshot.error! as ApiException).message : 'Erreur.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _refresh, child: const Text('Réessayer')),
                ],
              ),
            );
          }
          return RefreshIndicator(onRefresh: _refresh, child: _buildBody(context, snapshot.data!));
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Proposal proposal) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return ListView(
      padding: pageInsets(context),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FormHeader(title: proposal.jobTitle, subtitle: proposal.platformLine),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Align(alignment: Alignment.centerLeft, child: ProposalStatusBadge(proposal)),
        ),
        const SizedBox(height: 16),
        KeyFacts(
          facts: [
            (value: proposal.sentAt == null ? '—' : relativeDate(proposal.sentAt!), label: 'Envoyée'),
            (value: proposal.bid?.isNotEmpty == true ? proposal.bid! : '—', label: 'Tarif'),
            (value: proposal.connects == null ? '—' : '${proposal.connects}', label: 'Connects'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _changeStatus(proposal),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Statut'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => copyProposal(context, proposal),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copier'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FormSection(
          title: 'Proposition',
          children: [
            if (proposal.clientName?.isNotEmpty == true) Text('Pour ${proposal.clientName}', style: muted),
            SelectableText(proposal.body),
          ],
        ),
        if (proposal.screeningAnswers?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          FormSection(title: 'Réponses aux questions', children: [SelectableText(proposal.screeningAnswers!)]),
        ],
        if (proposal.jobUrl != null || proposal.jobPosting != null) ...[
          const SizedBox(height: 12),
          FormSection(
            title: 'Offre',
            initiallyExpanded: false,
            children: [
              if (proposal.jobUrl != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse(proposal.jobUrl!), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Ouvrir l\'offre'),
                  ),
                ),
              if (proposal.jobPosting != null) SelectableText(proposal.jobPosting!),
            ],
          ),
        ],
        if (proposal.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          FormSection(title: 'Notes privées', children: [Text(proposal.notes!)]),
        ],
        if (proposal.draftedBy?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text('Rédigée par ${proposal.draftedBy}', style: muted),
        ],
      ],
    );
  }
}
