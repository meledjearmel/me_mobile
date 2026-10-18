import 'package:flutter/foundation.dart';

import '../../../core/models/translated.dart';

/// Devises de l'estimateur (`EstimatorItem::CURRENCIES`).
const estimatorCurrencies = ['XOF', 'EUR', 'USD', 'CHF'];

/// Taux horaire par devise ; une devise absente (ou à 0) n'a pas de taux à ce niveau.
typedef HourlyRates = Map<String, int>;

HourlyRates hourlyRatesFromJson(Object? json) => {
  if (json is Map)
    for (final MapEntry(:key, :value) in json.entries)
      if (value is int && value > 0) key as String: value,
};

/// Les quatre devises, une absente envoyée à `null`, comme l'attend l'API.
Map<String, int?> hourlyRatesToJson(HourlyRates rates) => {
  for (final currency in estimatorCurrencies) currency: rates[currency],
};

/// « 25 000 XOF · 40 EUR » ; vide si aucun taux.
String describeRates(HourlyRates rates) => [
  for (final currency in estimatorCurrencies)
    if (rates[currency] != null) '${rates[currency]} $currency',
].join(' · ');

enum EstimatorItemKind {
  projectType('project_type', 'Type de projet'),
  feature('feature', 'Option');

  const EstimatorItemKind(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static EstimatorItemKind fromWire(String? value) =>
      values.firstWhere((k) => k.wireValue == value, orElse: () => feature);
}

/// Type de projet : forfait estimé ou facturé à l'heure.
enum EstimatorBilling {
  fixed('fixed', 'Forfait'),
  hourly('hourly', 'À l\'heure');

  const EstimatorBilling(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static EstimatorBilling? fromWire(String? value) => values.where((b) => b.wireValue == value).firstOrNull;
}

/// Option : des heures, un pourcentage des heures du projet, ou un service
/// récurrent (heures par mois, payé à chaque période).
enum EstimatorPricing {
  hours('hours', 'En heures'),
  percent('percent', 'En pourcentage'),
  recurring('recurring', 'Récurrent');

  const EstimatorPricing(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static EstimatorPricing? fromWire(String? value) => values.where((p) => p.wireValue == value).firstOrNull;
}

/// Période de paiement d'une option récurrente.
enum EstimatorPeriod {
  monthly('monthly', 'Mensuel', 'mois'),
  quarterly('quarterly', 'Trimestriel', 'trimestre'),
  semiannual('semiannual', 'Semestriel', 'semestre'),
  yearly('yearly', 'Annuel', 'an');

  const EstimatorPeriod(this.wireValue, this.label, this.unitLabel);

  final String wireValue;
  final String label;

  /// « / mois », « / an »…
  final String unitLabel;

  static EstimatorPeriod? fromWire(String? value) => values.where((p) => p.wireValue == value).firstOrNull;
}

/// Périodes proposées et leur remise en % ; une période absente n'est pas proposée.
typedef EstimatorPeriods = Map<EstimatorPeriod, int>;

EstimatorPeriods? estimatorPeriodsFromJson(Object? json) {
  if (json is! Map) {
    return null;
  }
  return {
    for (final period in EstimatorPeriod.values)
      if (json[period.wireValue] is num) period: (json[period.wireValue] as num).toInt(),
  };
}

Map<String, int> estimatorPeriodsToJson(EstimatorPeriods periods) => {
  for (final period in EstimatorPeriod.values)
    if (periods.containsKey(period)) period.wireValue: periods[period]!,
};

/// Réglages globaux (`/v1/estimator-settings`).
@immutable
class EstimatorSettings {
  const EstimatorSettings({required this.hourlyRates, required this.riskPercent, required this.hoursPerWeek});

  factory EstimatorSettings.fromJson(Map<String, dynamic> json) => EstimatorSettings(
    hourlyRates: hourlyRatesFromJson(json['estimator_hourly_rates']),
    riskPercent: json['estimator_risk_percent'] as int? ?? 0,
    hoursPerWeek: json['estimator_hours_per_week'] as int? ?? 0,
  );

  /// Taux global ; une devise sans taux n'est pas proposée au visiteur.
  final HourlyRates hourlyRates;

  /// Marge pour imprévus ajoutée aux heures, en %.
  final int riskPercent;

  /// Heures facturables par semaine, pour le délai.
  final int hoursPerWeek;

  Map<String, dynamic> toJson() => {
    'estimator_hourly_rates': hourlyRatesToJson(hourlyRates),
    'estimator_risk_percent': riskPercent,
    'estimator_hours_per_week': hoursPerWeek,
  };
}

/// Grille tarifaire nommée (`/v1/estimator-rates`).
@immutable
class EstimatorRate {
  const EstimatorRate({
    required this.id,
    required this.name,
    required this.hourlyRates,
    required this.sortOrder,
    this.itemsCount = 0,
  });

