import 'package:flutter/foundation.dart';

/// Jours de la semaine, dans l'ordre du calendrier français.
enum Weekday {
  monday('monday', 'Lundi', 'Lun'),
  tuesday('tuesday', 'Mardi', 'Mar'),
  wednesday('wednesday', 'Mercredi', 'Mer'),
  thursday('thursday', 'Jeudi', 'Jeu'),
  friday('friday', 'Vendredi', 'Ven'),
  saturday('saturday', 'Samedi', 'Sam'),
  sunday('sunday', 'Dimanche', 'Dim');

  const Weekday(this.wireValue, this.label, this.short);

  final String wireValue;
  final String label;
  final String short;

  static Weekday? fromWire(String value) {
    for (final day in values) {
      if (day.wireValue == value) {
        return day;
      }
    }
    return null;
  }
}

/// Plage hebdomadaire de disponibilité (heures d'Abidjan, `HH:mm`).
@immutable
class AvailabilityRule {
  const AvailabilityRule({required this.id, required this.days, required this.start, required this.end});

  factory AvailabilityRule.fromJson(Map<String, dynamic> json) => AvailabilityRule(
    id: json['id'] as int,
    days: [for (final value in json['days'] as List<dynamic>? ?? const []) ?Weekday.fromWire('$value')]
      ..sort((a, b) => a.index.compareTo(b.index)),
    start: json['start'] as String,
    end: json['end'] as String,
  );

  final int id;
  final List<Weekday> days;
  final String start;
  final String end;

  /// « Lun, Mar, Mer » ou « Lundi » pour un seul jour.
  String get daysLabel => days.length == 1 ? days.single.label : days.map((d) => d.short).join(', ');
}

/// Période où aucun rendez-vous n'est proposé (congés…), dates incluses.
@immutable
class BlockedPeriod {
  const BlockedPeriod({required this.id, required this.label, required this.from, required this.to});

  factory BlockedPeriod.fromJson(Map<String, dynamic> json) => BlockedPeriod(
    id: json['id'] as int,
    label: json['label'] as String?,
    from: DateTime.parse(json['from'] as String),
    to: DateTime.parse(json['to'] as String),
  );

  final int id;
  final String? label;
  final DateTime from;
  final DateTime to;
}

@immutable
class Availability {
  const Availability({required this.rules, required this.blockedPeriods});

  factory Availability.fromJson(Map<String, dynamic> json) => Availability(
    rules: [
      for (final item in json['rules'] as List<dynamic>? ?? const [])
        AvailabilityRule.fromJson(item as Map<String, dynamic>),
    ],
    blockedPeriods: [
      for (final item in json['blocked_periods'] as List<dynamic>? ?? const [])
        BlockedPeriod.fromJson(item as Map<String, dynamic>),
    ],
  );

  final List<AvailabilityRule> rules;
  final List<BlockedPeriod> blockedPeriods;
}
