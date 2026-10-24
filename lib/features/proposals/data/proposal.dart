import 'package:flutter/foundation.dart';

enum ProposalPlatform {
  upwork('upwork', 'Upwork'),
  malt('malt', 'Malt'),
  fiverr('fiverr', 'Fiverr'),
  freelancer('freelancer', 'Freelancer'),
  linkedin('linkedin', 'LinkedIn'),
  other('other', 'Autre');

  const ProposalPlatform(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ProposalPlatform fromWire(String? value) =>
      values.firstWhere((p) => p.wireValue == value, orElse: () => other);
}

enum ProposalStatus {
  draft('draft', 'Brouillon'),
  sent('sent', 'Envoyée'),
  viewed('viewed', 'Vue'),
  interview('interview', 'Entretien'),
  hired('hired', 'Mission obtenue'),
  declined('declined', 'Refusée');

  const ProposalStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  /// Entretien et mission obtenue : les étapes mises en avant.
  bool get isHighlighted => this == interview || this == hired;

  static ProposalStatus fromWire(String? value) => values.firstWhere((s) => s.wireValue == value, orElse: () => draft);
}

/// Proposition envoyée sur une plateforme freelance (`/v1/proposals`). Privée.
@immutable
class Proposal {
  const Proposal({
    required this.id,
    required this.platform,
    required this.locale,
    required this.jobTitle,
    required this.body,
    required this.status,
    this.clientName,
    this.jobUrl,
    this.jobPosting,
    this.screeningAnswers,
    this.bid,
    this.connects,
    this.notes,
    this.draftedBy,
    this.sentAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Proposal.fromJson(Map<String, dynamic> json) => Proposal(
    id: json['id'] as int,
    platform: ProposalPlatform.fromWire(json['platform'] as String?),
    locale: json['locale'] as String? ?? 'fr',
    jobTitle: json['job_title'] as String? ?? '',
    clientName: json['client_name'] as String?,
    jobUrl: json['job_url'] as String?,
    jobPosting: json['job_posting'] as String?,
    body: json['body'] as String? ?? '',
    screeningAnswers: json['screening_answers'] as String?,
    bid: json['bid'] as String?,
    connects: json['connects'] as int?,
    status: ProposalStatus.fromWire(json['status'] as String?),
    notes: json['notes'] as String?,
    draftedBy: json['drafted_by'] as String?,
    sentAt: DateTime.tryParse(json['sent_at'] as String? ?? '')?.toLocal(),
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal(),
  );

  final int id;
  final ProposalPlatform platform;

  /// `fr` ou `en`.
  final String locale;
  final String jobTitle;
  final String? clientName;
  final String? jobUrl;
  final String? jobPosting;

  /// La version réellement envoyée : elle sert d'exemple à l'IA.
  final String body;
  final String? screeningAnswers;

  /// Texte libre : « 40 $/h », « 1 200 € au forfait ».
  final String? bid;
  final int? connects;
  final ProposalStatus status;
  final String? notes;

  /// Client IA qui a rédigé le brouillon, `null` sinon.
  final String? draftedBy;

  /// Posée par le serveur au premier statut qui n'est plus `draft`.
  final DateTime? sentAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// « Upwork · EN ».
  String get platformLine => '${platform.label} · ${locale.toUpperCase()}';

  /// Ce qu'on colle sur la plateforme : la proposition, puis les réponses aux questions.
  String get clipboardText {
    final answers = screeningAnswers?.trim();
    return answers == null || answers.isEmpty ? body : '$body\n\n$answers';
  }
}
