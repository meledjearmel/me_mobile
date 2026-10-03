import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_exception.dart';
import 'package:me_mobile/core/storage/token_storage.dart';

import '../../helpers/fake_dio_adapter.dart';

/// [TokenStorage] en mémoire, pour ne pas toucher le Keystore réel dans les tests.
class _MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

void main() {
  late FakeDioAdapter adapter;
  late _MemoryTokenStorage tokens;
  late ApiClient client;

  setUp(() {
    adapter = FakeDioAdapter();
    tokens = _MemoryTokenStorage();
    client = ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: tokens, adapter: adapter);
  });

  test('ajoute Accept: application/json à chaque requête', () async {
    adapter.whenRequest('GET', '/v1/dashboard', statusCode: 200, body: {});

    await client.get('/v1/dashboard');

    expect(adapter.requests.single.headers['Accept'], 'application/json');
  });

  test('ajoute Authorization: Bearer quand un jeton est stocké', () async {
    await tokens.write('abc123');
    adapter.whenRequest('GET', '/v1/auth/me', statusCode: 200, body: {'id': 1, 'name': 'Armel', 'email': 'a@a.fr'});

    await client.get('/v1/auth/me');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer abc123');
  });

  test("n'ajoute pas d'en-tête Authorization sans jeton stocké", () async {
    adapter.whenRequest('GET', '/v1/dashboard', statusCode: 200, body: {});

    await client.get('/v1/dashboard');

    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('convertit une réponse 422 en ValidationException avec les erreurs par champ', () async {
    adapter.whenRequest(
      'POST',
      '/v1/auth/login',
      statusCode: 422,
      body: {
        'message': 'Erreur de validation.',
        'errors': {
          'email': ['Ces identifiants sont incorrects.'],
        },
      },
    );

    await expectLater(
      client.post('/v1/auth/login', data: {}),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errorFor('email'),
          'errorFor(email)',
          'Ces identifiants sont incorrects.',
        ),
      ),
    );
  });

  test('hasErrorUnder détecte les clés imbriquées en notation pointée', () async {
    const error = ValidationException('Erreur de validation.', {
      'title.en': ['Ce champ est obligatoire.'],
    });

    expect(error.hasErrorUnder('title'), isTrue);
    expect(error.hasErrorUnder('description'), isFalse);
  });

  test('convertit une réponse 401 en UnauthorizedException et le signale sur unauthorized', () async {
    adapter.whenRequest('GET', '/v1/auth/me', statusCode: 401, body: {'message': 'Unauthenticated.'});

    final notified = client.unauthorized.first;
    await expectLater(client.get('/v1/auth/me'), throwsA(isA<UnauthorizedException>()));
    await expectLater(notified, completes);
  });

  test('convertit une réponse 429 en TooManyRequestsException', () async {
    adapter.whenRequest(
      'POST',
      '/v1/auth/login',
      statusCode: 429,
      headers: {'retry-after': '42'},
      body: {'message': 'Too Many Attempts.'},
    );

    await expectLater(
      client.post('/v1/auth/login', data: {}),
      throwsA(isA<TooManyRequestsException>().having((e) => e.retryAfter, 'retryAfter', 42)),
    );
  });

  test('une absence de réponse (hors ligne) devient NetworkException', () async {
    final offline = ApiClient(
      baseUrl: 'https://armeldev.xyz/api',
      tokens: tokens,
      adapter: _ThrowingAdapter(),
    );

    await expectLater(offline.get('/v1/dashboard'), throwsA(isA<NetworkException>()));
  });
}

/// Simule une coupure réseau : l'appel Dio échoue avant de recevoir une réponse.
class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    throw const SocketExceptionStub();
  }

  @override
  void close({bool force = false}) {}
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
