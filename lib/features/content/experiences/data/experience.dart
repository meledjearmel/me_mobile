import 'package:flutter/foundation.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../core/utils/date_only.dart';

/// Point marquant d'une expérience (§4.3). `id == null` : pas encore créé
/// côté serveur. Un point sans `id` est créé, un point absent est supprimé.
@immutable
class Highlight {
  const Highlight({this.id, required this.text, required this.sortOrder});

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
        id: json['id'] as int?,
        text: Translated.fromJson(json['text']),
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  final int? id;
  final Translated text;
  final int sortOrder;

  Map<String, dynamic> toJson() => {'id': id, 'text': text.toJson(), 'sort_order': sortOrder};

  Highlight copyWith({Translated? text}) => Highlight(id: id, text: text ?? this.text, sortOrder: sortOrder);
}

@immutable
class Experience {
  const Experience({
    required this.id,
    required this.company,
    required this.role,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.description,
    required this.sortOrder,
    required this.status,
    required this.highlights,
  });

  factory Experience.fromJson(Map<String, dynamic> json) => Experience(
        id: json['id'] as int,
        company: json['company'] as String,
        role: Translated.fromJson(json['role']),
        location: json['location'] as String?,
        startDate: parseDateOnly(json['start_date'] as String?) ?? DateTime.now(),
        endDate: parseDateOnly(json['end_date'] as String?),
        description: Translated.fromJson(json['description']),
        sortOrder: json['sort_order'] as int? ?? 0,
        status: PublicationStatus.fromWire(json['status'] as String?),
        highlights: [
          for (final item in (json['highlights'] as List<dynamic>? ?? const []))
            Highlight.fromJson(item as Map<String, dynamic>),
        ],
      );

  final int id;
  final String company;
  final Translated role;
  final String? location;
  final DateTime startDate;
  final DateTime? endDate;
  final Translated description;
  final int sortOrder;
  final PublicationStatus status;
  final List<Highlight> highlights;
}
