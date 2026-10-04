import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/publication_status.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/content/certifications/data/certification.dart';
import 'package:me_mobile/features/content/certifications/data/certification_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _json = {
  'id': 5,
  'kind': 'course',
  'name': {'fr': 'Laravel avancé', 'en': 'Advanced Laravel'},
  'issuer': 'Laracasts',
  'issued_on': '2025-06-12',
  'expires_on': '2020-01-01',
  'credential_id': null,
  'credential_url': 'https://laracasts.com/c/1',
  'badge_url': null,
  'status': 'published',
  'sort_order': 0,
};

void main() {
  late FakeDioAdapter adapter;
  late CertificationRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = CertificationRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('fromJson lit le type, les dates et le lien de vérification', () {
    final c = Certification.fromJson(_json);

    expect(c.kind, CertificationKind.course);
    expect(c.issuedOn, DateTime(2025, 6, 12));
    expect(c.isExpired, isTrue);
    expect(c.credentialUrl, 'https://laracasts.com/c/1');
  });

  test('save : multipart, dates Y-m-d, _method=PUT en modification', () async {
    adapter.whenRequest('POST', '/v1/certifications/5', statusCode: 200, body: _json);

    await repository.save(
      id: 5,
      kind: CertificationKind.certification,
      name: const Translated(fr: 'AWS SA', en: 'AWS SA'),
      issuer: 'AWS',
      issuedOn: DateTime(2025, 3, 4),
      expiresOn: null,
      credentialId: 'ABC',
      credentialUrl: null,
      status: PublicationStatus.draft,
      sortOrder: 2,
    );

    final fields = {for (final f in (adapter.requests.single.data as FormData).fields) f.key: f.value};
    expect(fields['_method'], 'PUT');
    expect(fields['kind'], 'certification');
    expect(fields['issued_on'], '2025-03-04');
    expect(fields['expires_on'], '');
    expect(fields['name[en]'], 'AWS SA');
    expect(fields['status'], 'draft');
  });
}
