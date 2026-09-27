import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_providers.dart';
import 'text_tone.dart';

final aiAssistRepositoryProvider = Provider<AiAssistRepository>(
  (ref) => AiAssistRepository(ref.watch(apiClientProvider)),
);

/// Assistance IA (`POST /v1/ai/translate`, `POST /v1/ai/improve`) : traduit
/// un texte entre français et anglais, ou le réécrit dans sa langue
/// d'origine avec un ton et une consigne libres et optionnels.
///
/// Peut répondre 503 (« L'assistance IA est momentanément indisponible »,
/// tous les fournisseurs configurés ont échoué côté serveur) : ce cas passe
/// par [ApiException] comme n'importe quelle autre erreur serveur, le
/// message du serveur est déjà le bon à afficher tel quel.
class AiAssistRepository {
  const AiAssistRepository(this._api);

  final ApiClient _api;

  Future<String> translate({required String text, required String sourceLocale, required String targetLocale}) async {
    final json = await _api.post(
      '/v1/ai/translate',
      data: {'text': text, 'source_locale': sourceLocale, 'target_locale': targetLocale},
    ) as Map<String, dynamic>;
    return json['text'] as String;
  }

  Future<String> improve({
    required String text,
    required String locale,
    TextTone? tone,
    String? instructions,
  }) async {
    final json = await _api.post(
      '/v1/ai/improve',
      data: {'text': text, 'locale': locale, 'tone': tone?.wireValue, 'instructions': instructions},
    ) as Map<String, dynamic>;
    return json['text'] as String;
  }
}
