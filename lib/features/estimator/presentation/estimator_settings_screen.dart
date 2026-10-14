import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/estimator.dart';
import '../data/estimator_repository.dart';
import 'widgets/hourly_rates_field.dart';

/// Réglages globaux de l'estimateur : taux horaire par devise, marge pour
/// imprévus et heures facturables par semaine.
class EstimatorSettingsScreen extends ConsumerStatefulWidget {
  const EstimatorSettingsScreen({super.key});

  @override
  ConsumerState<EstimatorSettingsScreen> createState() => _EstimatorSettingsScreenState();
}

class _EstimatorSettingsScreenState extends ConsumerState<EstimatorSettingsScreen> {
  late Future<void> _future = _load();

  HourlyRates _rates = const {};
  final _risk = TextEditingController();
  final _hoursPerWeek = TextEditingController();
  bool _saving = false;
  String? _error;
  ValidationException? _validation;

  Future<void> _load() async {
    final settings = await ref.read(estimatorRepositoryProvider).settings();
    _rates = settings.hourlyRates;
    _risk.text = '${settings.riskPercent}';
    _hoursPerWeek.text = '${settings.hoursPerWeek}';
  }

  @override
  void dispose() {
    _risk.dispose();
    _hoursPerWeek.dispose();
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
          .saveSettings(
            EstimatorSettings(
              hourlyRates: _rates,
              riskPercent: int.tryParse(_risk.text) ?? 0,
              hoursPerWeek: int.tryParse(_hoursPerWeek.text) ?? 0,
            ),
          );
      ref.invalidate(estimatorSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réglages enregistrés.')));
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final v = _validation;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: const GlassAppBar(),
      bottomNavigationBar: FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && !snapshot.hasError
            ? SaveBar(onPressed: _save, saving: _saving)
            : const SizedBox.shrink(),
      ),
      body: FutureBuilder<void>(
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
                  FilledButton(onPressed: () => setState(() => _future = _load()), child: const Text('Réessayer')),
                ],
              ),
            );
          }
          return ListView(
            padding: pageInsets(context),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: FormHeader(title: 'Tarifs', subtitle: 'Valeurs par défaut de l\'estimateur du site'),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
              SurfaceCard(
                radius: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HourlyRatesField(
                      label: 'Taux horaire global',
                      emptyHint: 'Une devise sans taux n\'est pas proposée au visiteur.',
                      value: _rates,
                      errorFor: (currency) => v?.errorFor('estimator_hourly_rates.$currency'),
                      onChanged: (rates) => _rates = rates,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _risk,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Marge pour imprévus',
                        suffixText: '%',
                        helperText: 'Ajoutée aux heures estimées (0 à 200).',
                        errorText: v?.errorFor('estimator_risk_percent'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hoursPerWeek,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Heures facturables par semaine',
                        suffixText: 'h',
                        helperText: 'Sert à estimer le délai (1 à 80).',
                        errorText: v?.errorFor('estimator_hours_per_week'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
