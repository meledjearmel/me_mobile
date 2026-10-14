import 'package:flutter/foundation.dart';

import '../../../core/utils/date_only.dart';

/// `draft` (lien inactif), `active` (en ligne) ou `archived` (lien coupé).
enum JobApplicationStatus {
  draft('draft', 'Brouillon'),
  active('active', 'En ligne'),
  archived('archived', 'Archivée');

  const JobApplicationStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static JobApplicationStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => draft);
}

/// CV adapté à l'offre par l'IA (`cv_tailoring`) ; absent : CV standard du profil.
@immutable
class CvTailoring {
  const CvTailoring({
    this.title,
    this.summary,
    this.reasoning,
    this.experiences = const {},
    this.skillIds = const [],
    this.projectIds = const [],
  });

  factory CvTailoring.fromJson(Map<String, dynamic> json) => CvTailoring(
    title: json['title'] as String?,
    summary: json['summary'] as String?,
    reasoning: json['reasoning'] as String?,
    experiences: {
      for (final MapEntry(:key, :value) in (json['experiences'] as Map<String, dynamic>? ?? const {}).entries)
        key: [for (final id in value as List<dynamic>? ?? const []) id as int],
    },
    skillIds: [for (final id in json['skill_ids'] as List<dynamic>? ?? const []) id as int],
    projectIds: [for (final id in json['project_ids'] as List<dynamic>? ?? const []) id as int],
  );

  final String? title;
  final String? summary;
  final String? reasoning;

  /// Pour chaque expérience (clé), les réalisations retenues, dans l'ordre.
  final Map<String, List<int>> experiences;
  final List<int> skillIds;
  final List<int> projectIds;

  int get highlightsCount => experiences.values.fold(0, (sum, ids) => sum + ids.length);
}

/// Page de candidature privée envoyée à une entreprise (`/v1/job-applications`).
@immutable
class JobApplication {
  const JobApplication({
    required this.id,
    required this.token,
    required this.url,
    required this.company,
    required this.position,
    required this.locale,
    required this.intro,
    required this.status,
    this.contactName,
    this.jobProfileId,
    this.cvTailoring,
    this.cvTailoredAt,
    this.jobPostingUrl,
    this.jobPostingText,
    this.notes,
    this.isOpen = false,
    this.expiresOn,
    this.projectIds = const [],
    this.viewsCount = 0,
    this.cvDownloadsCount = 0,
    this.firstViewedAt,
    this.lastViewedAt,
    this.draftedBy,
    this.createdAt,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) => JobApplication(
    id: json['id'] as int,
    token: json['token'] as String? ?? '',
    url: json['url'] as String? ?? '',
    company: json['company'] as String? ?? '',
    contactName: json['contact_name'] as String?,
    position: json['position'] as String? ?? '',
    jobProfileId: json['job_profile_id'] as int?,
    cvTailoring: json['cv_tailoring'] is Map<String, dynamic>
        ? CvTailoring.fromJson(json['cv_tailoring'] as Map<String, dynamic>)
        : null,
    cvTailoredAt: DateTime.tryParse(json['cv_tailored_at'] as String? ?? '')?.toLocal(),
    locale: json['locale'] as String? ?? 'fr',
    intro: json['intro'] as String? ?? '',
    jobPostingUrl: json['job_posting_url'] as String?,
    jobPostingText: json['job_posting_text'] as String?,
    notes: json['notes'] as String?,
    status: JobApplicationStatus.fromWire(json['status'] as String?),
    isOpen: json['is_open'] as bool? ?? false,
    expiresOn: parseDateOnly(json['expires_on'] as String?),
    projectIds: [for (final id in json['project_ids'] as List<dynamic>? ?? const []) id as int],
    viewsCount: json['views_count'] as int? ?? 0,
    cvDownloadsCount: json['cv_downloads_count'] as int? ?? 0,
    firstViewedAt: DateTime.tryParse(json['first_viewed_at'] as String? ?? '')?.toLocal(),
    lastViewedAt: DateTime.tryParse(json['last_viewed_at'] as String? ?? '')?.toLocal(),
    draftedBy: json['drafted_by'] as String?,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
  );

  final int id;
  final String token;

  /// Lien privé à envoyer à l'entreprise ; ne répond que si [isOpen].
  final String url;
  final String company;
  final String? contactName;
  final String position;
  final int? jobProfileId;
  final CvTailoring? cvTailoring;
  final DateTime? cvTailoredAt;

  /// `fr` ou `en`.
  final String locale;

  /// Mot d'accompagnement, avec d'éventuels jetons `@[Titre](project:12)`.
  final String intro;
  final String? jobPostingUrl;
  final String? jobPostingText;
  final String? notes;
  final JobApplicationStatus status;
  final bool isOpen;

  /// Dernier jour d'ouverture (inclus) ; `null` : sans limite.
  final DateTime? expiresOn;
  final List<int> projectIds;
  final int viewsCount;
  final int cvDownloadsCount;
  final DateTime? firstViewedAt;
  final DateTime? lastViewedAt;
  final String? draftedBy;
  final DateTime? createdAt;

  bool get isTailored => cvTailoring != null;

  /// En ligne mais fermée parce que la date d'expiration est passée.
  bool get isExpired => status == JobApplicationStatus.active && !isOpen;
}

/// Ce que l'IA propose d'après une offre (`POST /v1/ai/draft-job-application`).
@immutable
class JobApplicationDraft {
  const JobApplicationDraft({
    required this.company,
    required this.position,
    required this.intro,
    this.contactName,
    this.projectIds = const [],
    this.jobProfileId,
    this.reasoning,
  });

  factory JobApplicationDraft.fromJson(Map<String, dynamic> json) => JobApplicationDraft(
    company: json['company'] as String? ?? '',
    contactName: json['contact_name'] as String?,
    position: json['position'] as String? ?? '',
    intro: json['intro'] as String? ?? '',
    projectIds: [for (final id in json['project_ids'] as List<dynamic>? ?? const []) id as int],
    jobProfileId: json['job_profile_id'] as int?,
    reasoning: json['reasoning'] as String?,
  );

  final String company;
  final String? contactName;
  final String position;
  final String intro;
  final List<int> projectIds;
  final int? jobProfileId;
  final String? reasoning;
}

enum JobApplicationEventType {
  view('view', 'Consultation'),
  cvDownload('cv_download', 'CV téléchargé');

  const JobApplicationEventType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static JobApplicationEventType fromWire(String? value) =>
      values.firstWhere((t) => t.wireValue == value, orElse: () => view);
}

/// Visite ou téléchargement du CV (`GET /v1/job-applications/{id}/events`).
@immutable
class JobApplicationEvent {
  const JobApplicationEvent({
    required this.id,
    required this.type,
    this.countryCode,
    this.country,
    this.city,
    this.device,
    this.referrerHost,
    this.createdAt,
  });

  factory JobApplicationEvent.fromJson(Map<String, dynamic> json) => JobApplicationEvent(
    id: json['id'] as int,
    type: JobApplicationEventType.fromWire(json['type'] as String?),
    countryCode: json['country_code'] as String?,
    country: json['country'] as String?,
    city: json['city'] as String?,
    device: json['device'] as String?,
    referrerHost: json['referrer_host'] as String?,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
  );

  final int id;
  final JobApplicationEventType type;
  final String? countryCode;
  final String? country;
  final String? city;
  final String? device;
  final String? referrerHost;
  final DateTime? createdAt;

  /// « Abidjan, Côte d'Ivoire », ou `null` si la position est inconnue.
  String? get place {
    final parts = [city, country].whereType<String>().where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }
}
