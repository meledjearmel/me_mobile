import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/billing/data/billing_settings.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

void main() {
  late FakeDioAdapter adapter;
  late BillingSettingsRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = BillingSettingsRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('get lit les textes (vides si absents) et les nombres (défauts si absents)', () async {
    adapter.whenRequest(
      'GET',
      '/v1/billing-settings',
      statusCode: 200,
      body: {'billing_business_name': 'Armel Dev', 'billing_iban': null, 'billing_quote_validity_days': 15},
    );

    final settings = await repository.get();

    expect(settings.texts['billing_business_name'], 'Armel Dev');
    expect(settings.texts['billing_iban'], '');
    expect(settings.numbers['billing_quote_validity_days'], 15);
    expect(settings.numbers['billing_max_reminders'], 2);
  });

  test('save envoie les textes vides à null et tous les nombres', () async {
    adapter.whenRequest('PUT', '/v1/billing-settings', statusCode: 200, body: {});

    await repository.save(
      const BillingSettings(
        texts: {'billing_business_name': ' Armel Dev ', 'billing_iban': '  '},
        numbers: {'billing_deposit_percent': 30},
      ),
    );

    expect(adapter.requests.single.data, {
      'billing_business_name': 'Armel Dev',
      'billing_iban': null,
      'billing_deposit_percent': 30,
    });
  });
}
