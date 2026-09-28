import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/features/dashboard/data/dashboard.dart';

void main() {
  // Reflète le contrat décrit dans le cahier des charges (§4.1), plus fiable
  // ici que la spec OpenAPI générée qui réduit les tableaux hétérogènes à
  // `array of string` (limite connue de Scramble sur ce projet).
  final json = {
    'todo': {'contacts': 2, 'engagements': 1, 'testimonials': 3},
    'visits': {
      'total': 540,
      'period_days': 30,
      'period': 540,
      'today': 12,
      'french': 300,
      'english': 240,
      'daily': [
        {'date': '2026-09-01', 'count': 10},
        {'date': '2026-09-02', 'count': 15},
      ],
      'top_pages': [
        {'path': '/fr', 'count': 200},
        {'path': '/fr/projets', 'count': 90},
      ],
    },
    'content': {
      'projects': {'published': 8, 'archived': 2, 'featured': 3, 'open_source': 4},
      'skills': 12,
      'technologies': 30,
      'domains': 5,
      'experiences': 4,
      'educations': 2,
      'references_on_cv': 3,
      'years_of_experience': 7,
      'testimonials': {'approved': 5, 'pending': 3, 'rejected': 1, 'featured': 2},
      'contacts': 20,
      'engagements': {'freelance': 6, 'hiring': 4, 'cv_sent': 3},
      'congratulations': 9,
    },
    'distribution': {
      'projects_by_domain': [
        {'label': 'Web', 'color': '#3b82f6', 'count': 5},
      ],
      'skills_by_domain': [
        {'label': 'Backend', 'color': '#22c55e', 'count': 4},
      ],
      'technologies_by_category': [
        {'label': 'Langages', 'count': 6},
      ],
    },
    'health': [
      {'key': 'profile_photo', 'ok': true, 'count': 0},
      {'key': 'cv_photo', 'ok': false, 'count': 0},
      // `ok` vu en chaîne dans la spec générée pour cv_identity : doit rester tolérant.
      {'key': 'cv_identity', 'ok': 'true', 'count': 0},
      {'key': 'cv_references', 'ok': false, 'count': 1},
      {'key': 'project_covers', 'ok': false, 'count': 2},
      {'key': 'featured_testimonials', 'ok': true, 'count': 3},
    ],
    'recent': {
      'contacts': [
        {'id': 1, 'name': 'Jeanne', 'subject': 'Une question', 'is_new': true, 'at': '2026-09-27T10:00:00Z'},
      ],
      'engagements': [
        {
          'id': 2,
          'name': 'Paul',
          'company': 'Acme',
          'type': 'hiring',
          'subject': 'Lead dev',
          'is_new': false,
          'at': '2026-09-26T10:00:00Z',
        },
      ],
      'testimonials': [
        {'id': 3, 'name': 'Alice', 'excerpt': 'Super travail…', 'at': '2026-09-25T10:00:00Z'},
      ],
    },
  };

  test('parse le tableau de bord complet depuis le JSON documenté', () {
    final dashboard = Dashboard.fromJson(json);

    expect(dashboard.todo.total, 6);
    expect(dashboard.visits.daily, hasLength(2));
    expect(dashboard.visits.topPages, hasLength(2));
    expect(dashboard.visits.topPages.first.path, '/fr');
    expect(dashboard.content.projects.published, 8);
    expect(dashboard.content.testimonials.pending, 3);
    expect(dashboard.distribution.skillsByDomain.single.color, '#22c55e');
    expect(dashboard.distribution.technologiesByCategory.single.label, 'Langages');
    expect(dashboard.recent.contacts.single.name, 'Jeanne');
    expect(dashboard.recent.engagements.single.company, 'Acme');
    expect(dashboard.recent.testimonials.single.excerpt, 'Super travail…');
  });

  test('ok tolère un booléen ou une chaîne "true"/"1"', () {
    final dashboard = Dashboard.fromJson(json);
    final byKey = {for (final h in dashboard.health) h.key: h};

    expect(byKey['profile_photo']!.ok, isTrue);
    expect(byKey['cv_photo']!.ok, isFalse);
    expect(byKey['cv_identity']!.ok, isTrue);
  });
}
