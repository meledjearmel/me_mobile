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

  factory ProjectRef.fromJson(Map<String, dynamic> json) => ProjectRef(
        id: json['id'] as int,
        slug: json['slug'] as String,
        title: Translated.fromJson(json['title']),
      );

  final int id;
  final String slug;
  final Translated title;
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
    required this.project,
    required this.submittedAt,
  });

  factory Testimonial.fromJson(Map<String, dynamic> json) => Testimonial(
        id: json['id'] as int,
        authorName: json['author_name'] as String,
        authorEmail: json['author_email'] as String,
        authorRole: json['author_role'] as String?,
        content: Translated.fromJson(json['content']),
        status: TestimonialStatus.fromWire(json['status'] as String?),
        isFeatured: json['is_featured'] as bool? ?? false,
        project: json['project'] == null ? null : ProjectRef.fromJson(json['project'] as Map<String, dynamic>),
        submittedAt: json['submitted_at'] == null ? null : DateTime.parse(json['submitted_at'] as String),
      );

  final int id;
  final String authorName;
  final String authorEmail;
  final String? authorRole;
  final Translated content;
  final TestimonialStatus status;
  final bool isFeatured;
  final ProjectRef? project;
  final DateTime? submittedAt;

  Testimonial copyWith({
    TestimonialStatus? status,
    bool? isFeatured,
    String? authorName,
    String? authorRole,
    Translated? content,
  }) =>
      Testimonial(
        id: id,
        authorName: authorName ?? this.authorName,
        authorEmail: authorEmail,
        authorRole: authorRole ?? this.authorRole,
        content: content ?? this.content,
        status: status ?? this.status,
        isFeatured: isFeatured ?? this.isFeatured,
        project: project,
        submittedAt: submittedAt,
      );
}
