import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/job_applications/data/job_application.dart';
import 'package:me_mobile/features/job_applications/data/job_application_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _applicationJson = {
  'id': 7,
  'token': 'acme-x1y2',
  'url': 'https://armeldev.xyz/fr/candidature/acme-x1y2',
  'company': 'Acme',
  'contact_name': 'Awa Koné',
  'position': 'Développeur Flutter',
  'job_profile_id': 2,
  'cv_tailoring': {
    'title': 'Développeur mobile',
    'summary': 'Résumé',
    'experiences': {
      '3': [11, 12],
      '4': [20],
    },
    'skill_ids': [1, 2],
    'project_ids': [5],
    'reasoning': 'Pourquoi',
  },
  'cv_tailored_at': '2026-10-01T10:00:00Z',
  'locale': 'fr',
  'intro': 'Bonjour, voir @[App Station](project:12).',
  'job_posting_url': null,
  'job_posting_text': 'Offre',
  'notes': null,
  'status': 'active',
  'is_open': false,
  'expires_on': '2026-10-10',
  'project_ids': [12, 5],
  'views_count': 3,
  'cv_downloads_count': 1,
  'first_viewed_at': null,
  'last_viewed_at': '2026-10-09T08:00:00Z',
  'drafted_by': 'Claude Code',
  'created_at': '2026-09-30T08:00:00Z',
};

void main() {
  test('JobApplication.fromJson lit les compteurs, le CV adapté et repère une page expirée', () {
    final application = JobApplication.fromJson(_applicationJson);
    expect(application.status, JobApplicationStatus.active);
    expect(application.isExpired, isTrue);
    expect(application.expiresOn, DateTime(2026, 10, 10));
    expect(application.projectIds, [12, 5]);
    expect(application.cvTailoring!.highlightsCount, 3);
    expect(application.cvTailoring!.experiences['3'], [11, 12]);
    expect(application.isTailored, isTrue);
  });

  test('JobApplicationEvent.place assemble la ville et le pays connus', () {
    final event = JobApplicationEvent.fromJson({
      'id': 1,
      'type': 'cv_download',
      'city': 'Abidjan',
      'country': "Côte d'Ivoire",
    });
    expect(event.type, JobApplicationEventType.cvDownload);
    expect(event.place, "Abidjan, Côte d'Ivoire");
    expect(JobApplicationEvent.fromJson({'id': 2, 'type': 'view'}).place, isNull);
  });

  late FakeDioAdapter adapter;
  late JobApplicationRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = JobApplicationRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list envoie la recherche et le statut', () async {
    adapter.whenRequest(
      'GET',
      '/v1/job-applications',
      statusCode: 200,
      body: {
        'data': [_applicationJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    final page = await repository.list(page: 1, search: 'acme', status: 'active');

    expect(page.items.single.company, 'Acme');
    final query = adapter.requests.single.queryParameters;
    expect(query['search'], 'acme');
    expect(query['status'], 'active');
  });

  test('save crée en POST avec les projets ordonnés et la date au format AAAA-MM-JJ', () async {
    adapter.whenRequest('POST', '/v1/job-applications', statusCode: 201, body: _applicationJson);

    await repository.save(
      company: 'Acme',
      contactName: '  ',
      position: 'Développeur Flutter',
      locale: 'fr',
      intro: 'Bonjour',
      status: JobApplicationStatus.draft,
      expiresOn: DateTime(2026, 11, 3),
      projectIds: [12, 5],
    );

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data['project_ids'], [12, 5]);
    expect(data['expires_on'], '2026-11-03');
    expect(data['contact_name'], isNull);
    expect(data['status'], 'draft');
  });

  test('save modifie en PUT', () async {
    adapter.whenRequest('PUT', '/v1/job-applications/7', statusCode: 200, body: _applicationJson);

    await repository.save(
      id: 7,
      company: 'Acme',
      position: 'Développeur Flutter',
      locale: 'fr',
      intro: 'Bonjour',
      status: JobApplicationStatus.active,
    );

    expect(adapter.requests.single.method, 'PUT');
  });

  test('events lit l\'historique', () async {
    adapter.whenRequest(
      'GET',
      '/v1/job-applications/7/events',
      statusCode: 200,
      body: {
        'data': [
          {'id': 1, 'type': 'view', 'city': 'Paris', 'country': 'France', 'created_at': '2026-10-09T08:00:00Z'},
        ],
      },
    );

    final events = await repository.events(7);

    expect(events.single.place, 'Paris, France');
  });

  test('tailorCv, updateCv et resetCv appellent les routes du CV', () async {
    adapter
      ..whenRequest('POST', '/v1/job-applications/7/cv/tailor', statusCode: 200, body: _applicationJson)
      ..whenRequest('PUT', '/v1/job-applications/7/cv', statusCode: 200, body: _applicationJson)
      ..whenRequest(
        'DELETE',
        '/v1/job-applications/7/cv',
        statusCode: 200,
        body: {..._applicationJson, 'cv_tailoring': null},
      );

    await repository.tailorCv(7);
    await repository.updateCv(7, title: 'Titre', summary: null);
    final reset = await repository.resetCv(7);

    expect(adapter.requests[1].data, {'title': 'Titre', 'summary': null});
    expect(reset.isTailored, isFalse);
  });

  test('draftWithAi envoie l\'offre et la langue, et lit la proposition', () async {
    adapter.whenRequest(
      'POST',
      '/v1/ai/draft-job-application',
      statusCode: 200,
      body: {
        'application': {
          'company': 'Acme',
          'contact_name': null,
          'position': 'Dev',
          'intro': 'Bonjour',
          'project_ids': [3, 1],
          'job_profile_id': 2,
          'reasoning': 'Parce que',
        },
      },
    );

    final draft = await repository.draftWithAi(jobPosting: '  Offre  ', locale: 'en');

    expect(adapter.requests.single.data, {'job_posting': 'Offre', 'locale': 'en'});
    expect(draft.projectIds, [3, 1]);
    expect(draft.jobProfileId, 2);
  });
}
