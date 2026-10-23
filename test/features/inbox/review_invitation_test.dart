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
  'collective': false,
  'max_uses': 1,
  'uses_count': 1,
  'subjects': [
    {'type': 'project', 'id': 7, 'label': 'Portalfy', 'slug': 'portalfy'},
    {'type': 'experience', 'id': 2, 'label': 'Développeur — Acme', 'slug': null},
  ],
  'subject': 'Portalfy · Développeur — Acme',
  'note': 'Client 2025',
  'testimonial_ids': [12],
  'testimonial_id': 12,
  'expires_at': null,
  'used_at': '2026-10-04T15:00:00Z',
  'created_at': '2026-10-01T09:00:00Z',
};

const _collective = {
  'id': 4,
  'name': null,
  'email': null,
  'locale': 'fr',
  'url': 'https://armeldev.xyz/fr/review/team',
  'status': 'pending',
  'collective': true,
  'max_uses': 10,
  'uses_count': 3,
  'subjects': <dynamic>[],
  'subject': null,
  'note': null,
  'testimonial_ids': [20, 21, 22],
  'testimonial_id': 20,
  'expires_at': null,
  'used_at': null,
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

  test('fromJson lit le lien, le statut, les sujets et les avis reçus', () {
    final invitation = ReviewInvitation.fromJson(_json);

    expect(invitation.status, ReviewInvitationStatus.used);
    expect(invitation.testimonialIds, [12]);
    expect(invitation.collective, isFalse);
    expect(invitation.displayName, 'client@example.com');
    expect(invitation.subjects.map((s) => s.type), ['project', 'experience']);
    expect(invitation.subjects.first.slug, 'portalfy');
    expect(invitation.usedAt, isNotNull);
  });

  test('lien collectif : libellé et compteur', () {
    final invitation = ReviewInvitation.fromJson(_collective);

    expect(invitation.displayName, 'Lien collectif');
    expect(invitation.usesLabel, '3 / 10 avis');
    expect(ReviewInvitation.fromJson({..._collective, 'max_uses': null}).usesLabel, '3 avis');
  });

  test('ancienne réponse sans les nouveaux champs : valeurs par défaut', () {
    final invitation = ReviewInvitation.fromJson({
      'id': 1,
      'url': 'https://armeldev.xyz/fr/review/x',
      'status': 'used',
      'subject': 'Projet : Portalfy',
      'testimonial_id': 9,
      'name': null,
      'email': null,
      'note': null,
    });

    expect(invitation.collective, isFalse);
    expect(invitation.subjects, isEmpty);
    expect(invitation.testimonialIds, [9]);
    expect(invitation.maxUses, isNull);
  });

  test('create envoie la langue, les rattachements et la date d\'expiration', () async {
    adapter.whenRequest('POST', '/v1/review-invitations', statusCode: 201, body: _json);

    final created = await repository.create(
      locale: 'en',
      name: 'Léa',
      projectIds: [7, 8],
      expiresAt: DateTime(2026, 11, 30),
    );

    expect(adapter.requests.single.data, {
      'locale': 'en',
      'collective': false,
      'name': 'Léa',
      'email': null,
      'project_ids': [7, 8],
      'experience_ids': <int>[],
      'education_ids': <int>[],
      'note': null,
      'expires_at': '2026-11-30',
    });
    expect(created.url, 'https://armeldev.xyz/en/review/abc123');
  });

  test('create d\'un lien collectif : limite, sans nom ni e-mail', () async {
    adapter.whenRequest('POST', '/v1/review-invitations', statusCode: 201, body: _collective);

    await repository.create(locale: 'fr', name: 'Ignoré', collective: true, maxUses: 10);

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data['collective'], isTrue);
    expect(data['max_uses'], 10);
    expect(data.containsKey('name'), isFalse);
    expect(data.containsKey('email'), isFalse);
  });

  test('list filtre par statut', () async {
    adapter.whenRequest(
      'GET',
      '/v1/review-invitations',
      statusCode: 200,
      body: {
        'data': [_json, _collective],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 2},
      },
    );

    await repository.list(page: 1, status: 'pending');

    expect(adapter.requests.single.queryParameters['status'], 'pending');
  });
}
