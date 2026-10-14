import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/translated.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../../shared/widgets/translated_field.dart';
import '../data/estimator.dart';
import '../data/estimator_repository.dart';
import 'widgets/estimator_list_body.dart';
import 'widgets/hourly_rates_field.dart';

/// Grilles tarifaires : des taux horaires nommés, que les éléments peuvent suivre.
class EstimatorRatesScreen extends ConsumerWidget {
  const EstimatorRatesScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, [EstimatorRate? rate]) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (context) => EstimatorRateFormScreen(rate: rate)));
    if (changed == true) {
      ref
        ..invalidate(estimatorRatesProvider)
        ..invalidate(estimatorItemsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(),
      floatingActionButton: GlassFab(
        icon: Icons.add_rounded,
        tooltip: 'Ajouter',
        onPressed: () => _open(context, ref),
        bottom: MediaQuery.paddingOf(context).bottom,
      ),
      body: EstimatorListBody<EstimatorRate>(
        title: 'Grilles tarifaires',
        subtitle: 'Un élément suit ses propres taux, sinon sa grille, sinon le taux global.',
        value: ref.watch(estimatorRatesProvider),
        onRefresh: () => ref.refresh(estimatorRatesProvider.future),
        emptyIcon: Icons.request_quote_outlined,
        emptyText: 'Aucune grille : tous les éléments suivent le taux global.',
        itemBuilder: (context, rate) => ListCardTile(
          onTap: () => _open(context, ref, rate),
          leading: const IconTile(Icons.request_quote_outlined),
          title: rate.name.display,
          subtitle: describeRates(rate.hourlyRates).isEmpty
              ? 'Taux global pour toutes les devises'
              : describeRates(rate.hourlyRates),
          meta: '${rate.itemsCount} élément${rate.itemsCount > 1 ? 's' : ''}',
          badge: null,
        ),
        footer: Text(
          'Une devise laissée vide dans une grille suit le taux global.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
      ),
    );
  }
}

/// Création ou modification d'une grille tarifaire. Renvoie `true` si elle a changé.
class EstimatorRateFormScreen extends ConsumerStatefulWidget {
  const EstimatorRateFormScreen({super.key, this.rate});

  final EstimatorRate? rate;

  @override
  ConsumerState<EstimatorRateFormScreen> createState() => _EstimatorRateFormScreenState();
}

class _EstimatorRateFormScreenState extends ConsumerState<EstimatorRateFormScreen> {
  late Translated _name = widget.rate?.name ?? const Translated();
  late HourlyRates _rates = widget.rate?.hourlyRates ?? const {};
  late final _sortOrder = TextEditingController(text: '${widget.rate?.sortOrder ?? 0}');
  bool _saving = false;
  bool _deleting = false;
  String? _error;
  ValidationException? _validation;

  @override
  void dispose() {
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      await ref
          .read(estimatorRepositoryProvider)
          .saveRate(
            id: widget.rate?.id,
            name: _name,
            hourlyRates: _rates,
            sortOrder: int.tryParse(_sortOrder.text) ?? 0,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ValidationException catch (e) {
      setState(() => _validation = e);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final rate = widget.rate!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer la grille « ${rate.name.display} » ?'),
        content: Text(
          rate.itemsCount == 0
              ? 'Aucun élément ne la suit.'
              : '${rate.itemsCount} élément${rate.itemsCount > 1 ? 's' : ''} la suive${rate.itemsCount > 1 ? 'nt' : ''} : '
                    'ils reviendront à leurs propres taux ou au taux global.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await ref.read(estimatorRepositoryProvider).deleteRate(rate.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _validation;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        actions: [
          if (widget.rate != null)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: _deleting ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar: SaveBar(onPressed: _save, saving: _saving),
      body: ListView(
        padding: pageInsets(context),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FormHeader(title: widget.rate == null ? 'Nouvelle grille' : 'Modifier la grille'),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
          SurfaceCard(
            radius: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TranslatedField(
                  label: 'Nom',
                  value: _name,
                  maxLength: 255,
                  errorFr: v?.errorFor('name.fr'),
                  errorEn: v?.errorFor('name.en'),
                  onChanged: (value) => setState(() => _name = value),
                ),
                const SizedBox(height: 16),
                HourlyRatesField(
                  value: _rates,
                  emptyHint: 'Vide : la devise suit le taux global.',
                  errorFor: (currency) => v?.errorFor('hourly_rates.$currency'),
                  onChanged: (rates) => _rates = rates,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sortOrder,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Ordre d\'affichage', errorText: v?.errorFor('sort_order')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
