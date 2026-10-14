import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';

/// Plateformes de republication.
enum SyndicationPlatform {
  devto('devto', 'dev.to'),
  hashnode('hashnode', 'Hashnode');

  const SyndicationPlatform(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static SyndicationPlatform? fromWire(String? value) => values.where((p) => p.wireValue == value).firstOrNull;
}

/// Comment un article part sur une plateforme.
enum SyndicationMode {
  off('off', 'Jamais'),
  manual('manual', 'Manuel'),
  auto('auto', 'Automatique');

  const SyndicationMode(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static SyndicationMode fromWire(String? value) => values.firstWhere((m) => m.wireValue == value, orElse: () => off);
}

/// Réglages d'une plateforme. La clé d'API n'est jamais renvoyée : seulement sa présence.
@immutable
class PlatformSettings {
  const PlatformSettings({
    required this.mode,
    required this.hasKey,
    required this.locale,
    this.autoSince,
    this.publicationId,
  });

  factory PlatformSettings.fromJson(Map<String, dynamic>? json) => PlatformSettings(
    mode: SyndicationMode.fromWire(json?['mode'] as String?),
    hasKey: json?['has_key'] as bool? ?? false,
    locale: json?['locale'] as String? ?? 'en',
    autoSince: DateTime.tryParse(json?['auto_since'] as String? ?? '')?.toLocal(),
    publicationId: json?['publication_id'] as String?,
  );

  final SyndicationMode mode;
  final bool hasKey;

  /// Langue republiée : `fr` ou `en`.
  final String locale;

  /// Mode automatique : seuls les articles publiés après cette date partent seuls.
  final DateTime? autoSince;

  /// Hashnode : publication (blog) visée.
  final String? publicationId;
}

@immutable
class SyndicationSettings {
  const SyndicationSettings({required this.devto, required this.hashnode, this.hashnodeError});

  factory SyndicationSettings.fromJson(Map<String, dynamic> json) => SyndicationSettings(
    devto: PlatformSettings.fromJson(json['devto'] as Map<String, dynamic>?),
    hashnode: PlatformSettings.fromJson(json['hashnode'] as Map<String, dynamic>?),
    hashnodeError: json['hashnode_error'] as String?,
  );

  final PlatformSettings devto;
  final PlatformSettings hashnode;

  /// Après un enregistrement : pourquoi la publication Hashnode n'a pas pu être retrouvée.
  final String? hashnodeError;

  PlatformSettings of(SyndicationPlatform platform) => switch (platform) {
    SyndicationPlatform.devto => devto,
    SyndicationPlatform.hashnode => hashnode,
  };
}

/// Ce qu'on envoie pour une plateforme. [apiKey] vide ou `null` : la clé enregistrée est gardée.
typedef PlatformSettingsInput = ({SyndicationMode mode, String locale, String? apiKey, bool clearKey});

/// Un blog du compte Hashnode.
typedef HashnodePublication = ({String id, String title, String url});

/// État d'un article sur une plateforme.
@immutable
class PostSyndication {
  const PostSyndication({
    required this.platform,
    required this.status,
    this.externalUrl,
    this.locale,
    this.error,
    this.publishedAt,
  });

  factory PostSyndication.fromJson(Map<String, dynamic> json) => PostSyndication(
    platform: SyndicationPlatform.fromWire(json['platform'] as String?),
    status: json['status'] as String? ?? 'pending',
    externalUrl: json['external_url'] as String?,
    locale: json['locale'] as String?,
    error: json['error'] as String?,
    publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '')?.toLocal(),
  );

  final SyndicationPlatform? platform;

  /// `pending`, `published` ou `failed`.
  final String status;
  final String? externalUrl;
  final String? locale;
  final String? error;
  final DateTime? publishedAt;

  bool get isPublished => status == 'published';
  bool get isFailed => status == 'failed';

  String get statusLabel => switch (status) {
    'published' => 'Republié',
    'failed' => 'Échec',
    _ => 'En cours',
  };
}

/// Réseaux du kit de partage.
enum SocialNetwork {
  linkedin('linkedin', 'LinkedIn', 2800),
  x('x', 'X', 255),
  facebook('facebook', 'Facebook', 2000),
  whatsapp('whatsapp', 'Statut WhatsApp', 300);

  const SocialNetwork(this.wireValue, this.label, this.maxLength);

  final String wireValue;
  final String label;
  final int maxLength;
}

/// Kit de partage d'un article pour une langue : adresse, image, textes et liens
/// qui ouvrent chaque réseau déjà rempli.
@immutable
class SocialKit {
  const SocialKit({required this.url, required this.image, required this.texts, required this.links});

  factory SocialKit.fromJson(Map<String, dynamic> json) => SocialKit(
    url: json['url'] as String? ?? '',
    image: json['image'] as String? ?? '',
    texts: {
      for (final network in SocialNetwork.values)
        if ((json['texts'] as Map<String, dynamic>?)?[network.wireValue] case final String text) network: text,
    },
    links: {
      for (final network in SocialNetwork.values)
        if ((json['links'] as Map<String, dynamic>?)?[network.wireValue] case final String link) network: link,
    },
  );

