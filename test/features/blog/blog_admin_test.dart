import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/blog/data/blog_admin.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _meta = {'current_page': 1, 'last_page': 1, 'per_page': 50, 'total': 1};

void main() {
  late FakeDioAdapter adapter;
  late BlogAdminRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = BlogAdminRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('tags : lecture avec le nombre d\'articles, modification des deux langues', () async {
    const tagJson = {
      'id': 2,
      'slug': 'ia',
      'name': {'fr': 'IA', 'en': 'AI'},
      'posts_count': 3,
    };
    adapter.whenRequest(
      'GET',
      '/v1/post-tags',
      statusCode: 200,
      body: {
        'data': [tagJson],
        'meta': _meta,
      },
    );
    adapter.whenRequest('PUT', '/v1/post-tags/2', statusCode: 200, body: tagJson);

    final page = await repository.tags(page: 1);
    await repository.updateTag(2, const Translated(fr: 'IA', en: 'AI'));

    expect(page.items.single.postsCount, 3);
    expect(page.items.single.name.en, 'AI');
    expect(adapter.requests.last.data, {
      'name': {'fr': 'IA', 'en': 'AI'},
    });
  });

  test('abonnés : statut, langue, filtre et compteurs', () async {
    adapter.whenRequest(
      'GET',
      '/v1/subscribers',
      statusCode: 200,
      body: {
        'data': [
          {
            'id': 7,
            'email': 'lea@example.com',
            'locale': 'en',
            'status': 'active',
            'confirmed_at': '2026-10-04T10:00:00Z',
            'unsubscribed_at': null,
            'created_at': '2026-10-04T09:00:00Z',
          },
        ],
        'meta': _meta,
        'summary': {'active': 12, 'pending': 3, 'unsubscribed': 1},
      },
    );

    final page = await repository.subscribers(page: 1, status: 'active');
    final summary = await repository.subscriberSummary();

    final subscriber = page.items.single;
    expect(subscriber.status, SubscriberStatus.active);
    expect(subscriber.locale, 'en');
    expect(adapter.requests.first.queryParameters['status'], 'active');
    expect(summary.active, 12);
    expect(summary.pending, 3);
  });

  test('séries : lecture, traduction et suppression', () async {
    const seriesJson = {
      'id': 4,
      'slug': 'laravel-de-a-a-z',
      'name': {'fr': 'Laravel de A à Z', 'en': 'Laravel de A à Z'},
      'posts_count': 2,
    };
    adapter.whenRequest(
      'GET',
      '/v1/post-series',
      statusCode: 200,
      body: {
        'data': [seriesJson],
        'meta': _meta,
      },
    );
    adapter.whenRequest('PUT', '/v1/post-series/4', statusCode: 200, body: seriesJson);
    adapter.whenRequest('DELETE', '/v1/post-series/4', statusCode: 204);

    final page = await repository.series(page: 1);
    await repository.updateSeries(4, const Translated(fr: 'Laravel de A à Z', en: 'Laravel from A to Z'));
    await repository.deleteSeries(4);

    expect(page.items.single.postsCount, 2);
    expect(adapter.requests[1].data, {
      'name': {'fr': 'Laravel de A à Z', 'en': 'Laravel from A to Z'},
    });
    expect(adapter.requests.last.method, 'DELETE');
  });
}
