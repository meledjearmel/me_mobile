import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_exception.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/inbox/data/testimonial.dart';
import 'package:me_mobile/features/inbox/data/testimonial_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _testimonialJson = {
  'id': 9,
  'author_name': 'Alice',
  'author_email': 'alice@example.com',
  'author_role': 'CTO',
  'content': {'fr': 'Excellent travail', 'en': ''},
  'status': 'pending',
  'is_featured': false,
  'project': null,
  'submitted_at': '2026-09-25T10:00:00Z',
};

void main() {
  late FakeDioAdapter adapter;
  late TestimonialRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = TestimonialRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('updateStatus (modération rapide) n\'envoie que le statut', () async {
    adapter.whenRequest(
      'PUT',
      '/v1/testimonials/9',
      statusCode: 200,
      body: {..._testimonialJson, 'status': 'approved'},
    );

    final updated = await repository.updateStatus(9, TestimonialStatus.approved);

    expect(updated.status, TestimonialStatus.approved);
    final body = adapter.requests.single.data as Map;
    expect(body, {'status': 'approved'});
  });

  test('updateContent envoie modération, texte, accroche et transcription en multipart', () async {
    adapter.whenRequest('POST', '/v1/testimonials/9', statusCode: 200, body: _testimonialJson);

    await repository.updateContent(
      9,
      status: TestimonialStatus.pending,
      isFeatured: true,
      authorName: 'Alice B.',
      authorRole: null,
      content: const Translated(fr: 'Corrigé', en: 'Fixed'),
      highlight: const Translated(fr: 'Top'),
      videoTranscript: const Translated(en: 'Hello'),
    );

    final form = adapter.requests.single.data as FormData;
    final fields = {for (final f in form.fields) f.key: f.value};
    expect(fields['_method'], 'PUT');
    expect(fields['author_name'], 'Alice B.');
    expect(fields['author_role'], '');
    expect(fields['content[fr]'], 'Corrigé');
    expect(fields['content[en]'], 'Fixed');
    expect(fields['highlight[fr]'], 'Top');
    expect(fields['video_transcript[en]'], 'Hello');
    expect(fields['is_featured'], '1');
    expect(form.files, isEmpty);
  });

  test('deleteVideo retire la vidéo et renvoie l\'avis texte', () async {
    adapter.whenRequest('DELETE', '/v1/testimonials/9/video', statusCode: 200, body: _testimonialJson);

    final updated = await repository.deleteVideo(9);

    expect(updated.video, isNull);
  });

  test('un 422 sur is_featured est réécrit avec le message des trois avis maximum', () async {
    adapter.whenRequest(
      'PUT',
      '/v1/testimonials/9',
      statusCode: 422,
      body: {
        'message': 'Erreur de validation.',
        'errors': {
          'is_featured': ['La limite est atteinte.'],
        },
      },
    );

    await expectLater(
      repository.updateFeatured(9, status: TestimonialStatus.approved, isFeatured: true),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.message,
          'message',
          'Trois avis au maximum peuvent être à la une : retirez-en un d\'abord.',
        ),
      ),
    );
  });

  test('un 422 sur un autre champ garde le message d\'origine', () async {
    adapter.whenRequest(
      'POST',
      '/v1/testimonials/9',
      statusCode: 422,
      body: {
        'message': 'Erreur de validation.',
        'errors': {
          'content.en': ['Ce champ est requis dès que le français est renseigné.'],
        },
      },
    );

    await expectLater(
      repository.updateContent(
        9,
        status: TestimonialStatus.pending,
        isFeatured: false,
        authorName: 'Alice',
        authorRole: null,
        content: const Translated(fr: 'Seulement en français'),
      ),
      throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'Erreur de validation.')),
    );
  });
}
