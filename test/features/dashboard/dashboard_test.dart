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

  test("cv_downloads : parse le bloc de l'API, et reste à zéro s'il est absent", () {
    final dashboard = Dashboard.fromJson({
      ...json,
      'cv_downloads': {
        'total': 42,
        'period_days': 30,
        'period': 12,
        'with_email': 5,
        'by_country': [
          {'label': "Côte d'Ivoire", 'count': 7},
          {'label': 'France', 'count': 3},
        ],
        'by_origin': [
          {'label': 'linkedin.com', 'count': 6},
          {'label': 'direct', 'count': 4},
        ],
      },
    });

    expect(dashboard.cvDownloads.total, 42);
    expect(dashboard.cvDownloads.period, 12);
    expect(dashboard.cvDownloads.withEmail, 5);
    expect(dashboard.cvDownloads.byCountry.first.label, "Côte d'Ivoire");
    expect(dashboard.cvDownloads.byOrigin.last.count, 4);

    final withoutBlock = Dashboard.fromJson(json);
    expect(withoutBlock.cvDownloads.total, 0);
    expect(withoutBlock.cvDownloads.byCountry, isEmpty);
  });

  test('audience : visiteurs uniques, provenances, appareils et conversions', () {
    final dashboard = Dashboard.fromJson({
      ...json,
      'visits': {
        ...json['visits']! as Map<String, dynamic>,
        'visitors': 180,
        'by_source': [
          {'label': 'linkedin.com', 'count': 90},
          {'label': 'direct', 'count': 60},
        ],
        'by_device': [
          {'label': 'mobile', 'count': 120},
          {'label': 'desktop', 'count': 60},
        ],
      },
      'conversions': {
        'period_days': 30,
        'visitors': 180,
        'goals': [
          {'key': 'cv_downloads', 'count': 9, 'rate': 5},
          {'key': 'appointments', 'count': 2, 'rate': 1.1},
        ],
      },
    });

    expect(dashboard.visits.visitors, 180);
    expect(dashboard.visits.bySource.first.label, 'linkedin.com');
    expect(dashboard.visits.byDevice.first.count, 120);
    expect(dashboard.conversions.visitors, 180);
    expect(dashboard.conversions.goals.first.rate, 5.0);
    expect(dashboard.conversions.goals.last.label, 'Rendez-vous');

    // Ancien serveur, sans ces champs : rien ne casse.
    final legacy = Dashboard.fromJson(json);
    expect(legacy.visits.visitors, 0);
    expect(legacy.visits.bySource, isEmpty);
    expect(legacy.conversions.goals, isEmpty);
  });
}
