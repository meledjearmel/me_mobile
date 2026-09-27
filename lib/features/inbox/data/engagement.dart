import 'package:flutter/foundation.dart';

import '../../../core/models/translated.dart';

enum EngagementType {
  freelance('freelance', 'Freelance'),
  hiring('hiring', 'Embauche');

  const EngagementType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static EngagementType? fromWire(String? value) {
    for (final type in values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return null;
  }
}

enum EngagementStatus {
  newRequest('new', 'Nouvelle'),
  handled('handled', 'Traitée');

  const EngagementStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static EngagementStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => EngagementStatus.newRequest);
}

@immutable
class JobProfileRef {
  const JobProfileRef({required this.id, required this.label});

  factory JobProfileRef.fromJson(Map<String, dynamic> json) =>
      JobProfileRef(id: json['id'] as int, label: Translated.fromJson(json['label']));

  final int id;
  final Translated label;
}

/// Demande de collaboration : freelance ou embauche (§4.2).
@immutable
class Engagement {
  const Engagement({
    required this.id,
    required this.type,
    required this.status,
    required this.name,
    required this.email,
    required this.company,
    required this.subject,
    required this.jobProfile,
    required this.contract,
    required this.budget,
    required this.timeline,
    required this.message,
    required this.locale,
    required this.cvSentAt,
    required this.createdAt,
  });

  factory Engagement.fromJson(Map<String, dynamic> json) => Engagement(
        id: json['id'] as int,
        type: EngagementType.fromWire(json['type'] as String?),
        status: EngagementStatus.fromWire(json['status'] as String?),
        name: json['name'] as String,
        email: json['email'] as String,
        company: json['company'] as String?,
        subject: json['subject'] as String?,
        jobProfile: json['job_profile'] == null
            ? null
            : JobProfileRef.fromJson(json['job_profile'] as Map<String, dynamic>),
        contract: json['contract'] as String?,
        budget: json['budget'] as String?,
        timeline: json['timeline'] as String?,
        message: json['message'] as String?,
        locale: json['locale'] as String? ?? 'fr',
        cvSentAt: json['cv_sent_at'] == null ? null : DateTime.parse(json['cv_sent_at'] as String),
        createdAt: json['created_at'] == null ? null : DateTime.parse(json['created_at'] as String),
      );

  final int id;
  final EngagementType? type;
  final EngagementStatus status;
  final String name;
  final String email;
  final String? company;
  final String? subject;
  final JobProfileRef? jobProfile;
  final String? contract;

  /// Libellé déjà formaté par le serveur (« 5 000 CHF (forfait) »), ou `null`.
  final String? budget;
  final String? timeline;
  final String? message;
  final String locale;

  /// Date d'envoi automatique du CV, pour une embauche.
  final DateTime? cvSentAt;
  final DateTime? createdAt;

  Engagement copyWith({EngagementStatus? status}) => Engagement(
        id: id,
        type: type,
        status: status ?? this.status,
        name: name,
        email: email,
        company: company,
        subject: subject,
        jobProfile: jobProfile,
        contract: contract,
        budget: budget,
        timeline: timeline,
        message: message,
        locale: locale,
        cvSentAt: cvSentAt,
        createdAt: createdAt,
      );
}
