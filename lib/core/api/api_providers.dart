import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/env.dart';
import '../storage/token_storage.dart';
import 'api_client.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: Env.apiBaseUrl, tokens: ref.watch(tokenStorageProvider));
  ref.onDispose(client.close);
  return client;
});
