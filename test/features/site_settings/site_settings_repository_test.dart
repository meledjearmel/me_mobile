import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/site_settings/data/site_settings.dart';
import 'package:me_mobile/features/site_settings/data/site_settings_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _settingsJson = {
  'contact_opens_drawer': false,
  'testimonial_video_enabled': true,
  'availability_status': 'from',
  'available_from': '2026-12-01',
  'blog_enabled': true,
  'cv_job_profile_id': 3,
  'cv_source': 'generated',
  'congratulation_notify_minutes': 30,
  'booking_enabled': true,
  'booking_min_notice_hours': 48,
  'booking_horizon_days': 60,
  'booking_buffer_minutes': 15,
  'booking_video_provider': 'link',
  'booking_video_link': 'https://meet.example.com/armel',
};

void main() {
  late FakeDioAdapter adapter;
  late SiteSettingsRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = SiteSettingsRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('get lit tous les réglages', () async {
    adapter.whenRequest('GET', '/v1/site-settings', statusCode: 200, body: _settingsJson);

    final settings = await repository.get();

    expect(settings.contactOpensDrawer, isFalse);
    expect(settings.testimonialVideoEnabled, isTrue);
    expect(settings.availabilityStatus, AvailabilityStatus.from);
    expect(settings.availableFrom, DateTime(2026, 12));
    expect(settings.blogEnabled, isTrue);
    expect(settings.cvJobProfileId, 3);
    expect(settings.cvSource, CvSource.generated);
    expect(settings.congratulationNotifyMinutes, 30);
    expect(settings.bookingMinNoticeHours, 48);
    expect(settings.bookingHorizonDays, 60);
    expect(settings.bookingBufferMinutes, 15);
    expect(settings.bookingVideoProvider, BookingVideoProvider.link);
    expect(settings.bookingVideoLink, 'https://meet.example.com/armel');
  });

  test('valeurs absentes ou inconnues : défauts du serveur', () {
    final settings = SiteSettings.fromJson({'cv_source': 'autre', 'booking_video_provider': 'autre'});

    expect(settings.cvSource, CvSource.uploaded);
    expect(settings.bookingVideoProvider, BookingVideoProvider.jitsi);
    expect(settings.cvJobProfileId, isNull);
  });

  test('update renvoie le formulaire complet en PATCH JSON, profil « Automatique » compris', () async {
    adapter.whenRequest('PATCH', '/v1/site-settings', statusCode: 200, body: _settingsJson);

    await repository.update(SiteSettings.fromJson({..._settingsJson, 'cv_job_profile_id': null}));

    final body = adapter.requests.single.data as Map;
    expect(body, {..._settingsJson, 'cv_job_profile_id': null});
  });

  test('available_from ne part qu\'avec le statut « à partir du »', () {
    final settings = SiteSettings.fromJson({..._settingsJson, 'availability_status': 'unavailable'});

    expect(settings.toJson()['availability_status'], 'unavailable');
    expect(settings.toJson()['available_from'], isNull);
    expect(SiteSettings.fromJson(_settingsJson).toJson()['available_from'], '2026-12-01');
  });

  test('patch n\'envoie que les champs demandés', () async {
    adapter.whenRequest('PATCH', '/v1/site-settings', statusCode: 200, body: _settingsJson);

    await repository.patch({'congratulation_notify_minutes': 60});

    expect(adapter.requests.single.data, {'congratulation_notify_minutes': 60});
  });
}
