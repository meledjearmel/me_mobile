/// Configuration par environnement, injectée au build avec `--dart-define`.
///
/// Production par défaut. En local :
/// `flutter run --dart-define=API_BASE_URL=https://192.168.1.x/api`
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://me.armeldev.xyz/api',
  );

  /// Racine du site public (sans `/api`), pour les liens « Voir le site ».
  static String get siteUrl => apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
}
