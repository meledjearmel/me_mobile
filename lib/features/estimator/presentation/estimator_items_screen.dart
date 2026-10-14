import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/estimator.dart';
import '../data/estimator_repository.dart';
import 'estimator_item_form_screen.dart';
import 'widgets/estimator_list_body.dart';

/// Types de projet ([kind] = `projectType`) ou options ([kind] = `feature`).
class EstimatorItemsScreen extends ConsumerWidget {
  const EstimatorItemsScreen({super.key, required this.kind});

  final EstimatorItemKind kind;

  bool get _isFeature => kind == EstimatorItemKind.feature;

  Future<void> _open(BuildContext context, WidgetRef ref, [EstimatorItem? item]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EstimatorItemFormScreen(kind: kind, item: item),
      ),
    );
    if (changed == true) {
      ref
        ..invalidate(estimatorItemsProvider)
        ..invalidate(estimatorRatesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(estimatorItemsProvider);
    final rates = ref.watch(estimatorRatesProvider).value ?? const [];
    final projectTypes = {
      for (final item in all.value ?? const <EstimatorItem>[])
        if (item.kind == EstimatorItemKind.projectType) item.id: item.name.display,
    };

    String subtitleOf(EstimatorItem item) {
      final rate = rates.where((r) => r.id == item.rateId).firstOrNull;
      return [
        item.effortLabel,
        if (!_isFeature && item.billing != null) item.billing!.label,
        if (_isFeature)
          item.projectTypeIds.isEmpty
              ? 'Tous les types'
              : item.projectTypeIds.map((id) => projectTypes[id] ?? '#$id').join(', '),
        if (item.hourlyRates.isNotEmpty) 'Taux propres' else if (rate != null) rate.name.display,
      ].join(' · ');
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(),
      floatingActionButton: GlassFab(
        icon: Icons.add_rounded,
        tooltip: 'Ajouter',
        onPressed: () => _open(context, ref),
        bottom: MediaQuery.paddingOf(context).bottom,
      ),
      body: EstimatorListBody<EstimatorItem>(
        title: _isFeature ? 'Options' : 'Types de projet',
        subtitle: _isFeature
            ? 'Ce qui s\'ajoute au projet : des heures ou un pourcentage de ses heures.'
            : 'La base de l\'estimation : le visiteur en choisit un.',
        value: all.whenData((items) => items.where((i) => i.kind == kind).toList()),
        onRefresh: () => ref.refresh(estimatorItemsProvider.future),
        emptyIcon: _isFeature ? Icons.extension_outlined : Icons.category_outlined,
        emptyText: _isFeature ? 'Aucune option pour l\'instant.' : 'Aucun type de projet pour l\'instant.',
        itemBuilder: (context, item) => ListCardTile(
          onTap: () => _open(context, ref, item),
          leading: IconTile(_isFeature ? Icons.extension_outlined : Icons.category_outlined),
          title: item.name.display,
          subtitle: subtitleOf(item),
          badge: item.isActive ? null : const StatusBadge('Masqué', prominent: true),
        ),
      ),
    );
  }
}
