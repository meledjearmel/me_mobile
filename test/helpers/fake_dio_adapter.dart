import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adaptateur HTTP factice : associe une méthode + un chemin à une réponse
/// canée, sans passer par le réseau. Permet de tester le client API et les
/// dépôts qui l'utilisent (auth, 2FA, erreurs) de bout en bout.
class FakeDioAdapter implements HttpClientAdapter {
  // Une file par route : plusieurs appels à whenRequest() pour la même clé
  // renvoient les réponses dans l'ordre (utile pour paginer), puis répètent
  // la dernière — un seul appel se comporte donc comme avant (même réponse
  // à chaque requête).
  final _routes = <String, List<_CannedResponse>>{};
  final requests = <RequestOptions>[];

  void whenRequest(String method, String path, {required int statusCode, Object? body, Map<String, String>? headers}) {
    _routes.putIfAbsent('${method.toUpperCase()} $path', () => []).add(_CannedResponse(statusCode, body, headers ?? const {}));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method.toUpperCase()} ${options.path}';
    final queue = _routes[key];
    if (queue == null || queue.isEmpty) {
      throw StateError('Aucune réponse simulée pour $key. Routes connues : ${_routes.keys}');
    }
    final callsForKey = requests.where((r) => '${r.method.toUpperCase()} ${r.path}' == key).length;
    final canned = queue[(callsForKey - 1).clamp(0, queue.length - 1)];

    return ResponseBody.fromString(
      canned.body == null ? '' : jsonEncode(canned.body),
      canned.statusCode,
      headers: {
        'content-type': ['application/json'],
        for (final MapEntry(:key, :value) in canned.headers.entries) key: [value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CannedResponse {
  const _CannedResponse(this.statusCode, this.body, this.headers);

  final int statusCode;
  final Object? body;
  final Map<String, String> headers;
}
