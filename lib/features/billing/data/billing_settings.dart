import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';

/// Champs texte des réglages de facturation (vides : `null`).
const billingTextFields = [
  'billing_business_name',
  'billing_legal_form',
  'billing_address',
  'billing_registration_number',
  'billing_iban',
  'billing_bank',
  'billing_vat_mention',
  'billing_payment_terms',
];

/// Champs numériques, avec leur valeur par défaut si l'API n'en renvoie pas.
const billingNumberFields = {
  'billing_quote_validity_days': 30,
  'billing_invoice_due_days': 30,
  'billing_deposit_percent': 0,
  'billing_quote_reminder_days': 7,
  'billing_invoice_reminder_days': 7,
  'billing_max_reminders': 2,
};

/// Réglages de facturation (`/v1/billing-settings`) : l'émetteur des documents,
/// la mention de TVA, les valeurs par défaut d'un document et les relances.
class BillingSettings {
  const BillingSettings({required this.texts, required this.numbers});

  factory BillingSettings.fromJson(Map<String, dynamic> json) => BillingSettings(
    texts: {for (final key in billingTextFields) key: json[key] as String? ?? ''},
    numbers: {
      for (final MapEntry(:key, value: fallback) in billingNumberFields.entries) key: json[key] as int? ?? fallback,
    },
  );

  final Map<String, String> texts;
  final Map<String, int> numbers;

  Map<String, dynamic> toJson() => {
    for (final MapEntry(:key, :value) in texts.entries) key: value.trim().isEmpty ? null : value.trim(),
    ...numbers,
  };
}

final billingSettingsRepositoryProvider = Provider<BillingSettingsRepository>(
  (ref) => BillingSettingsRepository(ref.watch(apiClientProvider)),
);

class BillingSettingsRepository {
  const BillingSettingsRepository(this._api);

  final ApiClient _api;

  Future<BillingSettings> get() async =>
      BillingSettings.fromJson(await _api.get('/v1/billing-settings') as Map<String, dynamic>);

  Future<BillingSettings> save(BillingSettings settings) async =>
      BillingSettings.fromJson(await _api.put('/v1/billing-settings', data: settings.toJson()) as Map<String, dynamic>);
}
