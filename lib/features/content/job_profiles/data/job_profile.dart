import 'package:flutter/foundation.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';

@immutable
class JobProfile {
  const JobProfile({
    required this.id,
    required this.key,
    required this.label,
    required this.description,
    required this.heroTitle,
    required this.heroWords,
    required this.cvDescription,
    required this.sortOrder,
    required this.status,
  });

  factory JobProfile.fromJson(Map<String, dynamic> json) => JobProfile(
        id: json['id'] as int,
        key: json['key'] as String,
        label: Translated.fromJson(json['label']),
        description: Translated.fromJson(json['description']),
        heroTitle: Translated.fromJson(json['hero_title']),
        heroWords: Translated.fromJson(json['hero_words']),
        cvDescription: Translated.fromJson(json['cv_description']),
        sortOrder: json['sort_order'] as int? ?? 0,
        status: PublicationStatus.fromWire(json['status'] as String?),
      );

  final int id;
  final String key;
  final Translated label;
  final Translated description;

  /// 15 caractères maximum (§4.3).
  final Translated heroTitle;
  final Translated heroWords;
  final Translated cvDescription;
  final int sortOrder;
  final PublicationStatus status;
}
