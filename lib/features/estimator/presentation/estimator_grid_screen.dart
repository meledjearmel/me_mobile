import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/estimator.dart';
import '../data/estimator_repository.dart';

/// L'IA propose une grille complète d'après la description de l'activité ;
/// aperçu, puis application d'un coup après confirmation. Renvoie `true` si
/// la grille a été appliquée.
class EstimatorGridScreen extends ConsumerStatefulWidget {
  const EstimatorGridScreen({super.key});

  @override
  ConsumerState<EstimatorGridScreen> createState() => _EstimatorGridScreenState();
}

class _EstimatorGridScreenState extends ConsumerState<EstimatorGridScreen> {
  final _brief = TextEditingController();
  EstimatorGridProposal? _proposal;
  bool _generating = false;
  bool _applying = false;
  String? _error;

  @override
  void dispose() {
    _brief.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final proposal = await ref.read(estimatorRepositoryProvider).proposeGrid(_brief.text);
      setState(() => _proposal = proposal);
    } on ValidationException catch (e) {
      setState(() => _error = e.errors.values.expand((m) => m).firstOrNull ?? e.message);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _apply() async {
    final proposal = _proposal!;
    final creates = proposal.items.where((i) => !i.isUpdate).length;
    final updates = proposal.items.length - creates;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appliquer cette grille ?'),
        content: Text(
          [
            if (proposal.settings != null) 'Les réglages seront remplacés par ceux proposés.',
            if (proposal.rates.isNotEmpty) '${proposal.rates.length} grille(s) tarifaire(s) créée(s) ou modifiée(s).',
            if (creates > 0) '$creates élément(s) créé(s), masqués jusqu\'à ce que tu les actives.',
            if (updates > 0) '$updates élément(s) existant(s) modifié(s).',
            'Tout est appliqué d\'un coup.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Appliquer')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      final result = await ref.read(estimatorRepositoryProvider).applyConfiguration(proposal);
      ref
        ..invalidate(estimatorSettingsProvider)
        ..invalidate(estimatorRatesProvider)
        ..invalidate(estimatorItemsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.summary.isEmpty ? 'Grille appliquée.' : 'Grille appliquée : ${result.summary}.'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on ValidationException catch (e) {
      setState(() => _error = e.errors.values.expand((m) => m).firstOrNull ?? e.message);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final proposal = _proposal;

    return PopScope(
      canPop: !_generating && !_applying,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: const GlassAppBar(),
        bottomNavigationBar: proposal == null
            ? null
            : SaveBar(onPressed: _apply, saving: _applying, label: 'Appliquer la grille'),
        body: ListView(
          padding: pageInsets(context),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: FormHeader(
                title: 'Proposer une grille',
                subtitle: 'L\'IA propose les types de projet, les options et les réglages. Rien n\'est appliqué sans ton accord.',
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
            SurfaceCard(
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _brief,
                    enabled: !_generating && !_applying,
                    minLines: 5,
                    maxLines: 12,
                    maxLength: 5000,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Ton activité et tes consignes',
                      hintText: 'Sites et apps mobiles pour PME à Abidjan, forfaits pour les sites, à l\'heure pour la maintenance…',
                      helperText: '20 caractères au moins.',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_generating) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text('Proposition en cours, cela peut prendre jusqu\'à une minute…', style: muted),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: _generating || _applying || _brief.text.trim().length < 20 ? null : _generate,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(proposal == null ? 'Proposer' : 'Proposer à nouveau'),
                  ),
                ],
              ),
            ),
            if (proposal != null) ..._preview(context, proposal),
          ],
        ),
      ),
    );
  }

  List<Widget> _preview(BuildContext context, EstimatorGridProposal proposal) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final types = proposal.items.where((i) => i.kind == EstimatorItemKind.projectType).toList();
    final features = proposal.items.where((i) => i.kind == EstimatorItemKind.feature).toList();
    final existing = ref.watch(estimatorItemsProvider).value ?? const <EstimatorItem>[];

    /// Nom d'un type visé par une option : `ref` d'un type proposé ou identifiant existant.
    String typeName(Object target) =>
        types.where((t) => t.ref == target).firstOrNull?.nameFr ??
        existing.where((e) => e.id == target).firstOrNull?.name.display ??
        '$target';

    Widget itemTile(ProposedItem item) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nameFr, style: theme.textTheme.titleSmall),
                Text(
                  [
                    item.effortLabel,
                    if (item.billing != null) item.billing!.label,
                    if (item.kind == EstimatorItemKind.feature)
                      item.projectTypes.isEmpty ? 'Tous les types' : item.projectTypes.map(typeName).join(', '),
                  ].join(' · '),
                  style: muted,
                ),
                if (item.descriptionFr?.isNotEmpty == true) Text(item.descriptionFr!, style: muted),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(item.isUpdate ? 'Modifié' : 'Nouveau', color: item.isUpdate ? null : theme.colorScheme.primary),
        ],
      ),
    );

    return [
      if (proposal.reasoning?.isNotEmpty == true) ...[
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 20, color: theme.colorScheme.tertiary),
              const SizedBox(width: 10),
              Expanded(child: Text(proposal.reasoning!, style: muted)),
            ],
          ),
        ),
      ],
      if (proposal.settings != null) ...[
        const SizedBox(height: 12),
        FormSection(
          title: 'Réglages proposés',
          children: [
            if (proposal.proposedRates.isNotEmpty) Text('Taux : ${describeRates(proposal.proposedRates)} (par heure)'),
            if (proposal.proposedRiskPercent != null) Text('Marge pour imprévus : ${proposal.proposedRiskPercent} %'),
            if (proposal.proposedHoursPerWeek != null) Text('Heures par semaine : ${proposal.proposedHoursPerWeek} h'),
          ],
        ),
      ],
      if (proposal.rates.isNotEmpty) ...[
        const SizedBox(height: 12),
        FormSection(
          title: 'Grilles tarifaires',
          summary: '${proposal.rates.length}',
          children: [
            for (final rate in proposal.rates)
              Text('${rate['name_fr'] ?? 'Grille'} · ${describeRates(hourlyRatesFromJson(rate['hourly_rates']))}'),
          ],
        ),
      ],
      const SizedBox(height: 12),
      FormSection(
        title: 'Types de projet',
        summary: '${types.length}',
        children: [if (types.isEmpty) Text('Aucun.', style: muted) else ...types.map(itemTile)],
      ),
      const SizedBox(height: 12),
      FormSection(
        title: 'Options',
        summary: '${features.length}',
        children: [if (features.isEmpty) Text('Aucune.', style: muted) else ...features.map(itemTile)],
      ),
      const SizedBox(height: 8),
      Text('Les éléments créés restent masqués au visiteur jusqu\'à ce que tu les actives.', style: muted),
    ];
  }
}