  factory EstimatorRate.fromJson(Map<String, dynamic> json) => EstimatorRate(
    id: json['id'] as int,
    name: Translated.fromJson(json['name']),
    hourlyRates: hourlyRatesFromJson(json['hourly_rates']),
    sortOrder: json['sort_order'] as int? ?? 0,
    itemsCount: json['items_count'] as int? ?? 0,
  );

  final int id;
  final Translated name;

  /// Une devise absente suit le taux global.
  final HourlyRates hourlyRates;
  final int sortOrder;

  /// Éléments rattachés à cette grille.
  final int itemsCount;
}

/// Type de projet ou option (`/v1/estimator-items`).
@immutable
class EstimatorItem {
  const EstimatorItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.description,
    required this.hoursMin,
    required this.hoursMax,
    this.pricing,
    this.percent,
    this.periods,
    this.billing,
    this.projectTypeIds = const [],
    this.rateId,
    this.hourlyRates = const {},
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory EstimatorItem.fromJson(Map<String, dynamic> json) => EstimatorItem(
    id: json['id'] as int,
    kind: EstimatorItemKind.fromWire(json['kind'] as String?),
    name: Translated.fromJson(json['name']),
    description: Translated.fromJson(json['description']),
    hoursMin: json['hours_min'] as int? ?? 0,
    hoursMax: json['hours_max'] as int? ?? 0,
    pricing: EstimatorPricing.fromWire(json['pricing'] as String?),
    percent: json['percent'] as int?,
    periods: estimatorPeriodsFromJson(json['periods']),
    billing: EstimatorBilling.fromWire(json['billing'] as String?),
    projectTypeIds: [for (final id in json['project_type_ids'] as List<dynamic>? ?? const []) id as int],
    rateId: json['estimator_rate_id'] as int?,
    hourlyRates: hourlyRatesFromJson(json['hourly_rates']),
    isActive: json['is_active'] as bool? ?? true,
    sortOrder: json['sort_order'] as int? ?? 0,
  );

  final int id;
  final EstimatorItemKind kind;
  final Translated name;
  final Translated description;

  /// Heures hors marge pour imprévus ; 0 pour une option en pourcentage.
  final int hoursMin;
  final int hoursMax;

  /// Options seulement.
  final EstimatorPricing? pricing;
  final int? percent;

  /// Options récurrentes seulement ; `null` sinon.
  final EstimatorPeriods? periods;

  /// Types de projet seulement.
  final EstimatorBilling? billing;

  /// Option réservée à ces types de projet ; vide : proposée pour tous.
  final List<int> projectTypeIds;

  /// Grille tarifaire suivie ; `null` : taux propres ou taux global.
  final int? rateId;

  /// Taux propres, prioritaires sur la grille puis sur le taux global.
  final HourlyRates hourlyRates;
  final bool isActive;
  final int sortOrder;

  bool get isPercent => kind == EstimatorItemKind.feature && pricing == EstimatorPricing.percent;
  bool get isRecurring => kind == EstimatorItemKind.feature && pricing == EstimatorPricing.recurring;

  /// « 20 – 40 h », « + 15 % », « 8 h » ou « 2 – 4 h / mois ».
  String get effortLabel {
    if (isPercent) {
      return '+ ${percent ?? 0} %';
    }
    final hours = hoursMin == hoursMax ? '$hoursMin h' : '$hoursMin – $hoursMax h';
    return isRecurring ? '$hours / mois' : hours;
  }
}

/// Élément proposé par l'IA (`POST /v1/ai/suggest-estimator-item`). Rien n'est enregistré.
@immutable
class EstimatorItemSuggestion {
  const EstimatorItemSuggestion({
    required this.name,
    required this.description,
    required this.hoursMin,
    required this.hoursMax,
    this.pricing,
    this.percent,
    this.reasoning,
  });

  factory EstimatorItemSuggestion.fromJson(Map<String, dynamic> json) => EstimatorItemSuggestion(
    name: Translated.fromJson(json['name']),
    description: Translated.fromJson(json['description']),
    hoursMin: json['hours_min'] as int? ?? 0,
    hoursMax: json['hours_max'] as int? ?? 0,
    pricing: EstimatorPricing.fromWire(json['pricing'] as String?),
    percent: json['percent'] as int?,
    reasoning: json['reasoning'] as String?,
  );

