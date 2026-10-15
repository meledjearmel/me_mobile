import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:me_mobile/app/theme/app_palette_variant.dart';
import 'package:me_mobile/app/theme/app_theme.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_providers.dart';
import 'package:me_mobile/features/billing/presentation/billing_settings_screen.dart';
import 'package:me_mobile/features/billing/presentation/document_detail_screen.dart';
import 'package:me_mobile/features/billing/presentation/document_form_screen.dart';
import 'package:me_mobile/features/billing/presentation/documents_list_screen.dart';
import 'package:me_mobile/features/blog/presentation/post_distribution_screen.dart';
import 'package:me_mobile/features/blog/presentation/syndication_settings_screen.dart';
import 'package:me_mobile/features/estimator/data/estimator.dart';
import 'package:me_mobile/features/estimator/presentation/estimator_grid_screen.dart';
import 'package:me_mobile/features/estimator/presentation/estimator_item_form_screen.dart';
import 'package:me_mobile/features/estimator/presentation/estimator_items_screen.dart';
import 'package:me_mobile/features/estimator/presentation/estimator_rates_screen.dart';
import 'package:me_mobile/features/estimator/presentation/estimator_screen.dart';
import 'package:me_mobile/features/estimator/presentation/estimator_settings_screen.dart';
import 'package:me_mobile/features/job_applications/presentation/job_application_detail_screen.dart';
import 'package:me_mobile/features/job_applications/presentation/job_application_form_screen.dart';
import 'package:me_mobile/features/job_applications/presentation/job_applications_list_screen.dart';
import 'package:me_mobile/features/mcp/presentation/mcp_activity_screen.dart';
import 'package:me_mobile/features/services/presentation/service_form_screen.dart';
import 'package:me_mobile/features/services/presentation/services_list_screen.dart';
import 'package:me_mobile/features/weekly_report/presentation/weekly_report_screen.dart';

import 'helpers/fake_dio_adapter.dart';
import 'helpers/memory_token_storage.dart';

/// Affiche chaque nouvel écran sur un format de téléphone, avec une API
/// simulée, et vérifie qu'il se construit sans erreur ni débordement.

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
  'data': items,
  'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': items.length},
};

const _translated = {'fr': 'Titre un peu long pour voir si le texte déborde', 'en': 'Title'};

const _jobApplication = {
  'id': 7,
  'token': 'acme-x1y2',
  'url': 'https://armeldev.xyz/fr/candidature/acme-x1y2',
  'company': 'Acme Industries Côte d\'Ivoire',
  'contact_name': 'Awa Koné',
  'position': 'Développeur Flutter senior pour une application de paiement',
  'job_profile_id': 2,
  'cv_tailoring': {
    'title': 'Développeur mobile',
    'summary': 'Résumé',
    'experiences': {
      '3': [11, 12],
    },
    'skill_ids': [1],
    'project_ids': [5],
    'reasoning': 'Pourquoi',
  },
  'cv_tailored_at': '2026-10-01T10:00:00Z',
  'locale': 'fr',
  'intro': 'Bonjour, voir @[App Station](project:12) et @[Laravel](technology:4).\n\nMerci.',
  'job_posting_url': 'https://example.com/offre',
  'job_posting_text': 'Offre',
  'notes': 'Notes',
  'status': 'active',
  'is_open': true,
  'expires_on': '2026-12-31',
  'project_ids': [12],
  'views_count': 3,
  'cv_downloads_count': 1,
  'first_viewed_at': null,
  'last_viewed_at': '2026-10-09T08:00:00Z',
  'drafted_by': null,
  'created_at': '2026-09-30T08:00:00Z',
};

const _estimatorItem = {
  'id': 1,
  'kind': 'project_type',
  'name': _translated,
  'description': _translated,
  'hours_min': 20,
  'hours_max': 40,
  'pricing': 'hours',
  'percent': null,
  'billing': 'fixed',
  'project_type_ids': [],
  'estimator_rate_id': 3,
  'hourly_rates': {'EUR': 60},
  'is_active': true,
  'sort_order': 0,
};

final _feature = <String, dynamic>{
  ..._estimatorItem,
  'id': 2,
  'kind': 'feature',
  'pricing': 'percent',
  'percent': 15,
  'billing': null,
  'project_type_ids': [1],
};

const _rate = {
  'id': 3,
  'name': _translated,
  'hourly_rates': {'XOF': 25000, 'EUR': 40, 'USD': 45, 'CHF': 60},
  'sort_order': 0,
  'items_count': 1,
};

const _settings = {
  'estimator_hourly_rates': {'XOF': 25000, 'EUR': 40, 'USD': null, 'CHF': null},
  'estimator_risk_percent': 20,
  'estimator_hours_per_week': 30,
};

