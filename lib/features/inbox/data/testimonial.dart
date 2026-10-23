import 'package:flutter/foundation.dart';

import '../../../core/models/translated.dart';

enum TestimonialStatus {
  pending('pending', 'En attente'),
  approved('approved', 'Approuvé'),
  rejected('rejected', 'Rejeté');

  const TestimonialStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static TestimonialStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => TestimonialStatus.pending);
}

@immutable
class ProjectRef {
  const ProjectRef({required this.id, required this.slug, required this.title});

  factory ProjectRef.fromJson(Map<String, dynamic> json) =>
      ProjectRef(id: json['id'] as int, slug: json['slug'] as String, title: Translated.fromJson(json['title']));

  final int id;
  final String slug;
  final Translated title;

  String get label => title.display;
}

/// Expérience à laquelle un avis est rattaché.
@immutable
class ExperienceRef {
  const ExperienceRef({required this.id, required this.company, required this.role});

  factory ExperienceRef.fromJson(Map<String, dynamic> json) => ExperienceRef(
        id: json['id'] as int,
        company: json['company'] as String,
        role: Translated.fromJson(json['role']),
      );

  final int id;
  final String company;
  final Translated role;

  String get label => '${role.display} · $company';
}

/// Formation à laquelle un avis est rattaché.
@immutable
class EducationRef {
  const EducationRef({required this.id, required this.institution, required this.degree});

  factory EducationRef.fromJson(Map<String, dynamic> json) => EducationRef(
        id: json['id'] as int,
        institution: json['institution'] as String,
        degree: Translated.fromJson(json['degree']),
      );

  final int id;
  final String institution;
  final Translated degree;

  String get label => '${degree.display} · $institution';
}

/// Vidéo jointe ou filmée par le visiteur. `duration` (secondes), `width` et
/// `height` restent nuls tant que le serveur n'a pas traité la vidéo.
@immutable
class TestimonialVideo {
  const TestimonialVideo({required this.url, this.posterUrl, this.duration, this.width, this.height, this.uploadedAt});

  factory TestimonialVideo.fromJson(Map<String, dynamic> json) => TestimonialVideo(
    url: json['url'] as String,
    posterUrl: json['poster_url'] as String?,
    duration: json['duration'] as int?,
    width: json['width'] as int?,
    height: json['height'] as int?,
    uploadedAt: json['uploaded_at'] == null ? null : DateTime.parse(json['uploaded_at'] as String),
  );

  final String url;
  final String? posterUrl;
  final int? duration;
  final int? width;
  final int? height;
  final DateTime? uploadedAt;

  /// Ratio largeur / hauteur, 16:9 tant que la vidéo n'est pas traitée.
  double get aspectRatio => width != null && height != null && height! > 0 ? width! / height! : 16 / 9;

  /// « 1:05 », ou `null` tant que la durée est inconnue.
  String? get durationLabel {
    final seconds = duration;
    if (seconds == null) {
      return null;
    }
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// Avis déposé sur le site public, à modérer (§4.2). Pas de création : les
/// avis viennent du site.
@immutable
class Testimonial {
  const Testimonial({
    required this.id,
    required this.authorName,
    required this.authorEmail,
    required this.authorRole,
    required this.content,
    required this.status,
    required this.isFeatured,
    required this.submittedAt,
    this.projects = const [],
    this.experiences = const [],
    this.educations = const [],
    this.reviewInvitationId,
    this.highlight = const Translated(),
    this.videoTranscript = const Translated(),
    this.video,
  });

  factory Testimonial.fromJson(Map<String, dynamic> json) => Testimonial(
    id: json['id'] as int,
    authorName: json['author_name'] as String,
    authorEmail: json['author_email'] as String,
    authorRole: json['author_role'] as String?,
    content: Translated.fromJson(json['content']),
    status: TestimonialStatus.fromWire(json['status'] as String?),
    isFeatured: json['is_featured'] as bool? ?? false,
    submittedAt: json['submitted_at'] == null ? null : DateTime.parse(json['submitted_at'] as String),
    projects: _refs(json, 'projects', 'project', ProjectRef.fromJson),
    experiences: _refs(json, 'experiences', 'experience', ExperienceRef.fromJson),
    educations: _refs(json, 'educations', 'education', EducationRef.fromJson),
    reviewInvitationId: json['review_invitation_id'] as int?,
    highlight: Translated.fromJson(json['highlight']),
    videoTranscript: Translated.fromJson(json['video_transcript']),
    video: json['video'] is Map<String, dynamic>
        ? TestimonialVideo.fromJson(json['video'] as Map<String, dynamic>)
        : null,
  );

  /// Liste `key` ; à défaut (ancienne réponse), le champ unique déprécié `legacy`.
  static List<T> _refs<T>(
    Map<String, dynamic> json,
    String key,
    String legacy,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = json[key];
    if (list is List) {
      return [for (final item in list) if (item is Map<String, dynamic>) fromJson(item)];
    }
    final single = json[legacy];
    return single is Map<String, dynamic> ? [fromJson(single)] : const [];
  }

  final int id;
  final String authorName;
  final String authorEmail;
  final String? authorRole;
  final Translated content;
  final TestimonialStatus status;
  final bool isFeatured;
  final DateTime? submittedAt;

  /// Projets, expériences et formations liés : plusieurs possibles, aucun pour un avis général.
  final List<ProjectRef> projects;
  final List<ExperienceRef> experiences;
  final List<EducationRef> educations;

  /// Lien d'invitation par lequel l'avis est arrivé.
  final int? reviewInvitationId;

  /// Phrase d'accroche affichée en grand sur les cartes du site (facultative).
  final Translated highlight;
  final Translated videoTranscript;

  /// `null` : avis texte.
  final TestimonialVideo? video;

  /// Rattachements en une ligne (« Projet A · Acme »), ou « Général ».
  String get subjectSummary {
    final labels = [
      for (final p in projects) p.label,
      for (final e in experiences) e.company,
      for (final e in educations) e.institution,
    ];
    return labels.isEmpty ? 'Général' : labels.join(' · ');
  }

  Testimonial copyWith({
    TestimonialStatus? status,
    bool? isFeatured,
    String? authorName,
    String? authorRole,
    Translated? content,
  }) => Testimonial(
    id: id,
    authorName: authorName ?? this.authorName,
    authorEmail: authorEmail,
    authorRole: authorRole ?? this.authorRole,
    content: content ?? this.content,
    status: status ?? this.status,
    isFeatured: isFeatured ?? this.isFeatured,
    submittedAt: submittedAt,
    projects: projects,
    experiences: experiences,
    educations: educations,
    reviewInvitationId: reviewInvitationId,
    highlight: highlight,
    videoTranscript: videoTranscript,
    video: video,
  );
}
