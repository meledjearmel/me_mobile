import 'package:flutter/foundation.dart';

import '../../../core/models/translated.dart';
import '../../inbox/data/appointment.dart';

/// Type de rendez-vous proposé aux visiteurs (ex. « Appel découverte, 30 min »).
@immutable
class AppointmentType {
  const AppointmentType({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.locations,
    required this.isActive,
    required this.sortOrder,
  });

  factory AppointmentType.fromJson(Map<String, dynamic> json) => AppointmentType(
    id: json['id'] as int,
    name: Translated.fromJson(json['name']),
    description: Translated.fromJson(json['description']),
    durationMinutes: json['duration_minutes'] as int,
    locations: [
      for (final value in json['locations'] as List<dynamic>? ?? const []) AppointmentLocation.fromWire('$value'),
    ],
    isActive: json['is_active'] as bool? ?? true,
    sortOrder: json['sort_order'] as int? ?? 0,
  );

  final int id;
  final Translated name;
  final Translated description;

  /// 10 à 480 minutes.
  final int durationMinutes;

  /// Lieux que le visiteur peut choisir (au moins un).
  final List<AppointmentLocation> locations;

  /// Proposé sur le site.
  final bool isActive;
  final int sortOrder;
}
