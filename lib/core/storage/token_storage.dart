import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage du jeton Sanctum. Les jetons n'expirent pas côté serveur :
/// ils ne doivent jamais être conservés en clair.
abstract interface class TokenStorage {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

/// Implémentation Keystore Android, avec un cache mémoire pour ne pas
/// relire le stockage chiffré à chaque requête.
final class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'api_token';

  final FlutterSecureStorage _storage;
  String? _cache;
  bool _loaded = false;

  @override
  Future<String?> read() async {
    if (!_loaded) {
      _cache = await _storage.read(key: _key);
      _loaded = true;
    }
    return _cache;
  }

  @override
  Future<void> write(String token) async {
    _cache = token;
    _loaded = true;
    await _storage.write(key: _key, value: token);
  }

  @override
  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }
}
