import 'package:flutter/foundation.dart';

import '../../../core/models/translated.dart';
import 'project.dart';

/// Champs proposés par `POST /v1/ai/draft-project`, en français : à injecter
/// dans le formulaire de création, rien n'est enregistré.
@immutable
class ProjectDraft {
  const ProjectDraft({
    required this.title,
    required this.slug,
    this.tagline,
    this.role,
    this.client,
    this.platform,
    required this.context,
    this.challenges,
    this.realization,
    this.result,
    this.decisions = const [],
    this.keyFigures = const [],
    this.startedOn,
    this.endedOn,
    this.teamSize,
    this.technologies = const [],
    this.domains = const [],
    this.jobProfiles = const [],
    this.githubRepository,
    this.repoUrl,
    this.demoUrl,
    this.isOpenSource,
  });

  factory ProjectDraft.fromJson(Map<String, dynamic> json) {
    List<int> ids(String key) => [
      for (final id in json[key] as List<dynamic>? ?? const [])
        if (id is int) id,
    ];
    return ProjectDraft(
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      tagline: json['tagline'] as String?,
      role: json['role'] as String?,
      client: json['client'] as String?,
      platform: json['platform'] as String?,
      context: json['context'] as String? ?? '',
      challenges: json['challenges'] as String?,
      realization: json['realization'] as String?,
      result: json['result'] as String?,
      decisions: [
        for (final item in json['decisions'] as List<dynamic>? ?? const [])
          if (item is Map<String, dynamic>)
            Decision(
              choice: Translated(fr: item['choice']?.toString() ?? ''),
              reason: Translated(fr: item['reason']?.toString() ?? ''),
            ),
      ],
      keyFigures: [
        for (final item in json['key_figures'] as List<dynamic>? ?? const [])
          if (item is Map<String, dynamic>)
            KeyFigure(
              value: item['value']?.toString() ?? '',
              label: Translated(fr: item['label']?.toString() ?? ''),
            ),
      ],
      startedOn: json['started_on'] as String?,
      endedOn: json['ended_on'] as String?,
      teamSize: json['team_size'] as int?,
      technologies: ids('technologies'),
      domains: ids('domains'),
      jobProfiles: ids('job_profiles'),
      githubRepository: json['github_repository'] as String?,
      repoUrl: json['repo_url'] as String?,
      demoUrl: json['demo_url'] as String?,
      isOpenSource: json['is_open_source'] as bool?,
    );
  }

  final String title;
  final String slug;
  final String? tagline;
  final String? role;
  final String? client;
  final String? platform;
  final String context;
  final String? challenges;
  final String? realization;
  final String? result;
  final List<Decision> decisions;
  final List<KeyFigure> keyFigures;

  /// `AAAA-MM`.
  final String? startedOn;
  final String? endedOn;
  final int? teamSize;
  final List<int> technologies;
  final List<int> domains;
  final List<int> jobProfiles;

  /// Présents seulement quand un dépôt a été fourni.
  final String? githubRepository;
  final String? repoUrl;
  final String? demoUrl;
  final bool? isOpenSource;
}
