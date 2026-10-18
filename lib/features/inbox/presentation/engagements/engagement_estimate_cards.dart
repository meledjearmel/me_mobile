import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../billing/data/commercial_document.dart';
import '../../../billing/presentation/document_detail_screen.dart';
import '../../data/engagement.dart';
import '../../data/engagement_repository.dart';

final _number = NumberFormat.decimalPattern('fr_FR');

String _range(int min, int max) => min == max ? _number.format(min) : '${_number.format(min)} – ${_number.format(max)}';

/// Estimation calculée par l'estimateur du site, telle que le visiteur l'a vue.
class EngagementEstimateCard extends StatelessWidget {
  const EngagementEstimateCard({super.key, required this.estimate});

  final EngagementEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Estimation envoyée', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_range(estimate.priceMin, estimate.priceMax)} ${estimate.currency}',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${billingLabel(estimate.billing)} · ${_range(estimate.hoursMin, estimate.hoursMax)} h · '
            '${_range(estimate.weeksMin, estimate.weeksMax)} semaine${estimate.weeksMax > 1 ? 's' : ''}',
            style: muted,
          ),
          const SizedBox(height: 12),
          Text(estimate.projectType, style: theme.textTheme.titleSmall),
          if (estimate.features.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final feature in estimate.features)
                  Chip(label: Text(feature), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Taux ${_number.format(estimate.hourlyRate)} ${estimate.currency}/h · marge pour imprévus ${estimate.riskPercent} %',
            style: muted,
          ),
          // Payé à chaque période, hors total du projet.
          if (estimate.recurring.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Ensuite, en continu', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final r in estimate.recurring)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${r.label} : ${_range(r.priceMin, r.priceMax)} ${estimate.currency} / ${r.periodUnit}'),
              ),
          ],
        ],
      ),
    );
  }
}

/// Analyse de l'IA pour chiffrer la demande, avec relance de l'analyse.
class EngagementAnalysisCard extends ConsumerStatefulWidget {
  const EngagementAnalysisCard({super.key, required this.engagement, required this.onUpdated});

  final Engagement engagement;
  final ValueChanged<Engagement> onUpdated;

  @override
  ConsumerState<EngagementAnalysisCard> createState() => _EngagementAnalysisCardState();
}

class _EngagementAnalysisCardState extends ConsumerState<EngagementAnalysisCard> {
  bool _analyzing = false;

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    try {
      widget.onUpdated(await ref.read(engagementRepositoryProvider).analyze(widget.engagement.id));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final analysis = widget.engagement.aiAnalysis;
    final analyzedAt = widget.engagement.aiAnalyzedAt;

    Widget list(String title, List<String> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: SelectableText(item)),
              ],
            ),
          ),
      ],
    );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 20, color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
              Expanded(child: Text('Analyse IA', style: theme.textTheme.titleSmall)),
              if (analyzedAt != null) Text(relativeDate(analyzedAt.toLocal()), style: muted),
            ],
          ),
          if (analysis == null) ...[
            const SizedBox(height: 8),
            Text(
              'Pas encore analysée : l\'IA relève les risques, les points flous et les questions à poser.',
              style: muted,
            ),
          ] else ...[
            const SizedBox(height: 12),
            SelectableText(analysis.summary),
            const SizedBox(height: 12),
            Text(
              [
                '${_range(analysis.hoursMin, analysis.hoursMax)} h réalistes',
                if (analysis.priceMin != null && analysis.priceMax != null)
                  '${_range(analysis.priceMin!, analysis.priceMax!)} ${analysis.currency ?? ''}'.trim(),
                billingLabel(analysis.billing).toLowerCase(),
              ].join(' · '),
              style: theme.textTheme.titleSmall,
            ),
            if (analysis.reasoning?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(analysis.reasoning!, style: muted),
            ],
            if (analysis.risks.isNotEmpty) list('Risques', analysis.risks),
            if (analysis.unclearPoints.isNotEmpty) list('Points flous', analysis.unclearPoints),
            if (analysis.questions.isNotEmpty) list('Questions à poser', analysis.questions),
          ],
          const SizedBox(height: 12),
          if (_analyzing) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text('Analyse en cours, cela peut prendre jusqu\'à une minute…', style: muted),
            const SizedBox(height: 8),
          ],
          FilledButton.tonalIcon(
            onPressed: _analyzing ? null : _analyze,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(analysis == null ? 'Analyser avec l\'IA' : 'Relancer l\'analyse'),
          ),
        ],
      ),
    );
  }
}

