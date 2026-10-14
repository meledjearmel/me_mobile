import 'package:flutter/foundation.dart';

import '../../../core/models/publication_status.dart';
import '../../../core/models/translated.dart';

/// D'où vient le prix « à partir de » d'une offre.
enum ServicePriceMode {
  estimator('estimator', 'Estimateur', 'Calculé depuis un type de projet de l\'estimateur.'),
  manual('manual', 'Manuel', 'Montants « à partir de » saisis par devise.'),
  quote('quote', 'Sur devis', 'Aucun prix affiché.');

  const ServicePriceMode(this.wireValue, this.label, this.hint);

  final String wireValue;
  final String label;
  final String hint;

  static ServicePriceMode fromWire(String? value) =>
      values.firstWhere((m) => m.wireValue == value, orElse: () => quote);
}

/// Offre de la page « Services » (`/v1/services`).
@immutable
class Service {
  const Service({
    required this.id,
    required this.slug,
    required this.title,
    required this.tagline,
    required this.description,
    required this.includes,
    required this.priceMode,
    required this.status,
    this.estimatorItemId,
    this.manualPrices = const {},
    this.projectIds = const [],
    this.draftedBy,
    this.sortOrder = 0,
  });

  factory Service.fromJson(Map<String, dynamic> json) => Service(
    id: json['id'] as int,
    slug: json['slug'] as String? ?? '',
    title: Translated.fromJson(json['title']),
    tagline: Translated.fromJson(json['tagline']),
    description: Translated.fromJson(json['description']),
    includes: Translated.fromJson(json['includes']),
    priceMode: ServicePriceMode.fromWire(json['price_mode'] as String?),
    estimatorItemId: json['estimator_item_id'] as int?,
    manualPrices: {
      if (json['manual_prices'] is Map)
        for (final MapEntry(:key, :value) in (json['manual_prices'] as Map).entries)
          if (value is int) key as String: value,
    },
    projectIds: [for (final id in json['project_ids'] as List<dynamic>? ?? const []) id as int],
    status: PublicationStatus.fromWire(json['status'] as String?),
    draftedBy: json['drafted_by'] as String?,
    sortOrder: json['sort_order'] as int? ?? 0,
  );

  final int id;

  /// Ancre de l'offre sur la page « Services » (`/services#slug`).
  final String slug;
  final Translated title;
  final Translated tagline;
  final Translated description;

  /// Ce qui est compris, un élément par ligne.
  final Translated includes;
  final ServicePriceMode priceMode;

  /// Type de projet de l'estimateur (mode `estimator`).
  final int? estimatorItemId;

  /// Prix « à partir de » par devise (mode `manual`).
  final Map<String, int> manualPrices;

  /// Projets qui illustrent l'offre ; leurs avis publiés s'affichent avec elle.
  final List<int> projectIds;
  final PublicationStatus status;
  final String? draftedBy;
  final int sortOrder;

  Service copyWith({PublicationStatus? status}) => Service(
    id: id,
    slug: slug,
    title: title,
    tagline: tagline,
    description: description,
    includes: includes,
    priceMode: priceMode,
    status: status ?? this.status,
    estimatorItemId: estimatorItemId,
    manualPrices: manualPrices,
    projectIds: projectIds,
    draftedBy: draftedBy,
    sortOrder: sortOrder,
  );
}

/// Texte d'une offre rédigé par l'IA, en français (`POST /v1/ai/draft-service`).
@immutable
class ServiceDraft {
  const ServiceDraft({required this.title, required this.slug, this.tagline, this.description, this.includes});

  factory ServiceDraft.fromJson(Map<String, dynamic> json) => ServiceDraft(
    title: json['title'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    tagline: json['tagline'] as String?,
    description: json['description'] as String?,
    includes: json['includes'] as String?,
  );

  final String title;
  final String slug;
  final String? tagline;
  final String? description;

  /// Une ligne par élément compris.
  final String? includes;
}
