import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adaptateur HTTP factice : associe une méthode + un chemin à une réponse
/// canée, sans passer par le réseau. Permet de tester le client API et les
/// dépôts qui l'utilisent (auth, 2FA, erreurs) de bout en bout.
class FakeDioAdapter implements HttpClientAdapter {
  final _routes = <String, _CannedResponse>{};
  final requests = <RequestOptions>[];

  void whenRequest(String method, String path, {required int statusCode, Object? body, Map<String, String>? headers}) {
    _routes['${method.toUpperCase()} $path'] = _CannedResponse(statusCode, body, headers ?? const {});
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method.toUpperCase()} ${options.path}';
    final canned = _routes[key];
    if (canned == null) {
      throw StateError('Aucune réponse simulée pour $key. Routes connues : ${_routes.keys}');
    }

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
