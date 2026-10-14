import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/estimator.dart';
import '../data/estimator_repository.dart';
import 'estimator_grid_screen.dart';
import 'estimator_items_screen.dart';
import 'estimator_rates_screen.dart';
import 'estimator_settings_screen.dart';

/// Estimateur de projet (devis indicatif du site) : tarifs, grilles
/// tarifaires, types de projet, options, et grille complète proposée par l'IA.
class EstimatorScreen extends ConsumerWidget {
  const EstimatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final settings = ref.watch(estimatorSettingsProvider).value;
    final rates = ref.watch(estimatorRatesProvider).value;
    final items = ref.watch(estimatorItemsProvider).value;

    String? countOf(EstimatorItemKind kind) {
      if (items == null) {
        return null;
      }
      final ofKind = items.where((i) => i.kind == kind);
      final hidden = ofKind.where((i) => !i.isActive).length;
      return '${ofKind.length}${hidden > 0 ? ' dont $hidden masqué${hidden > 1 ? 's' : ''}' : ''}';
    }

    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => screen));

    Widget tile(IconData icon, String title, String? subtitle, Widget screen) =>
        ListCardTile(onTap: () => open(screen), leading: IconTile(icon), title: title, subtitle: subtitle ?? '…');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(),
      body: Builder(
        builder: (context) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(estimatorSettingsProvider)
              ..invalidate(estimatorRatesProvider)
              ..invalidate(estimatorItemsProvider);
            await ref.read(estimatorItemsProvider.future);
          },
          child: ListView(
            padding: pageInsets(context),
            children: [
              Text('Estimateur', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('Le devis indicatif proposé aux visiteurs du site.', style: muted),
              const SizedBox(height: 16),
              tile(
                Icons.tune_rounded,
                'Tarifs',
                settings == null
                    ? null
                    : [
                        describeRates(settings.hourlyRates).isEmpty
                            ? 'Aucun taux'
                            : describeRates(settings.hourlyRates),
                        'marge ${settings.riskPercent} %',
                        '${settings.hoursPerWeek} h/sem.',
                      ].join(' · '),
                const EstimatorSettingsScreen(),
              ),
              const SizedBox(height: 10),
              tile(
                Icons.request_quote_outlined,
                'Grilles tarifaires',
                rates == null ? null : '${rates.length}',
                const EstimatorRatesScreen(),
              ),
              const SizedBox(height: 10),
              tile(
                Icons.category_outlined,
                'Types de projet',
                countOf(EstimatorItemKind.projectType),
                const EstimatorItemsScreen(kind: EstimatorItemKind.projectType),
              ),
              const SizedBox(height: 10),
              tile(
                Icons.extension_outlined,
                'Options',
                countOf(EstimatorItemKind.feature),
                const EstimatorItemsScreen(kind: EstimatorItemKind.feature),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: () => open(const EstimatorGridScreen()),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Proposer une grille complète avec l\'IA'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
