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

/// Chiffre clé de l'étude de cas : valeur courte (`« 3× »`, `« 40 % »`) et
/// libellé bilingue. 4 au plus par projet, dans l'ordre d'affichage.
@immutable
class KeyFigure {
  const KeyFigure({required this.value, required this.label});

  factory KeyFigure.fromJson(Map<String, dynamic> json) =>
      KeyFigure(value: json['value']?.toString() ?? '', label: Translated.fromJson(json['label']));

  static const maxCount = 4;

  final String value;
  final Translated label;

  Map<String, Object> toJson() => {'value': value, 'label': label};

  @override
  bool operator ==(Object other) => other is KeyFigure && other.value == value && other.label == label;

  @override
  int get hashCode => Object.hash(value, label);
}

/// Choix technique argumenté de l'étude de cas : le choix et sa raison,
/// bilingues. [maxCount] au plus par projet, dans l'ordre d'affichage.
@immutable
class Decision {
  const Decision({required this.choice, required this.reason});

  factory Decision.fromJson(Map<String, dynamic> json) =>
      Decision(choice: Translated.fromJson(json['choice']), reason: Translated.fromJson(json['reason']));

  static const maxCount = 6;

  final Translated choice;
  final Translated reason;

  Map<String, Object> toJson() => {'choice': choice, 'reason': reason};

  @override
  bool operator ==(Object other) => other is Decision && other.choice == choice && other.reason == reason;

  @override
  int get hashCode => Object.hash(choice, reason);
}

@immutable
class Project {
  const Project({
    required this.id,
    required this.slug,
    required this.title,
    this.tagline = const Translated(),
    this.role = const Translated(),
    this.client = const Translated(),
    this.platform = const Translated(),
    required this.context,
    required this.realization,
    required this.result,
    this.keyFigures = const [],
    this.challenges = const Translated(),
    this.decisions = const [],
    this.startedOn,
    this.endedOn,
    this.teamSize,
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
    // Étude de cas : `null` quand le champ est vide, lu comme texte vide.
    tagline: Translated.fromJson(json['tagline']),
    role: Translated.fromJson(json['role']),
    client: Translated.fromJson(json['client']),
    platform: Translated.fromJson(json['platform']),
    context: Translated.fromJson(json['context']),
    realization: Translated.fromJson(json['realization']),
    result: Translated.fromJson(json['result']),
    keyFigures: [
      for (final item in (json['key_figures'] as List<dynamic>? ?? const []))
        if (item is Map<String, dynamic>) KeyFigure.fromJson(item),
    ],
    challenges: Translated.fromJson(json['challenges']),
    decisions: [
      for (final item in (json['decisions'] as List<dynamic>? ?? const []))
        if (item is Map<String, dynamic>) Decision.fromJson(item),
    ],
    startedOn: json['started_on'] as String?,
    endedOn: json['ended_on'] as String?,
    teamSize: json['team_size'] as int?,
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
      for (final item in (json['domains'] as List<dynamic>? ?? const []))
        DomainRef.fromJson(item as Map<String, dynamic>),
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
    relatedProjectIds: [for (final item in (json['related_project_ids'] as List<dynamic>? ?? const [])) item as int],
  );

  final int id;
  final String slug;
  final Translated title;

  /// Accroche du bandeau (vide : le site reprend la 1re phrase du contexte).
  final Translated tagline;

  /// Rôle tenu, client (anonymisé) et plateforme : fiche d'identité du projet.
  final Translated role;
  final Translated client;
  final Translated platform;
  final Translated context;
  final Translated realization;
  final Translated result;
  final List<KeyFigure> keyFigures;

  /// Défis et contraintes (section facultative de l'étude de cas).
  final Translated challenges;
  final List<Decision> decisions;

  /// Période au mois près (`AAAA-MM`). Fin `null` avec un début : en cours.
  final String? startedOn;
  final String? endedOn;

  /// Taille de l'équipe, moi compris.
  final int? teamSize;
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
