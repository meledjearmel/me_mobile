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
  'cover_url': 'https://armeldev.xyz/covers/1.jpg',
  'gallery': [
    {'id': 'a1', 'url': 'https://armeldev.xyz/gallery/1.jpg'},
    {'id': 'a2', 'url': 'https://armeldev.xyz/gallery/2.jpg'},
  ],
  'domains': [
    {
      'id': 1,
      'key': 'web',
      'label': {'fr': 'Web', 'en': 'Web'},
      'color': '#3b82f6',
      'icon': 'globe',
      'sort_order': 1,
      'status': 'published',
    },
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

  group('étude de cas', () {
    test('champs vides : null (étude de cas) et {} (texte facultatif) donnent des textes vides', () {
      final project = Project.fromJson({
        ..._fullJson,
        'tagline': null,
        'role': null,
        'client': null,
        'platform': null,
        'context': <String, dynamic>{},
        'key_figures': <dynamic>[],
      });

      expect(project.tagline.isEmpty, isTrue);
      expect(project.role.isEmpty, isTrue);
      expect(project.client.isEmpty, isTrue);
      expect(project.platform.isEmpty, isTrue);
      expect(project.context.isEmpty, isTrue);
      expect(project.keyFigures, isEmpty);
    });

    test('champs renseignés, dont un dans une seule langue', () {
      final project = Project.fromJson({
        ..._fullJson,
        'tagline': {'fr': 'Une accroche', 'en': 'A tagline'},
        'role': {'fr': 'Lead développeur'},
        'client': {'fr': 'Organisme public', 'en': 'Public body'},
        'platform': {'fr': 'Web · API REST', 'en': 'Web · REST API'},
        'key_figures': [
          {
            'value': '3×',
            'label': {'fr': 'plus rapide', 'en': 'faster'},
          },
          {
            'value': '40 %',
            'label': {'fr': 'de coûts en moins', 'en': 'lower costs'},
          },
        ],
      });

      expect(project.tagline.en, 'A tagline');
      expect(project.role.fr, 'Lead développeur');
      expect(project.role.en, '');
      expect(project.platform.display, 'Web · API REST');
      expect(project.keyFigures, hasLength(2));
      expect(project.keyFigures.first.value, '3×');
      expect(project.keyFigures.last.label.en, 'lower costs');
    });

    test('champs absents (ancienne réponse) : valeurs vides', () {
      final project = Project.fromJson(_fullJson);

      expect(project.tagline.isEmpty, isTrue);
      expect(project.keyFigures, isEmpty);
    });
  });
}