  final String url;

  /// Image de partage générée pour l'article.
  final String image;
  final Map<SocialNetwork, String> texts;
  final Map<SocialNetwork, String> links;

  bool get hasTexts => texts.values.any((t) => t.trim().isNotEmpty);
}

/// `GET /v1/posts/{id}/syndications` : plateformes et kits de partage par langue.
@immutable
class PostDistribution {
  const PostDistribution({required this.syndications, required this.social});

  factory PostDistribution.fromJson(Map<String, dynamic> json) => PostDistribution(
    syndications: [
      for (final s in json['syndications'] as List<dynamic>? ?? const [])
        PostSyndication.fromJson(s as Map<String, dynamic>),
    ],
    social: {
      if (json['social'] is Map<String, dynamic>)
        for (final MapEntry(:key, :value) in (json['social'] as Map<String, dynamic>).entries)
          key: SocialKit.fromJson(value as Map<String, dynamic>),
    },
  );

  final List<PostSyndication> syndications;

  /// Par langue (`fr`, `en`) : seules les langues où l'article a un titre.
  final Map<String, SocialKit> social;

  PostSyndication? on(SyndicationPlatform platform) => syndications.where((s) => s.platform == platform).firstOrNull;
}

final syndicationRepositoryProvider = Provider<SyndicationRepository>(
  (ref) => SyndicationRepository(ref.watch(apiClientProvider)),
);

/// Republication (`/v1/syndication`, `/v1/posts/{id}/syndications`) et kit de
/// partage (`/v1/posts/{id}/social-texts`).
class SyndicationRepository {
  const SyndicationRepository(this._api);

  final ApiClient _api;

  Future<SyndicationSettings> settings() async =>
      SyndicationSettings.fromJson(await _api.get('/v1/syndication') as Map<String, dynamic>);

  /// Une clé vide n'est pas envoyée : la clé enregistrée est gardée.
  Future<SyndicationSettings> saveSettings({
    required PlatformSettingsInput devto,
    required PlatformSettingsInput hashnode,
    String? hashnodePublicationId,
  }) async {
    Map<String, dynamic> fields(String prefix, PlatformSettingsInput input) => {
      '${prefix}_mode': input.mode.wireValue,
      '${prefix}_locale': input.locale,
      if (input.apiKey != null && input.apiKey!.trim().isNotEmpty) '${prefix}_api_key': input.apiKey!.trim(),
      '${prefix}_clear_key': input.clearKey,
    };
    final json = await _api.put(
      '/v1/syndication',
      data: {
        ...fields('devto', devto),
        ...fields('hashnode', hashnode),
        'hashnode_publication_id': hashnodePublicationId == null || hashnodePublicationId.trim().isEmpty
            ? null
            : hashnodePublicationId.trim(),
      },
    );
    return SyndicationSettings.fromJson(json as Map<String, dynamic>);
  }

  /// Les blogs du compte du jeton Hashnode enregistré ; vide sans jeton.
  Future<List<HashnodePublication>> hashnodePublications() async {
    final json = await _api.get('/v1/syndication/hashnode-publications') as List<dynamic>;
    return [
      for (final item in json.cast<Map<String, dynamic>>())
        (id: item['id'] as String, title: item['title'] as String? ?? '', url: item['url'] as String? ?? ''),
    ];
  }

  Future<PostDistribution> distribution(int postId) async =>
      PostDistribution.fromJson(await _api.get('/v1/posts/$postId/syndications') as Map<String, dynamic>);

  /// Publie l'article (ou met à jour la version republiée). À n'appeler qu'après confirmation.
  /// Un échec de la plateforme arrive en [ValidationException] avec son message.
  Future<PostSyndication> syndicate(int postId, SyndicationPlatform platform) async => PostSyndication.fromJson(
    await _api.post('/v1/posts/$postId/syndications/${platform.wireValue}', receiveTimeout: const Duration(seconds: 60))
        as Map<String, dynamic>,
  );

  Future<SocialKit> saveSocialTexts(int postId, String locale, Map<SocialNetwork, String> texts) async {
    final json = await _api.put(
      '/v1/posts/$postId/social-texts',
      data: {
        'locale': locale,
        'texts': {
          for (final network in SocialNetwork.values)
            network.wireValue: (texts[network]?.trim().isEmpty ?? true) ? null : texts[network]!.trim(),
        },
      },
    );
    return SocialKit.fromJson(json as Map<String, dynamic>);
  }

  /// L'IA rédige les textes de la langue et les enregistre sur l'article.
  Future<SocialKit> generateSocialTexts(int postId, String locale) async => SocialKit.fromJson(
    await _api.post('/v1/posts/$postId/social-texts/$locale', receiveTimeout: const Duration(seconds: 90))
        as Map<String, dynamic>,
  );
}