  final Translated name;
  final Translated description;
  final int hoursMin;
  final int hoursMax;
  final EstimatorPricing? pricing;
  final int? percent;
  final String? reasoning;
}

/// Élément d'une grille proposée, lu pour l'aperçu.
@immutable
class ProposedItem {
  const ProposedItem(this.raw);

  /// Tel que renvoyé par l'IA, pour être renvoyé sans retouche à `/estimator-configuration`.
  final Map<String, dynamic> raw;

  int? get id => raw['id'] as int?;
  String? get ref => raw['ref'] as String?;
  EstimatorItemKind get kind => EstimatorItemKind.fromWire(raw['kind'] as String?);
  String get nameFr => raw['name_fr'] as String? ?? '';
  String get nameEn => raw['name_en'] as String? ?? '';
  String? get descriptionFr => raw['description_fr'] as String?;
  int get hoursMin => raw['hours_min'] as int? ?? 0;
  int get hoursMax => raw['hours_max'] as int? ?? 0;
  EstimatorPricing? get pricing => EstimatorPricing.fromWire(raw['pricing'] as String?);
  int? get percent => raw['percent'] as int?;
  EstimatorBilling? get billing => EstimatorBilling.fromWire(raw['billing'] as String?);

  /// Identifiants de types existants, ou `ref` de types de la proposition.
  List<Object> get projectTypes => [for (final t in raw['project_types'] as List<dynamic>? ?? const []) t as Object];

  bool get isUpdate => id != null;

  String get effortLabel {
    if (pricing == EstimatorPricing.percent) {
      return '+ ${percent ?? 0} %';
    }
    final hours = hoursMin == hoursMax ? '$hoursMin h' : '$hoursMin – $hoursMax h';
    return pricing == EstimatorPricing.recurring ? '$hours / mois' : hours;
  }
}

/// Grille complète proposée par l'IA (`POST /v1/ai/propose-estimator-grid`).
@immutable
class EstimatorGridProposal {
  const EstimatorGridProposal({this.settings, this.items = const [], this.rates = const [], this.reasoning});

  factory EstimatorGridProposal.fromJson(Map<String, dynamic> json) => EstimatorGridProposal(
    settings: json['settings'] as Map<String, dynamic>?,
    items: [
      for (final item in json['items'] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic>) ProposedItem(item),
    ],
    rates: [
      for (final rate in json['rates'] as List<dynamic>? ?? const [])
        if (rate is Map<String, dynamic>) rate,
    ],
    reasoning: json['reasoning'] as String?,
  );

  /// `hourly_rates`, `risk_percent`, `hours_per_week` ; `null` : réglages inchangés.
  final Map<String, dynamic>? settings;
  final List<ProposedItem> items;

  /// Grilles tarifaires à créer ou modifier (`name_fr`, `name_en`, `hourly_rates`).
  final List<Map<String, dynamic>> rates;
  final String? reasoning;

  HourlyRates get proposedRates => hourlyRatesFromJson(settings?['hourly_rates']);
  int? get proposedRiskPercent => settings?['risk_percent'] as int?;
  int? get proposedHoursPerWeek => settings?['hours_per_week'] as int?;

  /// Corps de `POST /v1/estimator-configuration` : la proposition telle quelle.
  Map<String, dynamic> toConfiguration() => {
    'settings': ?settings,
    if (rates.isNotEmpty) 'rates': rates,
    'items': [for (final item in items) item.raw],
  };
}

/// Ce que `POST /v1/estimator-configuration` a fait.
@immutable
class EstimatorConfigurationResult {
  const EstimatorConfigurationResult({
    required this.settingsUpdated,
    required this.rates,
    required this.created,
    required this.updated,
  });

  factory EstimatorConfigurationResult.fromJson(Map<String, dynamic> json) {
    List<String> names(String key) => [
      for (final entry in json[key] as List<dynamic>? ?? const [])
        if (entry is Map<String, dynamic>) entry['name'] as String? ?? '',
    ];
    return EstimatorConfigurationResult(
      settingsUpdated: json['settings_updated'] as bool? ?? false,
      rates: names('rates'),
      created: names('created'),
      updated: names('updated'),
    );
  }

  final bool settingsUpdated;
  final List<String> rates;
  final List<String> created;
  final List<String> updated;

  String get summary => [
    if (settingsUpdated) 'réglages mis à jour',
    if (rates.isNotEmpty)
      '${rates.length} grille${rates.length > 1 ? 's' : ''} tarifaire${rates.length > 1 ? 's' : ''}',
    if (created.isNotEmpty)
      '${created.length} élément${created.length > 1 ? 's' : ''} créé${created.length > 1 ? 's' : ''}',
    if (updated.isNotEmpty) '${updated.length} modifié${updated.length > 1 ? 's' : ''}',
  ].join(', ');
}
