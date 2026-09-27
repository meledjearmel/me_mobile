import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'user.dart';

/// Résultat de `POST /auth/login`.
sealed class LoginResult {
  const LoginResult();
}

final class LoginSucceeded extends LoginResult {
  const LoginSucceeded({required this.token, required this.user});

  final String token;
  final User user;
}

/// Compte protégé par la 2FA : aucun jeton, un défi valable 5 minutes.
final class TwoFactorRequired extends LoginResult {
  const TwoFactorRequired(this.challenge);

  final String challenge;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  Future<LoginResult> login({required String email, required String password, required String deviceName}) async {
    final json = await _api.post(
      '/v1/auth/login',
      data: {'email': email, 'password': password, 'device_name': deviceName},
    ) as Map<String, dynamic>;

    if (json['two_factor'] == true) {
      return TwoFactorRequired(json['challenge'] as String);
    }
    return _succeeded(json);
  }

  /// Termine une connexion 2FA avec le code TOTP **ou** un code de secours (usage unique).
  Future<LoginSucceeded> confirmTwoFactor({
    required String challenge,
    required String deviceName,
    String? code,
    String? recoveryCode,
  }) async {
    assert((code == null) != (recoveryCode == null), 'Un code ou un code de secours, pas les deux.');

    final json = await _api.post(
      '/v1/auth/two-factor-challenge',
      data: {
        'challenge': challenge,
        'device_name': deviceName,
        'code': ?code,
        'recovery_code': ?recoveryCode,
      },
    ) as Map<String, dynamic>;

    return _succeeded(json);
  }

  Future<User> me() async => User.fromJson(await _api.get('/v1/auth/me') as Map<String, dynamic>);

  /// Révoque le jeton courant côté serveur (204).
  Future<void> logout() => _api.post('/v1/auth/logout');

  LoginSucceeded _succeeded(Map<String, dynamic> json) => LoginSucceeded(
        token: json['token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );
}
