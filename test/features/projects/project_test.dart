import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/features/projects/data/project.dart';

const _fullJson = {
  'id': 1,
  'slug': 'mon-projet',
  'title': {'fr': 'Mon projet', 'en': 'My project'},
  'context': {'fr': 'Contexte', 'en': 'Context'},
  'realization': {'fr': 'Réalisation', 'en': 'Realization'},
  'result': {'fr': 'Résultat', 'en': 'Result'},
  'accent_color': '#71B7F4',
  'repo_url': 'https://github.com/armel/mon-projet',
  'demo_url': null,
  'is_featured': true,
  'is_open_source': true,
  'status': 'published',
  'sort_order': 3,
  'cover_url': 'https://me.armeldev.xyz/covers/1.jpg',
  'gallery': [
    {'id': 'a1', 'url': 'https://me.armeldev.xyz/gallery/1.jpg'},
    {'id': 'a2', 'url': 'https://me.armeldev.xyz/gallery/2.jpg'},
  ],
  'domains': [
    {'id': 1, 'key': 'web', 'label': {'fr': 'Web', 'en': 'Web'}, 'color': '#3b82f6', 'icon': 'globe', 'sort_order': 1, 'status': 'published'},
  ],
  'job_profiles': [
    {
      'id': 2,
      'key': 'lead',
      'label': {'fr': 'Lead technique', 'en': 'Tech lead'},
      'description': {'fr': '', 'en': ''},
      'hero_title': {'fr': '', 'en': ''},
      'hero_words': {'fr': '', 'en': ''},
      'cv_description': {'fr': '', 'en': ''},
      'sort_order': 1,
      'status': 'published',
    },
  ],
  'technologies': [
    {'id': 5, 'name': 'Flutter', 'category': 'frameworks', 'icon': null},
  ],
  'related_project_ids': [2, 3],
};

void main() {
  test('parse un projet complet avec toutes ses relations', () {
    final project = Project.fromJson(_fullJson);

    expect(project.title.fr, 'Mon projet');
    expect(project.status, ProjectStatus.published);
    expect(project.gallery, hasLength(2));
    expect(project.gallery.first.id, 'a1');
    expect(project.domains.single.label.fr, 'Web');
    expect(project.jobProfiles.single.label.en, 'Tech lead');
    expect(project.technologies.single.name, 'Flutter');
    expect(project.relatedProjectIds, [2, 3]);
  });

  test('sans related_project_ids (réponse de liste) : liste vide plutôt que planter', () {
    final json = Map<String, dynamic>.from(_fullJson)..remove('related_project_ids');
    final project = Project.fromJson(json);

    expect(project.relatedProjectIds, isEmpty);
  });

  test('sans couverture ni galerie : tout reste vide proprement', () {
    final json = Map<String, dynamic>.from(_fullJson)
      ..['cover_url'] = null
      ..['gallery'] = <dynamic>[]
      ..['domains'] = <dynamic>[]
      ..['job_profiles'] = <dynamic>[]
      ..['technologies'] = <dynamic>[];

    final project = Project.fromJson(json);

    expect(project.coverUrl, isNull);
    expect(project.gallery, isEmpty);
    expect(project.domains, isEmpty);
  });

  test('statut inconnu retombe sur "published" plutôt que de planter', () {
    expect(ProjectStatus.fromWire('autre'), ProjectStatus.published);
  });
}
