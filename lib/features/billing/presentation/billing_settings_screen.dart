import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../data/billing_settings.dart';

/// Réglages de facturation : émetteur, TVA, valeurs par défaut et relances.
/// Le design des PDF (modèles de documents) se règle dans l'admin web.
class BillingSettingsScreen extends ConsumerStatefulWidget {
  const BillingSettingsScreen({super.key});

  @override
  ConsumerState<BillingSettingsScreen> createState() => _BillingSettingsScreenState();
}

class _BillingSettingsScreenState extends ConsumerState<BillingSettingsScreen> {
  late Future<void> _future = _load();

  final _controllers = {
    for (final key in [...billingTextFields, ...billingNumberFields.keys]) key: TextEditingController(),
  };
  bool _saving = false;
  String? _error;
  ValidationException? _validation;

  Future<void> _load() async {
    final settings = await ref.read(billingSettingsRepositoryProvider).get();
    for (final MapEntry(:key, :value) in settings.texts.entries) {
      _controllers[key]!.text = value;
    }
    for (final MapEntry(:key, :value) in settings.numbers.entries) {
      _controllers[key]!.text = '$value';
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
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
          .read(billingSettingsRepositoryProvider)
          .save(
            BillingSettings(
              texts: {for (final key in billingTextFields) key: _controllers[key]!.text},
              numbers: {
                for (final MapEntry(:key, value: fallback) in billingNumberFields.entries)
                  key: int.tryParse(_controllers[key]!.text) ?? fallback,
              },
            ),
          );
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

  Widget _text(String key, String label, {String? helper, int maxLines = 1, TextInputType? keyboard}) => TextField(
    controller: _controllers[key],
    minLines: maxLines > 1 ? 2 : 1,
    maxLines: maxLines,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 2,
      alignLabelWithHint: maxLines > 1,
      errorText: _validation?.errorFor(key),
    ),
  );

  Widget _number(String key, String label, {String? suffix, String? helper}) => TextField(
    controller: _controllers[key],
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      helperText: helper,
      helperMaxLines: 2,
      errorText: _validation?.errorFor(key),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
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
                child: FormHeader(
                  title: 'Facturation',
                  subtitle:
                      'Repris sur chaque devis, proforma et facture. Le design des PDF se règle dans l\'admin web.',
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
              FormSection(
                title: 'Émetteur',
                hasError: billingTextFields.take(6).any((k) => v?.errorFor(k) != null),
                children: [
                  _text('billing_business_name', 'Nom ou raison sociale'),
                  _text('billing_legal_form', 'Statut', helper: 'Ex. entreprise individuelle, auto-entrepreneur…'),
                  _text('billing_address', 'Adresse', maxLines: 4),
                  _text('billing_registration_number', 'Numéro d\'entreprise', helper: 'RCCM, SIRET, IDE…'),
                  _text('billing_iban', 'IBAN'),
                  _text('billing_bank', 'Banque'),
                ],
              ),
              const SizedBox(height: 12),
              FormSection(
                title: 'Mentions',
                hasError: ['billing_vat_mention', 'billing_payment_terms'].any((k) => v?.errorFor(k) != null),
                children: [
                  _text('billing_vat_mention', 'Mention de TVA', helper: 'Vide : « TVA non applicable ».'),
                  _text('billing_payment_terms', 'Conditions de paiement par défaut', maxLines: 5),
                ],
              ),
              const SizedBox(height: 12),
              FormSection(
                title: 'Valeurs par défaut',
                hasError: [
                  'billing_quote_validity_days',
                  'billing_invoice_due_days',
                  'billing_deposit_percent',
                ].any((k) => v?.errorFor(k) != null),
                children: [
                  _number('billing_quote_validity_days', 'Validité d\'un devis', suffix: 'jours'),
                  _number('billing_invoice_due_days', 'Échéance d\'une facture', suffix: 'jours'),
                  _number('billing_deposit_percent', 'Acompte', suffix: '%'),
                  Text('Modifiables document par document.', style: muted),
                ],
              ),
              const SizedBox(height: 12),
              FormSection(
                title: 'Relances',
                hasError: [
                  'billing_quote_reminder_days',
                  'billing_invoice_reminder_days',
                  'billing_max_reminders',
                ].any((k) => v?.errorFor(k) != null),
                children: [
                  _number('billing_quote_reminder_days', 'Devis sans réponse depuis', suffix: 'jours'),
                  _number('billing_invoice_reminder_days', 'Facture en retard depuis', suffix: 'jours'),
                  _number(
                    'billing_max_reminders',
                    'Relances au plus par document',
                    helper: '0 : aucune relance suggérée.',
                  ),
                  Text(
                    'Une relance n\'est jamais envoyée seule : l\'app la suggère, tu la relis et la confirmes.',
                    style: muted,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
