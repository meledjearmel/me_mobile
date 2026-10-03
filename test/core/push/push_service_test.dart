import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_providers.dart';
import 'package:me_mobile/core/push/push_service.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

void main() {
  // Aucun test ne peut appeler `Firebase.initializeApp()` (pas de plateforme
  // native dans les tests unitaires) : ces cas vérifient donc que le service
  // se met en veille sans planter tant que Firebase n'est pas initialisé —
  // exactement la situation tant que `google-services.json` est absent.
  group('sans Firebase initialisé (google-services.json absent)', () {
    late FakeDioAdapter adapter;
    late ProviderContainer container;

    setUp(() {
      adapter = FakeDioAdapter();
      final client = ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter);
      container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(client)]);
      addTearDown(container.dispose);
    });

    test('init() ne lève pas et ne pose aucune route', () async {
      await container.read(pushServiceProvider).init();
    });

    test('registerForCurrentSession() ne contacte pas le serveur', () async {
      await container.read(pushServiceProvider).registerForCurrentSession();

      expect(adapter.requests, isEmpty);
    });

    test('unregisterCurrentDevice() ne contacte pas le serveur', () async {
      await container.read(pushServiceProvider).unregisterCurrentDevice();

      expect(adapter.requests, isEmpty);
    });
  });
}
