import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/push/push_token_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

void main() {
  late FakeDioAdapter adapter;
  late PushTokenRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    final client = ApiClient(
      baseUrl: 'https://me.armeldev.xyz/api',
      tokens: MemoryTokenStorage(),
      adapter: adapter,
    );
    repository = PushTokenRepository(client);
  });

  test('register envoie le jeton et la plateforme android', () async {
    adapter.whenRequest('POST', '/v1/push-tokens', statusCode: 204);

    await repository.register('fcm-token-123');

    final body = adapter.requests.single.data as Map;
    expect(body['token'], 'fcm-token-123');
    expect(body['platform'], 'android');
  });

  test('unregister envoie uniquement le jeton', () async {
    adapter.whenRequest('DELETE', '/v1/push-tokens', statusCode: 204);

    await repository.unregister('fcm-token-123');

    final body = adapter.requests.single.data as Map;
    expect(body['token'], 'fcm-token-123');
    expect(body.containsKey('platform'), isFalse);
  });
}