/// Issue de la demande : signée (montant hors taxes et devise) ou perdue. Une
/// issue range aussi la demande parmi les traitées et alimente les statistiques.
class EngagementOutcomeCard extends ConsumerStatefulWidget {
  const EngagementOutcomeCard({super.key, required this.engagement, required this.onUpdated});

  final Engagement engagement;
  final ValueChanged<Engagement> onUpdated;

  @override
  ConsumerState<EngagementOutcomeCard> createState() => _EngagementOutcomeCardState();
}

class _EngagementOutcomeCardState extends ConsumerState<EngagementOutcomeCard> {
  static const _currencies = ['XOF', 'EUR', 'USD', 'CHF'];

  bool _saving = false;

  Future<void> _save(EngagementOutcome? outcome, {int? amount, String? currency}) async {
    setState(() => _saving = true);
    try {
      widget.onUpdated(
        await ref
            .read(engagementRepositoryProvider)
            .setOutcome(widget.engagement.id, outcome, amount: amount, currency: currency),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Brouillon de devis qui reprend le client et les lignes de l'estimation, puis sa fiche.
  Future<void> _createQuote() async {
    setState(() => _saving = true);
    try {
      final document = await ref.read(commercialDocumentRepositoryProvider).fromEngagement(widget.engagement.id);
      if (mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (context) => DocumentDetailScreen(id: document.id)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Montant et devise signés ; préremplis depuis l'estimation (milieu de la fourchette).
  Future<void> _markWon() async {
    final engagement = widget.engagement;
    final estimate = engagement.estimate;
    final amount = TextEditingController(
      text:
          engagement.outcomeAmount?.toString() ??
          (estimate == null ? '' : '${((estimate.priceMin + estimate.priceMax) / 2).round()}'),
    );
    var currency = engagement.outcomeCurrency ?? estimate?.currency ?? 'XOF';
    if (!_currencies.contains(currency)) {
      currency = 'XOF';
    }
    final result = await showDialog<({int amount, String currency})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Demande gagnée'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Montant signé, hors taxes'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [for (final c in _currencies) ButtonSegment(value: c, label: Text(c))],
                selected: {currency},
                onSelectionChanged: (selection) => setDialogState(() => currency = selection.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(amount.text.replaceAll(RegExp(r'\s'), ''));
                if (value != null) {
                  Navigator.pop(context, (amount: value, currency: currency));
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    ).whenComplete(amount.dispose);
    if (result != null) {
      await _save(EngagementOutcome.won, amount: result.amount, currency: result.currency);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final engagement = widget.engagement;
    final outcome = engagement.outcome;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Issue', style: theme.textTheme.titleSmall)),
              if (engagement.outcomeAt != null) Text(relativeDate(engagement.outcomeAt!.toLocal()), style: muted),
            ],
          ),
          const SizedBox(height: 8),
          Text(switch (outcome) {
            EngagementOutcome.won when engagement.outcomeAmount != null =>
              'Gagnée : ${_number.format(engagement.outcomeAmount)} ${engagement.outcomeCurrency ?? ''} HT',
            EngagementOutcome.won => 'Gagnée',
            EngagementOutcome.lost => 'Perdue',
            null => 'Pas encore décidée.',
          }, style: outcome == null ? muted : theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _saving ? null : _markWon,
                icon: const Icon(Icons.emoji_events_outlined, size: 18),
                label: Text(outcome == EngagementOutcome.won ? 'Modifier le montant' : 'Gagnée'),
              ),
              if (outcome != EngagementOutcome.lost)
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _save(EngagementOutcome.lost),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Perdue'),
                ),
              if (outcome != null)
                TextButton(onPressed: _saving ? null : () => _save(null), child: const Text('Effacer l\'issue')),
              if (outcome != EngagementOutcome.lost)
                TextButton.icon(
                  onPressed: _saving ? null : _createQuote,
                  icon: const Icon(Icons.request_quote_outlined, size: 18),
                  label: const Text('Créer un devis'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
