import 'package:flutter/foundation.dart';

import '../../../core/utils/slugify.dart';

enum McpCommandKind {
  prompt('Commande'),
  tool('Outil');

  const McpCommandKind(this.label);

  final String label;

  static McpCommandKind fromWire(String? value) => value == 'tool' ? tool : prompt;
}

/// Argument d'une commande MCP.
@immutable
class McpArgument {
  const McpArgument({required this.name, required this.description, required this.required});

  factory McpArgument.fromJson(Map<String, dynamic> json) => McpArgument(
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    required: json['required'] as bool? ?? false,
  );

  final String name;
  final String description;
  final bool required;
}

/// Commande (prompt, lancée soi-même) ou outil (appelé par l'agent) du serveur
/// MCP du portfolio, avec son mode d'emploi.
@immutable
class McpCommand {
  const McpCommand({
    required this.name,
    required this.title,
    required this.kind,
    required this.description,
    required this.usage,
    this.tips = const [],
    this.example = '',
    this.requests = const [],
    this.arguments = const [],
  });

  factory McpCommand.fromJson(Map<String, dynamic> json) => McpCommand(
    name: json['name'] as String? ?? '',
    title: json['title'] as String? ?? json['name'] as String? ?? '',
    kind: McpCommandKind.fromWire(json['kind'] as String?),
    description: json['description'] as String? ?? '',
    usage: json['usage'] as String? ?? '',
    tips: [for (final tip in json['tips'] as List<dynamic>? ?? const []) '$tip'],
    example: json['example'] as String? ?? '',
    requests: [for (final request in json['requests'] as List<dynamic>? ?? const []) '$request'],
    arguments: [
      for (final item in json['arguments'] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic>) McpArgument.fromJson(item),
    ],
  );

  /// Nom technique (`draft-project`).
  final String name;
  final String title;
  final McpCommandKind kind;

  /// Description transmise à l'agent.
  final String description;

  /// Quand s'en servir.
  final String usage;
  final List<String> tips;

  /// Commande à taper dans Claude Code ou Codex.
  final String example;

  /// Phrases à écrire telles quelles dans claude.ai ou ChatGPT, mobile compris.
  final List<String> requests;
  final List<McpArgument> arguments;

  /// Recherche insensible aux accents et à la casse : titre, nom, usage et phrases.
  bool matches(String query) {
    final needle = foldAccents(query.trim());
    if (needle.isEmpty) {
      return true;
    }
    return [title, name, usage, ...requests].any((text) => foldAccents(text).contains(needle));
  }
}

/// `GET /v1/mcp-commands` : adresse du serveur, commandes et outils.
@immutable
class McpCommands {
  const McpCommands({required this.serverUrl, required this.prompts, required this.tools});

  factory McpCommands.fromJson(Map<String, dynamic> json) {
    List<McpCommand> list(String key) => [
      for (final item in json[key] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic>) McpCommand.fromJson(item),
    ];
    return McpCommands(serverUrl: json['server_url'] as String? ?? '', prompts: list('prompts'), tools: list('tools'));
  }

  final String serverUrl;
  final List<McpCommand> prompts;
  final List<McpCommand> tools;
}
