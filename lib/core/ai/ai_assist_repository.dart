import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_providers.dart';
import '../models/translated.dart';
import 'text_tone.dart';

final aiAssistRepositoryProvider = Provider<AiAssistRepository>(
  (ref) => AiAssistRepository(ref.watch(apiClientProvider)),
);

/// Assistance IA (`POST /v1/ai/translate`, `/improve`, `/describe-technology`) :
/// traduit un texte entre français et anglais, le réécrit dans sa langue
/// d'origine avec un ton et une consigne libres et optionnels, ou rédige la
/// description d'une technologie.
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

  /// Rédige la description (infobulle) d'une technologie en français, traduite en
  /// anglais. [category] : libellé de sa catégorie, pour aider à la situer.
  Future<Translated> describeTechnology({required String name, String? category}) async {
    final json = await _api.post(
      '/v1/ai/describe-technology',
      data: {'name': name, 'category': category},
    ) as Map<String, dynamic>;
    return Translated.fromJson(json['description']);
  }
}
