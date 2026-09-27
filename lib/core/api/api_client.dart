import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Client unique de l'API `/api/v1`.
///
/// - ajoute `Accept: application/json` (sans lui, Laravel peut répondre par une redirection HTML)
///   et `Authorization: Bearer` quand un jeton est stocké ;
/// - convertit toute erreur en [ApiException] ;
/// - signale chaque 401 sur [unauthorized] pour que la session se ferme.
///
/// Les chemins sont relatifs à l'URL de base, qui se termine par `/api` : `get('/v1/dashboard')`.
class ApiClient {
  ApiClient({required String baseUrl, required TokenStorage tokens, HttpClientAdapter? adapter})
      : _tokens = tokens,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Accept': 'application/json'},
          ),
        ) {
    if (adapter != null) {
      _dio.httpClientAdapter = adapter;
    }
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokens.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokens;
  final _unauthorized = StreamController<void>.broadcast();

  /// Émet à chaque réponse 401.
  Stream<void> get unauthorized => _unauthorized.stream;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: _cleanQuery(query)));

  Future<dynamic> post(String path, {Object? data}) => _send(() => _dio.post<dynamic>(path, data: data));

  Future<dynamic> put(String path, {Object? data}) => _send(() => _dio.put<dynamic>(path, data: data));

  Future<dynamic> patch(String path, {Object? data}) => _send(() => _dio.patch<dynamic>(path, data: data));

  Future<dynamic> delete(String path, {Object? data}) => _send(() => _dio.delete<dynamic>(path, data: data));

  /// Envoi multipart. Toujours en `POST` : PHP ne lit pas les fichiers d'un `PUT`/`PATCH`,
  /// le vrai verbe passe dans le champ `_method` du [FormData] (voir `buildFormData`).
  Future<dynamic> upload(String path, FormData form, {ProgressCallback? onProgress}) => _send(
        () => _dio.post<dynamic>(
          path,
          data: form,
          onSendProgress: onProgress,
          options: Options(receiveTimeout: const Duration(minutes: 2)),
        ),
      );

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      if (error is UnauthorizedException) {
        _unauthorized.add(null);
      }
      throw error;
    }
  }

  /// Retire les filtres vides et convertit les booléens en `1` / `0`.
  static Map<String, dynamic>? _cleanQuery(Map<String, dynamic>? query) {
    if (query == null) {
      return null;
    }
    return {
      for (final MapEntry(:key, :value) in query.entries)
        if (value != null && value != '') key: value is bool ? (value ? 1 : 0) : value,
    };
  }

  void close() {
    _dio.close();
    _unauthorized.close();
  }
}
