import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_exception.dart';
import 'package:me_mobile/core/api/api_providers.dart';
import 'package:me_mobile/core/device/device_name.dart';
import 'package:me_mobile/core/storage/token_storage.dart';
import 'package:me_mobile/features/auth/application/session_controller.dart';
import 'package:me_mobile/features/auth/data/auth_repository.dart';

import '../../helpers/fake_dio_adapter.dart';

class _MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

const _userJson = {'id': 1, 'name': 'Armel Meledje', 'email': 'armel@example.com'};

void main() {
  late FakeDioAdapter adapter;
  late _MemoryTokenStorage tokens;
  late ProviderContainer container;

  setUp(() {
    adapter = FakeDioAdapter();
    tokens = _MemoryTokenStorage();
    final client = ApiClient(baseUrl: 'https://me.armeldev.xyz/api', tokens: tokens, adapter: adapter);
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(client),
        deviceNameProvider.overrideWith((ref) async => 'Test Device'),
      ],
    );
    addTearDown(container.dispose);
  });

  test('sans jeton stocké, la session démarre déconnectée', () async {
    final user = await container.read(sessionProvider.future);

    expect(user, isNull);
  });

  test('un jeton stocké invalide (401) déconnecte silencieusement', () async {
    await tokens.write('un-vieux-jeton');
    adapter.whenRequest('GET', '/v1/auth/me', statusCode: 401, body: {'message': 'Unauthenticated.'});

    final user = await container.read(sessionProvider.future);

    expect(user, isNull);
    expect(await tokens.read(), isNull);
  });

  test('connexion réussie sans 2FA ouvre la session et stocke le jeton', () async {
    await container.read(sessionProvider.future);
    adapter.whenRequest(
      'POST',
      '/v1/auth/login',
      statusCode: 200,
      body: {'token': 'nouveau-jeton', 'user': _userJson},
    );

    final result = await container.read(sessionProvider.notifier).login(email: 'armel@example.com', password: 'x');

    expect(result, isA<LoginSucceeded>());
    expect(container.read(sessionProvider).value?.name, 'Armel Meledje');
    expect(await tokens.read(), 'nouveau-jeton');
  });

  test('identifiants invalides renvoient un 422 sur email, la session reste fermée', () async {
    await container.read(sessionProvider.future);
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
      container.read(sessionProvider.notifier).login(email: 'armel@example.com', password: 'faux'),
      throwsA(isA<ValidationException>()),
    );
    expect(container.read(sessionProvider).value, isNull);
  });

  test('trop de tentatives de connexion renvoie 429', () async {
    await container.read(sessionProvider.future);
    adapter.whenRequest('POST', '/v1/auth/login', statusCode: 429, body: {'message': 'Too Many Attempts.'});

    await expectLater(
      container.read(sessionProvider.notifier).login(email: 'armel@example.com', password: 'x'),
      throwsA(isA<TooManyRequestsException>()),
    );
  });

  group('double authentification', () {
    test('login renvoie un défi et ne stocke aucun jeton', () async {
      await container.read(sessionProvider.future);
      adapter.whenRequest('POST', '/v1/auth/login', statusCode: 200, body: {'two_factor': true, 'challenge': 'abc'});

      final result = await container.read(sessionProvider.notifier).login(email: 'armel@example.com', password: 'x');

      expect(result, isA<TwoFactorRequired>());
      expect((result as TwoFactorRequired).challenge, 'abc');
      expect(await tokens.read(), isNull);
      expect(container.read(sessionProvider).value, isNull);
    });

    test('un code TOTP valide ouvre la session', () async {
      await container.read(sessionProvider.future);
      adapter.whenRequest(
        'POST',
        '/v1/auth/two-factor-challenge',
        statusCode: 200,
        body: {'token': 'jeton-2fa', 'user': _userJson},
      );

      await container.read(sessionProvider.notifier).confirmTwoFactor(challenge: 'abc', code: '123456');

      expect(container.read(sessionProvider).value?.email, 'armel@example.com');
      expect(await tokens.read(), 'jeton-2fa');
    });

    test('un code invalide renvoie un 422 sur code, la session reste fermée', () async {
      await container.read(sessionProvider.future);
      adapter.whenRequest(
        'POST',
        '/v1/auth/two-factor-challenge',
        statusCode: 422,
        body: {
          'message': 'Erreur de validation.',
          'errors': {
            'code': ['Le code fourni est invalide.'],
          },
        },
      );

      await expectLater(
        container.read(sessionProvider.notifier).confirmTwoFactor(challenge: 'abc', code: '000000'),
        throwsA(isA<ValidationException>().having((e) => e.errorFor('code'), 'errorFor(code)', isNotNull)),
      );
      expect(container.read(sessionProvider).value, isNull);
    });

    test('un défi expiré renvoie un 422 sur challenge (l\'écran doit relancer la connexion)', () async {
      await container.read(sessionProvider.future);
      adapter.whenRequest(
        'POST',
        '/v1/auth/two-factor-challenge',
        statusCode: 422,
        body: {
          'message': 'Erreur de validation.',
          'errors': {
            'challenge': ['Ce défi a expiré, reconnectez-vous.'],
          },
        },
      );

      await expectLater(
        container.read(sessionProvider.notifier).confirmTwoFactor(challenge: 'perime', code: '123456'),
        throwsA(isA<ValidationException>().having((e) => e.errorFor('challenge'), 'errorFor(challenge)', isNotNull)),
      );
    });

    test('un code de secours ouvre aussi la session', () async {
      await container.read(sessionProvider.future);
      adapter.whenRequest(
        'POST',
        '/v1/auth/two-factor-challenge',
        statusCode: 200,
        body: {'token': 'jeton-secours', 'user': _userJson},
      );

      await container.read(sessionProvider.notifier).confirmTwoFactor(challenge: 'abc', recoveryCode: 'AAAA-BBBB');

      expect(container.read(sessionProvider).value, isNotNull);
      expect(await tokens.read(), 'jeton-secours');
    });
  });

  test('un 401 reçu en cours de session ferme la session et efface le jeton', () async {
    await container.read(sessionProvider.future);
    adapter.whenRequest(
      'POST',
      '/v1/auth/login',
      statusCode: 200,
      body: {'token': 'jeton', 'user': _userJson},
    );
    await container.read(sessionProvider.notifier).login(email: 'armel@example.com', password: 'x');
    expect(container.read(sessionProvider).value, isNotNull);

    adapter.whenRequest('GET', '/v1/dashboard', statusCode: 401, body: {'message': 'Unauthenticated.'});
    await expectLater(
      container.read(apiClientProvider).get('/v1/dashboard'),
      throwsA(isA<UnauthorizedException>()),
    );
    // La notification passe par un Stream : laisse le micro-tour de boucle s'écouler.
    await Future<void>.delayed(Duration.zero);

    expect(container.read(sessionProvider).value, isNull);
    expect(await tokens.read(), isNull);
  });

  test('la déconnexion révoque le jeton côté serveur puis ferme la session localement', () async {
    await container.read(sessionProvider.future);
    adapter.whenRequest(
      'POST',
      '/v1/auth/login',
      statusCode: 200,
      body: {'token': 'jeton', 'user': _userJson},
    );
    await container.read(sessionProvider.notifier).login(email: 'armel@example.com', password: 'x');

    adapter.whenRequest('POST', '/v1/auth/logout', statusCode: 204);
    await container.read(sessionProvider.notifier).logout();

    expect(container.read(sessionProvider).value, isNull);
    expect(await tokens.read(), isNull);
  });

  test('la déconnexion ferme la session même si la révocation échoue (hors ligne)', () async {
    await container.read(sessionProvider.future);
    adapter.whenRequest(
      'POST',
      '/v1/auth/login',
      statusCode: 200,
      body: {'token': 'jeton', 'user': _userJson},
    );
    await container.read(sessionProvider.notifier).login(email: 'armel@example.com', password: 'x');

    adapter.whenRequest('POST', '/v1/auth/logout', statusCode: 500, body: {'message': 'Erreur serveur.'});
    await container.read(sessionProvider.notifier).logout();

    expect(container.read(sessionProvider).value, isNull);
    expect(await tokens.read(), isNull);
  });
}
