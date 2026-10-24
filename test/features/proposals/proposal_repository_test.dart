import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/proposals/data/proposal.dart';
import 'package:me_mobile/features/proposals/data/proposal_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _proposalJson = {
  'id': 4,
  'platform': 'upwork',
  'locale': 'en',
  'job_title': 'Flutter developer for a fintech app',
  'client_name': 'John',
  'job_url': 'https://www.upwork.com/jobs/~01',
  'job_posting': 'We need a Flutter dev.',
  'body': 'Hi John,\n\nI built a payment app.',
  'screening_answers': 'Yes, 5 years.',
  'bid': '40 \$/h',
  'connects': 16,
  'status': 'interview',
  'notes': 'Relancer lundi',
  'drafted_by': 'Claude Code',
  'sent_at': '2026-10-20T09:00:00Z',
  'created_at': '2026-10-19T09:00:00Z',
  'updated_at': '2026-10-21T09:00:00Z',
};

void main() {
  test('Proposal.fromJson lit les champs, la plateforme et le statut', () {
    final proposal = Proposal.fromJson(_proposalJson);
    expect(proposal.platform, ProposalPlatform.upwork);
    expect(proposal.status, ProposalStatus.interview);
    expect(proposal.status.isHighlighted, isTrue);
    expect(proposal.connects, 16);
    expect(proposal.draftedBy, 'Claude Code');
    expect(proposal.sentAt, DateTime.utc(2026, 10, 20, 9).toLocal());
    expect(proposal.platformLine, 'Upwork · EN');
  });

  test('Proposal.fromJson tolère les champs facultatifs absents', () {
    final proposal = Proposal.fromJson({
      'id': 5,
      'platform': 'inconnue',
      'locale': 'fr',
      'job_title': 'Site vitrine',
      'body': 'Bonjour',
      'status': 'draft',
    });
    expect(proposal.platform, ProposalPlatform.other);
    expect(proposal.sentAt, isNull);
    expect(proposal.connects, isNull);
    expect(proposal.status.isHighlighted, isFalse);
    expect(proposal.clipboardText, 'Bonjour');
  });

  test('clipboardText ajoute les réponses aux questions après la proposition', () {
    expect(Proposal.fromJson(_proposalJson).clipboardText, 'Hi John,\n\nI built a payment app.\n\nYes, 5 years.');
  });

  late FakeDioAdapter adapter;
  late ProposalRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = ProposalRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list envoie la recherche, la plateforme et le statut', () async {
    adapter.whenRequest(
      'GET',
      '/v1/proposals',
      statusCode: 200,
      body: {
        'data': [_proposalJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    final page = await repository.list(page: 1, search: 'flutter', platform: 'malt', status: 'sent');

    expect(page.items.single.jobTitle, 'Flutter developer for a fintech app');
    final query = adapter.requests.single.queryParameters;
    expect(query['search'], 'flutter');
    expect(query['platform'], 'malt');
    expect(query['status'], 'sent');
    expect(query['per_page'], 25);
  });

  test('save crée en POST et vide les champs facultatifs blancs', () async {
    adapter.whenRequest('POST', '/v1/proposals', statusCode: 201, body: _proposalJson);

    await repository.save(
      platform: ProposalPlatform.upwork,
      locale: 'fr',
      jobTitle: 'Site vitrine',
      clientName: '  ',
      body: 'Bonjour',
      connects: 8,
      status: ProposalStatus.draft,
    );

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data['platform'], 'upwork');
    expect(data['client_name'], isNull);
    expect(data['connects'], 8);
    expect(data['status'], 'draft');
  });

  test('updateStatus renvoie l\'objet complet en PUT avec le nouveau statut', () async {
    adapter.whenRequest('PUT', '/v1/proposals/4', statusCode: 200, body: {..._proposalJson, 'status': 'hired'});

    final saved = await repository.updateStatus(Proposal.fromJson(_proposalJson), ProposalStatus.hired);

    expect(saved.status, ProposalStatus.hired);
    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    final data = request.data as Map<String, dynamic>;
    expect(data['status'], 'hired');
    expect(data['job_title'], 'Flutter developer for a fintech app');
    expect(data['body'], 'Hi John,\n\nI built a payment app.');
    expect(data['screening_answers'], 'Yes, 5 years.');
    expect(data['bid'], '40 \$/h');
    expect(data['connects'], 16);
    expect(data['notes'], 'Relancer lundi');
    expect(data['locale'], 'en');
  });

  test('delete envoie DELETE', () async {
    adapter.whenRequest('DELETE', '/v1/proposals/4', statusCode: 204);

    await repository.delete(4);

    expect(adapter.requests.single.method, 'DELETE');
  });
}
