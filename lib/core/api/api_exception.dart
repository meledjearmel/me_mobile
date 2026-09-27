import 'package:dio/dio.dart';

/// Erreur renvoyée par le client API, déjà traduite en message affichable.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  static ApiException fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return const NetworkException();
    }

    final data = response.data;
    final message = data is Map && data['message'] is String ? data['message'] as String : null;

    return switch (response.statusCode) {
      401 => const UnauthorizedException(),
      404 => const NotFoundException(),
      422 => ValidationException(message ?? 'Certains champs sont invalides.', _parseErrors(data)),
      429 => TooManyRequestsException(retryAfter: int.tryParse(response.headers.value('retry-after') ?? '')),
      final status => ServerException(status ?? 0, message ?? 'Erreur du serveur (${status ?? '?'}).'),
    };
  }

  static Map<String, List<String>> _parseErrors(Object? data) {
    if (data is! Map || data['errors'] is! Map) {
      return const {};
    }

    return {
      for (final MapEntry(:key, :value) in (data['errors'] as Map).entries)
        key.toString(): value is List ? value.map((m) => m.toString()).toList() : [value.toString()],
    };
  }

  @override
  String toString() => message;
}

/// 422 : erreurs de validation Laravel, clés en notation pointée (`title.fr`, `gallery.2`).
final class ValidationException extends ApiException {
  const ValidationException(super.message, this.errors);

  final Map<String, List<String>> errors;

  /// Premier message d'erreur du champ, à afficher sous celui-ci.
  String? errorFor(String field) => errors[field]?.firstOrNull;

  /// Vrai si le champ ou l'un de ses sous-champs (`title` → `title.fr`) est en erreur.
  bool hasErrorUnder(String prefix) => errors.keys.any((k) => k == prefix || k.startsWith('$prefix.'));
}

/// 401 : jeton absent ou révoqué, la session doit être fermée.
final class UnauthorizedException extends ApiException {
  const UnauthorizedException() : super('Votre session a expiré, reconnectez-vous.');
}

final class NotFoundException extends ApiException {
  const NotFoundException() : super('Élément introuvable : il a peut-être été supprimé.');
}

/// 429 : limite de tentatives atteinte (5 par minute sur la connexion).
final class TooManyRequestsException extends ApiException {
  const TooManyRequestsException({this.retryAfter})
      : super('Trop de tentatives. Patientez une minute avant de réessayer.');

  /// Secondes à attendre, si le serveur l'indique.
  final int? retryAfter;
}

final class ServerException extends ApiException {
  const ServerException(this.statusCode, super.message);

  final int statusCode;
}

/// Pas de réponse : hors ligne, délai dépassé, DNS, certificat…
final class NetworkException extends ApiException {
  const NetworkException() : super('Connexion impossible. Vérifiez votre réseau puis réessayez.');
}
