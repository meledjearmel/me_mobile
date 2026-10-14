import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';

/// Contenu visé par un appel, avec son lien d'administration s'il existe encore.
typedef McpActivityTarget = ({String label, String? url});

/// Un appel d'outil ou de commande du serveur MCP (`GET /v1/mcp-activity`).
@immutable
class McpActivity {
  const McpActivity({
    required this.id,
    required this.client,
    required this.kind,
    required this.name,
    required this.title,
    required this.success,
    required this.durationMs,
    this.target,
    this.error,
    this.createdAt,
  });

  factory McpActivity.fromJson(Map<String, dynamic> json) {
    final target = json['target'];
    return McpActivity(
      id: json['id'] as int,
      client: json['client'] as String? ?? '',
      kind: json['kind'] as String? ?? 'tool',
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      target: target is Map<String, dynamic>
          ? (label: target['label'] as String? ?? '', url: target['url'] as String?)
          : null,
      success: json['success'] as bool? ?? true,
      error: json['error'] as String?,
      durationMs: json['duration_ms'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
    );
  }

  final int id;

  /// Nom du jeton ou du connecteur (« Claude », « Claude Code »…).
  final String client;

  /// `tool` ou `prompt` (commande).
  final String kind;

  /// Nom technique (`get-project`) et titre lisible.
  final String name;
  final String title;
  final McpActivityTarget? target;
  final bool success;
  final String? error;
  final int durationMs;
  final DateTime? createdAt;

  bool get isPrompt => kind == 'prompt';
}

/// Clients et outils présents dans le journal, pour remplir les filtres.
@immutable
class McpActivityFilterOptions {
  const McpActivityFilterOptions({this.clients = const [], this.tools = const []});

  factory McpActivityFilterOptions.fromJson(Map<String, dynamic>? json) => McpActivityFilterOptions(
    clients: [for (final c in json?['clients'] as List<dynamic>? ?? const []) c as String],
    tools: [
      for (final t in json?['tools'] as List<dynamic>? ?? const [])
        if (t is Map<String, dynamic>)
          (value: t['value'] as String, label: t['label'] as String? ?? t['value'] as String),
    ],
  );

  final List<String> clients;
  final List<({String value, String label})> tools;
}

/// Une page du journal et les valeurs possibles des filtres.
typedef McpActivityPage = ({Paginated<McpActivity> page, McpActivityFilterOptions filters});

final mcpActivityRepositoryProvider = Provider<McpActivityRepository>(
  (ref) => McpActivityRepository(ref.watch(apiClientProvider)),
);

/// `GET /v1/mcp-activity` : journal paginé (90 jours conservés), du plus récent au plus ancien.
class McpActivityRepository {
  const McpActivityRepository(this._api);

  final ApiClient _api;

  /// [kind] : `tool` ou `prompt` ; [status] : `success` ou `error` ; [days] : 1, 7 ou 30.
  Future<McpActivityPage> list({
    required int page,
    String search = '',
    String? client,
    String? name,
    String? kind,
    String? status,
    int? days,
  }) async {
    final json = await _api.get(
      '/v1/mcp-activity',
      query: {
        'page': page,
        'per_page': 25,
        'search': search,
        'client': client,
        'name': name,
        'kind': kind,
        'status': status,
        'days': days,
      },
    ) as Map<String, dynamic>;
    return (
      page: Paginated.fromJson(json, McpActivity.fromJson),
      filters: McpActivityFilterOptions.fromJson(json['filters'] as Map<String, dynamic>?),
    );
  }
}
