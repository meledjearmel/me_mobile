import 'package:flutter/foundation.dart';

import '../../../core/models/translated.dart';
import '../../content/data/refs.dart';

enum ProjectStatus {
  published('published', 'Publié'),
  archived('archived', 'Archivé');

  const ProjectStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ProjectStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => ProjectStatus.published);
}

/// Image de galerie : `id` (chaîne) sert à cibler `DELETE .../gallery/{id}` (§4.3).
@immutable
class GalleryImage {
  const GalleryImage({required this.id, required this.url});

  factory GalleryImage.fromJson(Map<String, dynamic> json) =>
      GalleryImage(id: json['id'].toString(), url: json['url'] as String);

  final String id;
  final String url;
}

@immutable
class Project {
  const Project({
    required this.id,
    required this.slug,
    required this.title,
    required this.context,
    required this.realization,
    required this.result,
    required this.accentColor,
    required this.repoUrl,
    required this.demoUrl,
    required this.isFeatured,
    required this.isOpenSource,
    required this.status,
    required this.sortOrder,
    required this.coverUrl,
    required this.gallery,
    required this.domains,
    required this.jobProfiles,
    required this.technologies,
    required this.relatedProjectIds,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as int,
        slug: json['slug'] as String,
        title: Translated.fromJson(json['title']),
        context: Translated.fromJson(json['context']),
        realization: Translated.fromJson(json['realization']),
        result: Translated.fromJson(json['result']),
        accentColor: json['accent_color'] as String?,
        repoUrl: json['repo_url'] as String?,
        demoUrl: json['demo_url'] as String?,
        isFeatured: json['is_featured'] as bool? ?? false,
        isOpenSource: json['is_open_source'] as bool? ?? false,
        status: ProjectStatus.fromWire(json['status'] as String?),
        sortOrder: json['sort_order'] as int? ?? 0,
        coverUrl: json['cover_url'] as String?,
        gallery: [
          for (final item in (json['gallery'] as List<dynamic>? ?? const []))
            GalleryImage.fromJson(item as Map<String, dynamic>),
        ],
        domains: [
          for (final item in (json['domains'] as List<dynamic>? ?? const [])) DomainRef.fromJson(item as Map<String, dynamic>),
        ],
        jobProfiles: [
          for (final item in (json['job_profiles'] as List<dynamic>? ?? const []))
            JobProfileFullRef.fromJson(item as Map<String, dynamic>),
        ],
        technologies: [
          for (final item in (json['technologies'] as List<dynamic>? ?? const []))
            TechnologyRef.fromJson(item as Map<String, dynamic>),
        ],
        // Absent des réponses de liste (§4.3) : liste vide dans ce cas, sans conséquence
        // puisqu'on ne l'utilise que dans le formulaire, rechargé depuis le détail.
        relatedProjectIds: [
          for (final item in (json['related_project_ids'] as List<dynamic>? ?? const [])) item as int,
        ],
      );

  final int id;
  final String slug;
  final Translated title;
  final Translated context;
  final Translated realization;
  final Translated result;
  final String? accentColor;
  final String? repoUrl;
  final String? demoUrl;
  final bool isFeatured;
  final bool isOpenSource;
  final ProjectStatus status;
  final int sortOrder;
  final String? coverUrl;
  final List<GalleryImage> gallery;
  final List<DomainRef> domains;
  final List<JobProfileFullRef> jobProfiles;
  final List<TechnologyRef> technologies;
  final List<int> relatedProjectIds;
}
