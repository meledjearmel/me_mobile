import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/publication_status.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/content/job_profiles/data/job_profile.dart';
import 'package:me_mobile/features/content/job_profiles/data/job_profile_repository.dart';

import '../../../helpers/fake_dio_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

const _jobProfileJson = {
  'id': 1,
  'key': 'lead',
  'label': {'fr': 'Lead technique', 'en': 'Tech lead'},
  'description': {'fr': 'Description', 'en': 'Description'},
  'hero_title': {'fr': 'Lead', 'en': 'Lead'},
  'hero_words': {'fr': '', 'en': ''},
  'cv_description': {'fr': 'CV', 'en': 'CV'},
  'sort_order': 1,
  'status': 'published',
  'cv_files': {
    'fr': {'file_name': 'cv-fr.pdf', 'url': 'https://me.armeldev.xyz/cv/cv-fr.pdf'},
    'en': null,
  },
};

Map<String, String> _fieldMap(FormData form) => {for (final e in form.fields) e.key: e.value};

void main() {
  test('JobProfile.fromJson analyse les 5 champs bilingues et les CV par langue', () {
    final jobProfile = JobProfile.fromJson(_jobProfileJson);
    expect(jobProfile.label.fr, 'Lead technique');
    expect(jobProfile.heroTitle.fr, 'Lead');
    expect(jobProfile.cvFiles.fr!.fileName, 'cv-fr.pdf');
    expect(jobProfile.cvFiles.en, isNull);
  });

  late FakeDioAdapter adapter;
  late JobProfileRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = JobProfileRepository(
      ApiClient(baseUrl: 'https://me.armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('save envoie un POST multipart avec les 5 champs bilingues', () async {
    adapter.whenRequest('POST', '/v1/job-profiles', statusCode: 200, body: _jobProfileJson);

    await repository.save(
      key: 'lead',
      label: const Translated(fr: 'Lead technique', en: 'Tech lead'),
      description: const Translated(fr: 'Description', en: 'Description'),
      heroTitle: const Translated(fr: 'Lead', en: 'Lead'),
      heroWords: const Translated(),
      cvDescription: const Translated(fr: 'CV', en: 'CV'),
      sortOrder: 1,
      status: PublicationStatus.published,
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    final fields = _fieldMap(request.data as FormData);
    expect(fields['label[fr]'], 'Lead technique');
    expect(fields['hero_title[fr]'], 'Lead');
    expect(fields.containsKey('_method'), isFalse);
  });

  test('save en édition envoie _method=PUT avec les fichiers CV', () async {
    adapter.whenRequest('POST', '/v1/job-profiles/1', statusCode: 200, body: _jobProfileJson);

    await repository.save(
      id: 1,
      key: 'lead',
      label: const Translated(fr: 'Lead technique', en: 'Tech lead'),
      description: const Translated(fr: 'Description', en: 'Description'),
      heroTitle: const Translated(fr: 'Lead', en: 'Lead'),
      heroWords: const Translated(),
      cvDescription: const Translated(fr: 'CV', en: 'CV'),
      sortOrder: 1,
      status: PublicationStatus.published,
      cvFileFr: MultipartFile.fromBytes([1, 2, 3], filename: 'cv-fr.pdf'),
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/job-profiles/1');
    final form = request.data as FormData;
    expect(_fieldMap(form)['_method'], 'PUT');
    expect(form.files.single.key, 'cv_file_fr');
  });

  test('deleteCv appelle DELETE /v1/job-profiles/{id}/cv/{locale} et renvoie le profil métier', () async {
    adapter.whenRequest('DELETE', '/v1/job-profiles/1/cv/fr', statusCode: 200, body: _jobProfileJson);

    final jobProfile = await repository.deleteCv(1, 'fr');

    expect(adapter.requests.single.path, '/v1/job-profiles/1/cv/fr');
    expect(jobProfile.key, 'lead');
  });
}
