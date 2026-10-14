import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/surfaces.dart';
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
