import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_providers.dart';
import 'package:me_mobile/core/biometrics/biometric_lock_controller.dart';
import 'package:me_mobile/core/biometrics/biometric_preferences.dart';
import 'package:me_mobile/core/device/device_name.dart';
import 'package:me_mobile/features/auth/application/session_controller.dart';

import '../../helpers/fake_biometrics.dart';
import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _userJson = {'id': 1, 'name': 'Armel Meledje', 'email': 'armel@example.com'};

ProviderContainer _buildContainer({
  required MemoryTokenStorage tokens,
  required FakeDioAdapter adapter,
  required FakeBiometricPreferences biometrics,
}) {
  final client = ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: tokens, adapter: adapter);
  return ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(client),
      deviceNameProvider.overrideWith((ref) async => 'Test Device'),
      biometricPreferencesProvider.overrideWithValue(biometrics),
    ],
  );
}

void main() {
  test('désactivé, sans session : pas verrouillé au démarrage', () async {
    final container = _buildContainer(
      tokens: MemoryTokenStorage(),
      adapter: FakeDioAdapter(),
      biometrics: FakeBiometricPreferences(),
    );
    addTearDown(container.dispose);

    expect(await container.read(biometricLockControllerProvider.future), isFalse);
  });

  test('activé mais sans session existante : rien à verrouiller au démarrage', () async {
    final biometrics = FakeBiometricPreferences()..setEnabled(true);
    final container = _buildContainer(tokens: MemoryTokenStorage(), adapter: FakeDioAdapter(), biometrics: biometrics);
    addTearDown(container.dispose);

    expect(await container.read(biometricLockControllerProvider.future), isFalse);
  });

  test('activé avec une session déjà valide (jeton stocké) : verrouillé au démarrage', () async {
    final tokens = MemoryTokenStorage()..write('jeton-existant');
    final adapter = FakeDioAdapter()..whenRequest('GET', '/v1/auth/me', statusCode: 200, body: _userJson);
    final biometrics = FakeBiometricPreferences()..setEnabled(true);
    final container = _buildContainer(tokens: tokens, adapter: adapter, biometrics: biometrics);
    addTearDown(container.dispose);

    expect(await container.read(biometricLockControllerProvider.future), isTrue);
  });

  test('une connexion interactive réussie ne verrouille pas immédiatement, même si activé', () async {
    final biometrics = FakeBiometricPreferences()..setEnabled(true);
    final adapter = FakeDioAdapter();
    final container = _buildContainer(tokens: MemoryTokenStorage(), adapter: adapter, biometrics: biometrics);
    addTearDown(container.dispose);
    await container.read(biometricLockControllerProvider.future);

    adapter.whenRequest('POST', '/v1/auth/login', statusCode: 200, body: {'token': 'jeton', 'user': _userJson});
    await container.read(sessionProvider.notifier).login(email: 'armel@example.com', password: 'x');

    expect(container.read(biometricLockControllerProvider).value, isFalse);
  });

  test('lockIfEnabled() verrouille si activé et une session est ouverte', () async {
    final biometrics = FakeBiometricPreferences()..setEnabled(true);
    final adapter = FakeDioAdapter();
    final container = _buildContainer(tokens: MemoryTokenStorage(), adapter: adapter, biometrics: biometrics);
    addTearDown(container.dispose);
    await container.read(biometricLockControllerProvider.future);
    adapter.whenRequest('POST', '/v1/auth/login', statusCode: 200, body: {'token': 'jeton', 'user': _userJson});
    await container.read(sessionProvider.notifier).login(email: 'armel@example.com', password: 'x');

    await container.read(biometricLockControllerProvider.notifier).lockIfEnabled();

    expect(container.read(biometricLockControllerProvider).value, isTrue);
  });

  test('lockIfEnabled() ne fait rien si la préférence est désactivée', () async {
    final biometrics = FakeBiometricPreferences();
    final adapter = FakeDioAdapter();
    final container = _buildContainer(tokens: MemoryTokenStorage(), adapter: adapter, biometrics: biometrics);
    addTearDown(container.dispose);
    await container.read(biometricLockControllerProvider.future);
    adapter.whenRequest('POST', '/v1/auth/login', statusCode: 200, body: {'token': 'jeton', 'user': _userJson});
    await container.read(sessionProvider.notifier).login(email: 'armel@example.com', password: 'x');

    await container.read(biometricLockControllerProvider.notifier).lockIfEnabled();

    expect(container.read(biometricLockControllerProvider).value, isFalse);
  });

  test('unlock() déverrouille immédiatement', () async {
    final biometrics = FakeBiometricPreferences()..setEnabled(true);
    final tokens = MemoryTokenStorage()..write('jeton-existant');
    final adapter = FakeDioAdapter()..whenRequest('GET', '/v1/auth/me', statusCode: 200, body: _userJson);
    final container = _buildContainer(tokens: tokens, adapter: adapter, biometrics: biometrics);
    addTearDown(container.dispose);
    expect(await container.read(biometricLockControllerProvider.future), isTrue);

    container.read(biometricLockControllerProvider.notifier).unlock();

    expect(container.read(biometricLockControllerProvider).value, isFalse);
  });

  test('la déconnexion réinitialise le verrouillage', () async {
    final biometrics = FakeBiometricPreferences()..setEnabled(true);
    final tokens = MemoryTokenStorage()..write('jeton-existant');
    final adapter = FakeDioAdapter()
      ..whenRequest('GET', '/v1/auth/me', statusCode: 200, body: _userJson)
      ..whenRequest('POST', '/v1/auth/logout', statusCode: 204);
    final container = _buildContainer(tokens: tokens, adapter: adapter, biometrics: biometrics);
    addTearDown(container.dispose);
    await container.read(biometricLockControllerProvider.future);

    await container.read(sessionProvider.notifier).logout();

    expect(container.read(biometricLockControllerProvider).value, isFalse);
  });
}
