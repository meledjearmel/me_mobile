import 'package:flutter/material.dart';

import '../../../core/models/translated.dart';

enum AppointmentStatus {
  pending('pending', 'En attente'),
  confirmed('confirmed', 'Confirmé'),
  declined('declined', 'Refusé'),
  cancelled('cancelled', 'Annulé');

  const AppointmentStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static AppointmentStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => AppointmentStatus.pending);
}

/// Lieu choisi par le visiteur parmi ceux du type de rendez-vous.
enum AppointmentLocation {
  video('video', 'Visio', Icons.videocam_outlined),
  phone('phone', 'Téléphone', Icons.phone_outlined),
  whatsapp('whatsapp', 'WhatsApp', Icons.chat_outlined),
  inPerson('in_person', 'En personne', Icons.place_outlined);

  const AppointmentLocation(this.wireValue, this.label, this.icon);

  final String wireValue;
  final String label;
  final IconData icon;

  static AppointmentLocation fromWire(String? value) =>
      values.firstWhere((l) => l.wireValue == value, orElse: () => AppointmentLocation.video);
}

@immutable
class AppointmentTypeRef {
  const AppointmentTypeRef({required this.id, required this.name, required this.durationMinutes});

  factory AppointmentTypeRef.fromJson(Map<String, dynamic> json) => AppointmentTypeRef(
    id: json['id'] as int,
    name: Translated.fromJson(json['name']),
    durationMinutes: json['duration_minutes'] as int,
  );

  final int id;
  final Translated name;
  final int durationMinutes;
}

/// Demande de rendez-vous déposée sur le site. Pas de création : à confirmer
/// ou refuser ; le visiteur peut l'annuler depuis son e-mail.
@immutable
class Appointment {
  const Appointment({
    required this.id,
    required this.type,
    required this.name,
    required this.email,
    required this.phone,
    required this.company,
    required this.location,
    required this.message,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.locale,
    required this.status,
    required this.meetingDetails,
    required this.declineReason,
    required this.confirmedAt,
    required this.cancelledAt,
    required this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['id'] as int,
    type: json['appointment_type'] is Map<String, dynamic>
        ? AppointmentTypeRef.fromJson(json['appointment_type'] as Map<String, dynamic>)
        : null,
    name: json['name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    company: json['company'] as String?,
    location: AppointmentLocation.fromWire(json['location'] as String?),
    message: json['message'] as String?,
    startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
    endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
    timezone: json['timezone'] as String?,
    locale: json['locale'] as String? ?? 'fr',
    status: AppointmentStatus.fromWire(json['status'] as String?),
    meetingDetails: json['meeting_details'] as String?,
    declineReason: json['decline_reason'] as String?,
    confirmedAt: _date(json['confirmed_at']),
    cancelledAt: _date(json['cancelled_at']),
    createdAt: _date(json['created_at']),
  );

  static DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String).toLocal();

  final int id;

  /// `null` si le type a été supprimé.
  final AppointmentTypeRef? type;
  final String name;
  final String email;
  final String? phone;
  final String? company;
  final AppointmentLocation location;
  final String? message;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Fuseau du visiteur (ex. `Europe/Paris`), pour info.
  final String? timezone;
  final String locale;
  final AppointmentStatus status;

  /// Lien de visio, numéro ou adresse communiqué au visiteur à la confirmation.
  final String? meetingDetails;
  final String? declineReason;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;

  /// Le rendez-vous est passé.
  bool get isPast => endsAt.isBefore(DateTime.now());
}