const _service = {
  'id': 4,
  'slug': 'site-vitrine',
  'title': _translated,
  'tagline': _translated,
  'description': _translated,
  'includes': {'fr': 'Design\nHébergement', 'en': ''},
  'price_mode': 'manual',
  'estimator_item_id': null,
  'manual_prices': {'XOF': 500000},
  'project_ids': [12],
  'status': 'draft',
  'drafted_by': 'Claude Code',
  'sort_order': 1,
};

const _document = {
  'id': 3,
  'type': 'quote',
  'status': 'issued',
  'number': 'ADEV-DEV-2026-001',
  'engagement_id': 5,
  'source_id': null,
  'locale': 'fr',
  'client_name': 'Awa Koné',
  'client_email': 'awa@acme.ci',
  'client_company': 'Acme Industries Côte d\'Ivoire',
  'client_address': 'Abidjan, Plateau',
  'title': 'Refonte du site vitrine et de l\'espace client',
  'currency': 'XOF',
  'lines': [
    {'label': 'Développement', 'description': 'Front et back', 'quantity': 40, 'unit': 'hour', 'unit_price': 25000},
    {'label': 'Mise en ligne', 'description': null, 'quantity': 1, 'unit': 'flat', 'unit_price': 50000},
  ],
  'total': 1050000,
  'deposit_percent': 30,
  'deposit_amount': 315000,
  'payment_terms': 'À 30 jours',
  'notes': 'Notes',
  'issued_at': '2026-10-01',
  'valid_until': '2026-10-31',
  'due_at': null,
  'public_url': 'https://armeldev.xyz/devis/abc',
  'sent_at': '2026-10-01T10:00:00Z',
  'accepted_at': null,
  'declined_at': null,
  'paid_at': null,
  'reminders_count': 1,
  'last_reminded_at': '2026-10-08T10:00:00Z',
  'reminder_due_at': '2026-10-12T10:00:00Z',
  'created_at': '2026-09-30T10:00:00Z',
};

const _kit = {
  'url': 'https://armeldev.xyz/fr/blog/mon-article',
  'image': 'https://armeldev.xyz/share.png',
  'texts': {'linkedin': 'Mon article', 'x': null, 'facebook': null, 'whatsapp': null},
  'links': {
    'linkedin': 'https://www.linkedin.com/feed/',
    'x': 'https://x.com/intent/post',
    'facebook': 'https://www.facebook.com/sharer/sharer.php',
    'whatsapp': 'https://wa.me/',
  },
};

