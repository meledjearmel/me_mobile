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

/// `fixed` (forfait estimé) ou `hourly` (facturé à l'heure).
String billingLabel(String billing) => switch (billing) {
      'fixed' => 'Forfait',
      'hourly' => 'À l\'heure',
      _ => billing,
    };

/// Estimation calculée par l'estimateur du site, telle que le visiteur l'a vue.
@immutable
class EngagementEstimate {
  const EngagementEstimate({
    required this.billing,
    required this.currency,
    required this.hourlyRate,
    required this.riskPercent,
    required this.projectType,
    required this.features,
    required this.hoursMin,
    required this.hoursMax,
    required this.priceMin,
    required this.priceMax,
    required this.weeksMin,
    required this.weeksMax,
  });

  factory EngagementEstimate.fromJson(Map<String, dynamic> json) => EngagementEstimate(
        billing: json['billing'] as String? ?? 'fixed',
        currency: json['currency'] as String? ?? '',
        hourlyRate: json['hourly_rate'] as int? ?? 0,
        riskPercent: json['risk_percent'] as int? ?? 0,
        projectType: json['project_type'] as String? ?? '',
        features: [for (final f in json['features'] as List<dynamic>? ?? const []) f as String],
        hoursMin: json['hours_min'] as int? ?? 0,
        hoursMax: json['hours_max'] as int? ?? 0,
        priceMin: json['price_min'] as int? ?? 0,
        priceMax: json['price_max'] as int? ?? 0,
        weeksMin: json['weeks_min'] as int? ?? 0,
        weeksMax: json['weeks_max'] as int? ?? 0,
      );

  final String billing;
  final String currency;
  final int hourlyRate;
  final int riskPercent;
  final String projectType;

  /// Options choisies par le visiteur.
  final List<String> features;
  final int hoursMin;
  final int hoursMax;
  final int priceMin;
  final int priceMax;
  final int weeksMin;
  final int weeksMax;
}

/// Analyse de l'IA : risques, points flous, questions, heures réalistes (marge comprise).
@immutable
class EngagementAnalysis {
  const EngagementAnalysis({
    required this.summary,
    required this.risks,
    required this.unclearPoints,
    required this.questions,
    required this.hoursMin,
    required this.hoursMax,
    required this.billing,
    this.reasoning,
    this.priceMin,
    this.priceMax,
    this.currency,
  });

  factory EngagementAnalysis.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) => [for (final s in json[key] as List<dynamic>? ?? const []) s as String];
    return EngagementAnalysis(
      summary: json['summary'] as String? ?? '',
      risks: strings('risks'),
      unclearPoints: strings('unclear_points'),
      questions: strings('questions'),
      hoursMin: json['hours_min'] as int? ?? 0,
      hoursMax: json['hours_max'] as int? ?? 0,
      billing: json['billing'] as String? ?? 'fixed',
      reasoning: json['reasoning'] as String?,
      priceMin: json['price_min'] as int?,
      priceMax: json['price_max'] as int?,
      currency: json['currency'] as String?,
    );
  }

  final String summary;
  final List<String> risks;
  final List<String> unclearPoints;
  final List<String> questions;
  final int hoursMin;
  final int hoursMax;

  /// Facturation recommandée : `fixed` ou `hourly`.
  final String billing;
  final String? reasoning;

  /// Prix au taux de la demande ; `null` sans taux connu.
  final int? priceMin;
  final int? priceMax;
  final String? currency;
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
    this.estimate,
    this.estimateLabel,
    this.aiAnalysis,
    this.aiAnalyzedAt,
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
        estimate: json['estimate'] is Map<String, dynamic>
            ? EngagementEstimate.fromJson(json['estimate'] as Map<String, dynamic>)
            : null,
        estimateLabel: (json['estimate_label'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['estimate_label'] as String,
        aiAnalysis: json['ai_analysis'] is Map<String, dynamic>
            ? EngagementAnalysis.fromJson(json['ai_analysis'] as Map<String, dynamic>)
            : null,
        aiAnalyzedAt: json['ai_analyzed_at'] == null ? null : DateTime.parse(json['ai_analyzed_at'] as String),
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

  /// Estimation montrée au visiteur, quand la demande vient de l'estimateur.
  final EngagementEstimate? estimate;

  /// La même estimation, lisible (« 3 600 – 6 000 CHF (forfait, 36 – 60 h) · 2 semaines »).
  final String? estimateLabel;

  /// Analyse de l'IA pour chiffrer la demande ; faite d'office pour une demande de l'estimateur.
  final EngagementAnalysis? aiAnalysis;
  final DateTime? aiAnalyzedAt;
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
        estimate: estimate,
        estimateLabel: estimateLabel,
        aiAnalysis: aiAnalysis,
        aiAnalyzedAt: aiAnalyzedAt,
        timeline: timeline,
        message: message,
        locale: locale,
        cvSentAt: cvSentAt,
        createdAt: createdAt,
      );
}
