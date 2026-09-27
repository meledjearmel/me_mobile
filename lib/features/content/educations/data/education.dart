import 'package:flutter/foundation.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../core/utils/date_only.dart';

@immutable
class Education {
  const Education({
    required this.id,
    required this.institution,
    required this.degree,
    required this.field,
    required this.startDate,
    required this.endDate,
    required this.description,
    required this.sortOrder,
    required this.status,
  });

  factory Education.fromJson(Map<String, dynamic> json) => Education(
        id: json['id'] as int,
        institution: json['institution'] as String,
        degree: Translated.fromJson(json['degree']),
        field: Translated.fromJson(json['field']),
        startDate: parseDateOnly(json['start_date'] as String?) ?? DateTime.now(),
        endDate: parseDateOnly(json['end_date'] as String?),
        description: Translated.fromJson(json['description']),
        sortOrder: json['sort_order'] as int? ?? 0,
        status: PublicationStatus.fromWire(json['status'] as String?),
      );

  final int id;
  final String institution;
  final Translated degree;
  final Translated field;
  final DateTime startDate;

  /// `null` = en cours (§4.3).
  final DateTime? endDate;
  final Translated description;
  final int sortOrder;
  final PublicationStatus status;
}