FakeDioAdapter _adapter() => FakeDioAdapter()
  ..whenRequest('GET', '/v1/projects', statusCode: 200, body: _page([
    {'id': 12, 'title': _translated},
  ]))
  ..whenRequest('GET', '/v1/job-profiles', statusCode: 200, body: _page([
    {'id': 2, 'label': _translated},
  ]))
  ..whenRequest('GET', '/v1/job-applications', statusCode: 200, body: _page([_jobApplication]))
  ..whenRequest('GET', '/v1/job-applications/7', statusCode: 200, body: _jobApplication)
  ..whenRequest('GET', '/v1/job-applications/7/events', statusCode: 200, body: {
    'data': [
      {'id': 1, 'type': 'view', 'city': 'Abidjan', 'country': 'Côte d\'Ivoire', 'device': 'mobile', 'created_at': '2026-10-09T08:00:00Z'},
      {'id': 2, 'type': 'cv_download', 'created_at': '2026-10-09T09:00:00Z'},
    ],
  })
  ..whenRequest('GET', '/v1/estimator-settings', statusCode: 200, body: _settings)
  ..whenRequest('GET', '/v1/estimator-rates', statusCode: 200, body: _page([_rate]))
  ..whenRequest('GET', '/v1/estimator-items', statusCode: 200, body: _page([_estimatorItem, _feature]))
  ..whenRequest('GET', '/v1/services', statusCode: 200, body: _page([_service]))
  ..whenRequest('GET', '/v1/weekly-report', statusCode: 200, body: {
    'enabled': true,
    'sent_at': null,
    'report': {
      'period': {'from': '2026-10-07', 'to': '2026-10-14'},
      'audience': {'visits': 120, 'visitors': 80, 'previous_visits': 100, 'change': 20, 'top_content': [], 'sources': []},
      'requests': {'total': 1, 'contacts': 1, 'freelance': 0, 'hiring': 0, 'appointments': 0, 'upcoming_appointments': 0, 'estimates': []},
      'applications': {'created': 0, 'viewed': []},
      'cv_downloads': 2,
      'blog': {'published': 0, 'comments': 0, 'reactions': 0, 'new_subscribers': 0, 'subscribers': 10},
      'todo': [],
      'highlights': null,
    },
  })
  ..whenRequest('GET', '/v1/mcp-activity', statusCode: 200, body: {
    'data': [
      {
        'id': 1,
        'client': 'Claude Code',
        'kind': 'tool',
        'name': 'get-project',
        'title': 'Lire un projet',
        'target': {'label': 'App Station', 'url': null},
        'success': false,
        'error': 'Introuvable',
        'duration_ms': 42,
        'created_at': '2026-10-14T08:00:00+00:00',
      },
    ],
    'current_page': 1,
    'last_page': 1,
    'per_page': 25,
    'total': 1,
    'filters': {
      'clients': ['Claude Code'],
      'tools': [
        {'value': 'get-project', 'label': 'Lire un projet'},
      ],
    },
  })
  ..whenRequest('GET', '/v1/commercial-documents', statusCode: 200, body: _page([_document]))
  ..whenRequest('GET', '/v1/commercial-documents/3', statusCode: 200, body: _document)
  ..whenRequest('GET', '/v1/billing-settings', statusCode: 200, body: {'billing_business_name': 'Armel Dev', 'billing_deposit_percent': 30})
  ..whenRequest('GET', '/v1/syndication', statusCode: 200, body: {
    'devto': {'mode': 'manual', 'has_key': true, 'locale': 'en', 'auto_since': null},
    'hashnode': {'mode': 'off', 'has_key': false, 'locale': 'fr', 'auto_since': null, 'publication_id': null},
  })
  ..whenRequest('GET', '/v1/posts/9/syndications', statusCode: 200, body: {
    'syndications': [
      {'platform': 'devto', 'status': 'failed', 'external_url': null, 'locale': 'en', 'error': 'Clé refusée', 'published_at': null},
    ],
    'social': {'fr': _kit, 'en': _kit},
  });

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<void> pump(WidgetTester tester, Widget screen) async {
    // Un téléphone courant : 390 × 844 points.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(
            ApiClient(baseUrl: 'https://me.test/api', tokens: MemoryTokenStorage(), adapter: _adapter()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(AppPaletteVariant.values.first, Brightness.light),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final screens = <String, (Widget, String)>{
    'Candidatures : liste': (const JobApplicationsListScreen(), 'Acme Industries Côte d\'Ivoire'),
    'Candidatures : fiche': (const JobApplicationDetailScreen(id: 7), 'Lien privé'),
    'Candidatures : formulaire': (const JobApplicationFormScreen(), 'Nouvelle candidature'),
    'Candidatures : modification': (const JobApplicationFormScreen(id: 7), 'Modifier la candidature'),
    'Estimateur : accueil': (const EstimatorScreen(), 'Estimateur'),
    'Estimateur : tarifs': (const EstimatorSettingsScreen(), 'Tarifs'),
    'Estimateur : grilles': (const EstimatorRatesScreen(), 'Grilles tarifaires'),
    'Estimateur : types': (const EstimatorItemsScreen(kind: EstimatorItemKind.projectType), 'Types de projet'),
    'Estimateur : options': (const EstimatorItemsScreen(kind: EstimatorItemKind.feature), 'Options'),
    'Estimateur : nouvelle option': (const EstimatorItemFormScreen(kind: EstimatorItemKind.feature), 'Nouvelle option'),
    'Estimateur : proposition IA': (const EstimatorGridScreen(), 'Proposer une grille'),
    'Services : liste': (const ServicesListScreen(), 'Services'),
    'Services : formulaire': (const ServiceFormScreen(), 'Nouvelle offre'),
    'Rapport de la semaine': (const WeeklyReportScreen(), 'Rapport de la semaine'),
    'Activité MCP': (const McpActivityScreen(), 'Lire un projet'),
    'Devis et factures : liste': (const DocumentsListScreen(), 'Devis et factures'),
    'Devis et factures : fiche': (const DocumentDetailScreen(id: 3), 'Relance suggérée'),
    'Devis et factures : brouillon': (const DocumentFormScreen(), 'Devis : brouillon'),
    'Réglages de facturation': (const BillingSettingsScreen(), 'Facturation'),
    'Republication : réglages': (const SyndicationSettingsScreen(), 'Republication'),
    'Article : diffusion': (const PostDistributionScreen(postId: 9, title: 'Mon article', isPublished: true), 'Diffusion'),
  };

  for (final MapEntry(key: name, value: (screen, expected)) in screens.entries) {
    testWidgets('$name s\'affiche sans erreur sur un téléphone', (tester) async {
      await pump(tester, screen);

      expect(find.text(expected, skipOffstage: false), findsWidgets);
    });
  }
}
