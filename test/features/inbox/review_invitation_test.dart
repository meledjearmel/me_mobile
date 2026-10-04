import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/inbox/data/review_invitation.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _json = {
  'id': 3,
  'name': null,
  'email': 'client@example.com',
  'locale': 'en',
  'url': 'https://armeldev.xyz/en/review/abc123',
  'status': 'used',
  'project_id': 7,
  'experience_id': null,
  'education_id': null,
  'subject': 'Projet : Portalfy',
  'note': 'Client 2025',
  'testimonial_id': 12,
  'expires_at': null,
  'used_at': '2026-10-04T15:00:00Z',
  'created_at': '2026-10-01T09:00:00Z',
};

void main() {
  late FakeDioAdapter adapter;
  late ReviewInvitationRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = ReviewInvitationRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('fromJson lit le lien, le statut et l\'avis reçu', () {
    final invitation = ReviewInvitation.fromJson(_json);

    expect(invitation.status, ReviewInvitationStatus.used);
    expect(invitation.testimonialId, 12);
    expect(invitation.displayName, 'client@example.com');
    expect(invitation.subject, 'Projet : Portalfy');
    expect(invitation.usedAt, isNotNull);
  });

  test('create envoie la langue, le rattachement et la date d\'expiration', () async {
    adapter.whenRequest('POST', '/v1/review-invitations', statusCode: 201, body: _json);

    final created = await repository.create(locale: 'en', name: 'Léa', projectId: 7, expiresAt: DateTime(2026, 11, 30));

    expect(adapter.requests.single.data, {
      'locale': 'en',
      'name': 'Léa',
      'email': null,
      'project_id': 7,
      'experience_id': null,
      'education_id': null,
      'note': null,
      'expires_at': '2026-11-30',
    });
    expect(created.url, 'https://armeldev.xyz/en/review/abc123');
  });

  test('list filtre par statut', () async {
    adapter.whenRequest(
      'GET',
      '/v1/review-invitations',
      statusCode: 200,
      body: {
        'data': [_json],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    await repository.list(page: 1, status: 'pending');

    expect(adapter.requests.single.queryParameters['status'], 'pending');
  });
}
