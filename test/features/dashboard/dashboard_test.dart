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

  test("estimator : visiteurs, demandes, montants par devise et écart avec l'IA", () {
    final dashboard = Dashboard.fromJson({
      ...json,
      'estimator': {
        'period_days': 30,
        'since': '2026-09-14',
        'page_visitors': 40,
        'requests': 6,
        'conversion_rate': 15.0,
        'by_currency': [
          {
            'currency': 'XOF',
            'count': 4,
            'price_min': 2000000,
            'price_max': 3200000,
            'average_min': 500000,
            'average_max': 800000,
          },
        ],
        'billing': {'fixed': 5, 'hourly': 1},
        'project_types': [
          {'label': 'Site vitrine', 'count': 4},
        ],
        'features': [
          {'label': 'Multilingue', 'count': 3},
        ],
        'rate_grids': [
          {'label': 'Taux global ou propre', 'count': 6},
        ],
        'ai_gap': {'analysed': 5, 'hours_gap_percent': 18.4},
      },
    });

    final estimator = dashboard.estimator;
    expect(estimator.isEmpty, isFalse);
    expect(estimator.conversionRate, 15.0);
    expect(estimator.byCurrency.single.averageMax, 800000);
    expect(estimator.fixed, 5);
    expect(estimator.projectTypes.single.label, 'Site vitrine');
    expect(estimator.aiHoursGapPercent, 18.4);

    // Sans le bloc (API plus ancienne) : vide, la section ne s'affiche pas.
    expect(Dashboard.fromJson(json).estimator.isEmpty, isTrue);
  });

  test('outcomes, appointments et billing : résultats, rendez-vous et facturation', () {
    final dashboard = Dashboard.fromJson({
      ...json,
      'outcomes': {
        'period_days': 30,
        'won': 3,
        'lost': 1,
        'win_rate': 75.0,
        'by_currency': [
          {'currency': 'XOF', 'count': 3, 'amount': 2400000, 'average': 800000},
        ],
        'estimate_gap': {'compared': 2, 'gap_percent': -8.5},
      },
      'appointments': {
        'period_days': 30,
        'total': 6,
        'by_status': {'pending': 1, 'confirmed': 3, 'declined': 1, 'cancelled': 1},
        'confirmation_rate': 75.0,
        'response_hours': 0.5,
        'by_type': [
          {'label': 'Appel découverte', 'count': 6},
        ],
        'by_location': [
          {'label': 'video', 'count': 4},
          {'label': 'phone', 'count': 2},
        ],
      },
      'billing': {
        'period_days': 30,
        'by_currency': [
          {'currency': 'EUR', 'invoiced': 5000, 'collected': 3000, 'outstanding': 2000, 'overdue': 500},
        ],
        'quotes': {'issued': 4, 'accepted': 2, 'declined': 1, 'acceptance_rate': 66.7},
        'overdue_invoices': [
          {
            'id': 9,
            'number': 'F-2026-012',
            'client': 'Acme',
            'total': 500,
            'currency': 'EUR',
            'due_at': '2026-10-01',
            'days_late': 13,
          },
        ],
      },
    });

    expect(dashboard.outcomes.winRate, 75.0);
    expect(dashboard.outcomes.byCurrency.single.average, 800000);
    expect(dashboard.outcomes.estimateGapPercent, -8.5);
    expect(dashboard.appointments.confirmed, 3);
    expect(dashboard.appointments.responseHours, 0.5);
    expect(dashboard.appointments.byLocation.first.label, 'video');
    expect(dashboard.billing.byCurrency.single.overdue, 500);
    expect(dashboard.billing.acceptanceRate, 66.7);
    expect(dashboard.billing.overdueInvoices.single.dueAt, DateTime(2026, 10, 1));

    // Sans ces blocs (API plus ancienne) : sections masquées.
    final legacy = Dashboard.fromJson(json);
    expect(legacy.outcomes.isEmpty && legacy.appointments.isEmpty && legacy.billing.isEmpty, isTrue);
  });
}
