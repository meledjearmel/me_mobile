import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/updates/app_release.dart';
import 'package:me_mobile/core/updates/app_update_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

AppRelease _release({int buildNumber = 5}) => AppRelease(
  id: 1,
  versionName: '1.2.0',
  buildNumber: buildNumber,
  notes: '',
  size: 0,
  sha256: '',
  downloadUrl: 'https://armeldev.xyz/x.apk',
);

void main() {
  group('comparaison des versions', () {
    test('un build plus grand est une mise à jour', () {
      expect(_release(buildNumber: 5).isNewerThan(4), isTrue);
    });

    test('le même build ou un build plus petit ne l\'est pas', () {
      expect(_release(buildNumber: 5).isNewerThan(5), isFalse);
      expect(_release(buildNumber: 5).isNewerThan(6), isFalse);
    });

    test('le numéro de build installé est lu depuis le texte', () {
      expect(parseBuildNumber('12'), 12);
      expect(parseBuildNumber(' 3 '), 3);
      expect(parseBuildNumber(''), 0);
      expect(parseBuildNumber('abc'), 0);
    });
  });

  group('vérification de l\'empreinte', () {
    late Directory dir;
    late File file;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('apk_test');
      file = File('${dir.path}/app.apk')..writeAsStringSync('abc');
    });

    tearDown(() => dir.delete(recursive: true));

    // SHA-256 de « abc ».
    const abc = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

    test('accepte la bonne empreinte, casse et espaces ignorés', () async {
      expect(await fileMatchesSha256(file, abc), isTrue);
      expect(await fileMatchesSha256(file, ' ${abc.toUpperCase()} '), isTrue);
    });

    test('refuse une empreinte différente', () async {
      expect(await fileMatchesSha256(file, abc.replaceFirst('b', 'c')), isFalse);
    });
  });

  group('AppUpdateRepository', () {
    late FakeDioAdapter adapter;
    late AppUpdateRepository repository;

    setUp(() {
      adapter = FakeDioAdapter();
      repository = AppUpdateRepository(
        ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
      );
    });

    test('lit la dernière version publiée', () async {
      adapter.whenRequest('GET', '/v1/app/latest', statusCode: 200, body: {
        'data': {
          'id': 3,
          'version_name': '1.1.0',
          'build_number': 7,
          'notes': 'Correctifs',
          'size': 1024,
          'sha256': 'ff',
          'published_at': '2026-10-15T10:00:00Z',
          'download_url': 'https://armeldev.xyz/api/v1/app-releases/3/download?signature=x',
        },
      });

      final release = await repository.latest();

      expect(release!.buildNumber, 7);
      expect(release.versionName, '1.1.0');
      expect(release.downloadUrl, contains('signature'));
    });

    test('renvoie null sur une réponse 204', () async {
      adapter.whenRequest('GET', '/v1/app/latest', statusCode: 204);

      expect(await repository.latest(), isNull);
    });
  });
}
