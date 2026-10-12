import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/mcp_command.dart';
import '../data/mcp_command_repository.dart';

final mcpCommandsProvider = FutureProvider.autoDispose<McpCommands>(
  (ref) => ref.watch(mcpCommandRepositoryProvider).get(),
);

void _copy(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copié')));
}

/// « Serveur MCP » : adresse du serveur, commandes et outils du portfolio à
/// utiliser avec Claude ou ChatGPT, avec leur mode d'emploi.
class McpCommandsScreen extends ConsumerStatefulWidget {
  const McpCommandsScreen({super.key});

  @override
  ConsumerState<McpCommandsScreen> createState() => _McpCommandsScreenState();
}

class _McpCommandsScreenState extends ConsumerState<McpCommandsScreen> {
  McpCommandKind _kind = McpCommandKind.prompt;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final state = ref.watch(mcpCommandsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(),
      body: Builder(
        builder: (context) => RefreshIndicator(
          onRefresh: () => ref.refresh(mcpCommandsProvider.future),
          child: ListView(
            padding: pageInsets(context),
            children: [
              Text('Serveur MCP', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('Commandes et outils à utiliser avec Claude ou ChatGPT', style: muted),
              const SizedBox(height: 16),
              ...state.when(
                loading: () => const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (error, _) => [
                  Text(error is ApiException ? error.message : 'Erreur.'),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: () => ref.invalidate(mcpCommandsProvider),
                      child: const Text('Réessayer'),
                    ),
                  ),
                ],
                data: (data) => _content(context, data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, McpCommands data) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final list = _kind == McpCommandKind.prompt ? data.prompts : data.tools;
    final visible = list.where((command) => command.matches(_query)).toList();

    return [
      SurfaceCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adresse', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(data.serverUrl, style: _mono(context)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copier l\'adresse',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () => _copy(context, data.serverUrl),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PillFilterChip(
            label: 'Commandes (${data.prompts.length})',
            selected: _kind == McpCommandKind.prompt,
            onTap: () => setState(() => _kind = McpCommandKind.prompt),
          ),
          PillFilterChip(
            label: 'Outils (${data.tools.length})',
            selected: _kind == McpCommandKind.tool,
            onTap: () => setState(() => _kind = McpCommandKind.tool),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        onChanged: (value) => setState(() => _query = value),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Rechercher…'),
      ),
      const SizedBox(height: 16),
      if (visible.isEmpty)
        Text(list.isEmpty ? 'Aucun élément.' : 'Aucun résultat.', style: muted)
      else
        for (final command in visible) ...[
          SurfaceCard(
            onTap: () => showMcpCommandSheet(context, command),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(command.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(command.name, style: _mono(context, muted: true)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
    ];
  }
}

TextStyle? _mono(BuildContext context, {bool muted = false}) {
  final theme = Theme.of(context);
  return theme.textTheme.bodySmall?.copyWith(
    fontFamily: 'monospace',
    color: muted ? theme.colorScheme.onSurfaceVariant : null,
  );
}

/// Fiche d'une commande : phrases à écrire en premier (l'usage sur mobile),
/// puis commande, conseils, arguments et description transmise à l'agent.
void showMcpCommandSheet(BuildContext context, McpCommand command) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => _CommandSheet(command: command, controller: controller),
    ),
  );
}

class _CommandSheet extends StatelessWidget {
  const _CommandSheet({required this.command, required this.controller});

  final McpCommand command;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: 24);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(command.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(command.name, style: _mono(context, muted: true)),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: StatusBadge(command.kind.label)),
        if (command.usage.isNotEmpty) ...[const SizedBox(height: 12), Text(command.usage)],
        if (command.requests.isNotEmpty) ...[
          gap,
          const SectionHeader('À écrire dans la conversation'),
          const SizedBox(height: 8),
          for (final request in command.requests) ...[_CopyBlock(text: request), const SizedBox(height: 8)],
        ],
        if (command.kind == McpCommandKind.prompt && command.example.isNotEmpty) ...[
          gap,
          const SectionHeader('Commande (Claude Code, Codex)'),
          const SizedBox(height: 8),
          _CopyBlock(text: command.example, monospace: true),
        ],
        if (command.tips.isNotEmpty) ...[
          gap,
          const SectionHeader('Pour bien l\'utiliser'),
          const SizedBox(height: 8),
          for (final tip in command.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(tip)),
                ],
              ),
            ),
        ],
        if (command.arguments.isNotEmpty) ...[
          gap,
          const SectionHeader('Arguments'),
          const SizedBox(height: 8),
          for (final argument in command.arguments)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: argument.name,
                          style: _mono(context)?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (argument.required)
                          TextSpan(
                            text: '  obligatoire',
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                          ),
                      ],
                    ),
                  ),
                  if (argument.description.isNotEmpty) Text(argument.description),
                ],
              ),
            ),
        ],
        if (command.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: const Text('Description transmise à l\'agent'),
            children: [SelectableText(command.description)],
          ),
        ],
      ],
    );
  }
}

/// Bloc de texte à copier tel quel.
class _CopyBlock extends StatelessWidget {
  const _CopyBlock({required this.text, this.monospace = false});

  final String text;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: SelectableText(text, style: monospace ? _mono(context) : null)),
          IconButton(tooltip: 'Copier', icon: const Icon(Icons.copy_rounded), onPressed: () => _copy(context, text)),
        ],
      ),
    );
  }
}
