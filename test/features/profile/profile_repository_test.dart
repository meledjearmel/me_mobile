import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/profile/data/profile.dart';
import 'package:me_mobile/features/profile/data/profile_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _profileJson = {
  'id': 1,
  'name': 'Armel Meledje',
  'cv_last_name': null,
  'cv_first_name': null,
  'headline': {'fr': 'Développeur', 'en': 'Developer'},
  'bio_short': {'fr': '', 'en': ''},
  'bio_full': {'fr': '', 'en': ''},
  'email': 'armel@example.com',
  'phone': null,
  'location': null,
  'social_links': null,
  'photo_url': null,
  'cv_photo_url': null,
  'music': null,
  'cv_files': null,
};

Map<String, String> _fieldMap(FormData form) => {for (final e in form.fields) e.key: e.value};

void main() {
  late FakeDioAdapter adapter;
  late ProfileRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = ProfileRepository(
      ApiClient(baseUrl: 'https://me.armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('get renvoie le profil analysé', () async {
    adapter.whenRequest('GET', '/v1/profile', statusCode: 200, body: _profileJson);

    final profile = await repository.get();

    expect(profile.name, 'Armel Meledje');
  });

  test('update envoie un POST multipart avec _method=PATCH (piège des fichiers)', () async {
    adapter.whenRequest('POST', '/v1/profile', statusCode: 200, body: _profileJson);

    await repository.update(
      name: 'Armel Meledje',
      cvLastName: null,
      cvFirstName: null,
      headline: const Translated(fr: 'Développeur', en: 'Developer'),
      bioShort: const Translated(),
      bioFull: const Translated(),
      email: 'armel@example.com',
      phone: null,
      location: null,
      socialLinks: const SocialLinks(),
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    final fields = _fieldMap(request.data as FormData);
    expect(fields['_method'], 'PATCH');
    expect(fields['name'], 'Armel Meledje');
    expect(fields['headline[fr]'], 'Développeur');
    expect(fields['social_links[github]'], '');
  });

  test('deleteMusic appelle DELETE /v1/profile/music', () async {
    adapter.whenRequest('DELETE', '/v1/profile/music', statusCode: 204);

    await repository.deleteMusic();

    expect(adapter.requests.single.path, '/v1/profile/music');
  });

  test('deleteCv appelle DELETE /v1/profile/cv/{locale}', () async {
    adapter.whenRequest('DELETE', '/v1/profile/cv/en', statusCode: 204);

    await repository.deleteCv('en');

    expect(adapter.requests.single.path, '/v1/profile/cv/en');
  });
}
