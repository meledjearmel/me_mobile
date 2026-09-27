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
};

void main() {
  test('JobProfile.fromJson analyse les 5 champs bilingues', () {
    final jobProfile = JobProfile.fromJson(_jobProfileJson);
    expect(jobProfile.label.fr, 'Lead technique');
    expect(jobProfile.heroTitle.fr, 'Lead');
  });

  late FakeDioAdapter adapter;
  late JobProfileRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = JobProfileRepository(
      ApiClient(baseUrl: 'https://me.armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('save envoie les 5 champs bilingues', () async {
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

    final body = adapter.requests.single.data as Map;
    expect(body['label'], {'fr': 'Lead technique', 'en': 'Tech lead'});
    expect(body['hero_title'], {'fr': 'Lead', 'en': 'Lead'});
  });
}
