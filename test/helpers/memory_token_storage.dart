import 'package:me_mobile/core/storage/token_storage.dart';

/// [TokenStorage] en mémoire pour les tests, sans toucher le Keystore réel.
class MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
