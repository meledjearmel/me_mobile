import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/relative_date.dart';
import '../../content/distinctions/data/distinction_repository.dart';
import '../../content/distinctions/presentation/distinction_form_screen.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/surfaces.dart';
import '../application/congratulation_list_controller.dart';
import '../data/congratulation.dart';

/// Historique des félicitations reçues sur le site, du plus récent au plus
/// ancien. [highlightId] : envoi visé par une notification tapée, marqué d'une
/// pastille.
class CongratulationsScreen extends ConsumerStatefulWidget {
  const CongratulationsScreen({super.key, this.highlightId});

  final int? highlightId;

  @override
  ConsumerState<CongratulationsScreen> createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends ConsumerState<CongratulationsScreen> {
  static const _sources = [null, CongratulationSource.surprise, CongratulationSource.about];

  @override
  void initState() {
    super.initState();
    // De nouvelles félicitations ont pu arriver depuis la dernière ouverture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(congratulationListProvider);
      }
    });
  }

  /// Ouvre la fiche de la distinction félicitée, si elle existe encore.
  Future<void> _openDistinction(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(distinctionRepositoryProvider).get(id);
    } on NotFoundException {
      messenger.showSnackBar(const SnackBar(content: Text('Cette distinction n\'existe plus.')));
      return;
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (context) => DistinctionFormScreen(id: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(congratulationListProvider);
    final notifier = ref.read(congratulationListProvider.notifier);
    final current = state.value?.query.filters['source'] as String?;

    return ResourceListScaffold<Congratulation>(
      title: 'Félicitations',
      searchHint: 'Motif…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(congratulationListProvider),
      filterChips: [
        for (final source in _sources)
          PillFilterChip(
            label: source == null ? 'Toutes' : source.label,
            selected: current == source?.wireValue,
            onTap: () => notifier.setFilters({'source': source?.wireValue}),
          ),
      ],
      emptyIcon: Icons.emoji_events_outlined,
      emptyTitle: 'Aucune félicitation pour l\'instant',
      emptyDescription: 'Les félicitations des visiteurs du site apparaîtront ici.',
      itemBuilder: (context, item) => ListCardTile(
        leading: const IconTile(Icons.emoji_events_outlined, size: 38),
        title: item.reason.isEmpty ? item.source.label : item.reason,
        subtitle: [
          '${item.count} clic${item.count > 1 ? 's' : ''}',
          if (item.locale != null) item.locale!.toUpperCase(),
        ].join(' · '),
        meta: item.createdAt == null ? null : relativeDate(item.createdAt!),
        badge: StatusBadge(item.source.label),
        unread: item.id == widget.highlightId,
        onTap: item.distinctionId == null ? null : () => _openDistinction(item.distinctionId!),
      ),
    );
  }
}
