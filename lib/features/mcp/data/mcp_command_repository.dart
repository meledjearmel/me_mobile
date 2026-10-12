import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'mcp_command.dart';

final mcpCommandRepositoryProvider = Provider<McpCommandRepository>(
  (ref) => McpCommandRepository(ref.watch(apiClientProvider)),
);

/// `GET /v1/mcp-commands` : mode d'emploi du serveur MCP du portfolio.
class McpCommandRepository {
  const McpCommandRepository(this._api);

  final ApiClient _api;

  Future<McpCommands> get() async {
    final json = await _api.get('/v1/mcp-commands') as Map<String, dynamic>;
    return McpCommands.fromJson(json['data'] as Map<String, dynamic>);
  }
}
