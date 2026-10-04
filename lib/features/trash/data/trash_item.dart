import 'package:flutter/foundation.dart';

/// Types de ressources qui passent par la corbeille (§4.5), avec leur libellé
/// français pour le filtre (le libellé de chaque élément vient déjà traduit
/// du serveur, voir [TrashItem.label]).
const trashTypes = [
  ('domains', 'Domaines'),
  ('music-genres', 'Registres'),
  ('tracks', 'Pistes'),
  ('uses-items', 'Éléments « Uses »'),
  ('technologies', 'Technologies'),
  ('technology-categories', 'Catégories de technologies'),
  ('job-profiles', 'Profils métier'),
  ('skills', 'Compétences'),
  ('educations', 'Formations'),
  ('certifications', 'Certifications'),
  ('experiences', 'Expériences'),
  ('projects', 'Projets'),
  ('professional-references', 'Références'),
  ('testimonials', 'Avis'),
  ('contacts', 'Messages'),
  ('engagements', 'Collaborations'),
  ('appointments', 'Rendez-vous'),
  ('appointment-types', 'Types de rendez-vous'),
  ('posts', 'Articles du blog'),
  ('post-comments', 'Commentaires du blog'),
];

@immutable
class TrashItem {
  const TrashItem({
    required this.id,
    required this.type,
    required this.label,
    required this.title,
    required this.deletedAt,
  });

  factory TrashItem.fromJson(Map<String, dynamic> json) => TrashItem(
        id: json['id'] as int,
        type: json['type'] as String,
        label: json['label'] as String,
        title: json['title'] as String,
        deletedAt: DateTime.tryParse(json['deleted_at'] as String? ?? ''),
      );

  final int id;

  /// Clé technique (`domains`, `projects`…), à repasser telle quelle à
  /// `PATCH|DELETE /trash/{type}/{id}`.
  final String type;

  /// Nom de catégorie déjà traduit par le serveur (« Domaine », « Projet »…).
  final String label;

  /// Titre de cet élément précis (ex. le nom du projet).
  final String title;
  final DateTime? deletedAt;
}
