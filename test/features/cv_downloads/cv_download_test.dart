import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/cv_downloads/data/cv_download.dart';
import 'package:me_mobile/features/cv_downloads/data/cv_download_repository.dart';
import 'package:me_mobile/features/site_settings/data/site_settings.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

// Forme de `CvDownloadResource` côté API.
const _fullJson = {
  'id': 7,
  'job_profile_id': 2,
  'job_profile_label': {'fr': 'Développeur mobile', 'en': 'Mobile developer'},
  'locale': 'en',
  'source': 'uploaded',
  'email': 'recruteur@example.com',
  'country_code': 'CI',
  'country': "Côte d'Ivoire",
  'city': 'Abidjan',
  'referrer_host': 'linkedin.com',
  'utm_source': 'newsletter',
  'utm_medium': 'email',
  'utm_campaign': 'rentree',
  'origin': 'newsletter',
  'device': 'mobile',
  'created_at': '2026-10-01T09:30:00.000000Z',
};

const _anonymousJson = {
  'id': 8,
  'job_profile_id': null,
  'job_profile_label': null,
  'locale': 'fr',
  'source': 'generated',
  'email': null,
  'country_code': null,
  'country': null,
  'city': null,
  'referrer_host': null,
  'utm_source': null,
  'utm_medium': null,
  'utm_campaign': null,
  'origin': 'direct',
  'device': null,
  'created_at': null,
};

void main() {
  group('CvDownload.fromJson', () {
    test('parse un téléchargement complet', () {
      final download = CvDownload.fromJson(_fullJson);

      expect(download.jobProfileLabel!.fr, 'Développeur mobile');
      expect(download.locale, 'en');
      expect(download.source, CvSource.uploaded);
      expect(download.countryCode, 'CI');
      expect(download.place, "Abidjan, Côte d'Ivoire");
      expect(download.origin, 'newsletter');
      expect(download.device, CvDownloadDevice.mobile);
      expect(download.createdAt, DateTime.utc(2026, 10, 1, 9, 30));
    });

    test('accès direct anonyme, profil métier supprimé : tout reste null proprement', () {
      final download = CvDownload.fromJson(_anonymousJson);

      expect(download.jobProfileLabel, isNull);
      expect(download.source, CvSource.generated);
      expect(download.place, isNull);
      expect(download.device, isNull);
      expect(download.createdAt, isNull);
    });

    test('appareil vide ou inconnu : null', () {
      expect(CvDownload.fromJson({..._fullJson, 'device': ''}).device, isNull);
    });
  });

  group('CvDownloadRepository', () {
    late FakeDioAdapter adapter;
    late CvDownloadRepository repository;

    setUp(() {
      adapter = FakeDioAdapter();
      repository = CvDownloadRepository(
        ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
      );
    });

    test('list envoie recherche, pays et langue, et lit la pagination', () async {
      adapter.whenRequest(
        'GET',
        '/v1/cv-downloads',
        statusCode: 200,
        body: {
          'data': [_fullJson, _anonymousJson],
          'meta': {'current_page': 1, 'last_page': 3, 'per_page': 25, 'total': 60},
        },
      );

      final page = await repository.list(page: 1, search: 'abidjan', countryCode: 'CI', locale: 'en');

      final query = adapter.requests.single.queryParameters;
      expect(query['search'], 'abidjan');
      expect(query['country_code'], 'CI');
      expect(query['locale'], 'en');
      expect(page.items, hasLength(2));
      expect(page.hasMore, isTrue);
    });

    test('delete appelle DELETE /v1/cv-downloads/{id}', () async {
      adapter.whenRequest('DELETE', '/v1/cv-downloads/7', statusCode: 204);

      await repository.delete(7);

      expect(adapter.requests.single.method, 'DELETE');
    });
  });
}
