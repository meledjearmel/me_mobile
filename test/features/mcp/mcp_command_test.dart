import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/features/mcp/data/mcp_command.dart';

const _json = {
  'server_url': 'https://armeldev.xyz/mcp/portfolio',
  'prompts': [
    {
      'name': 'draft-project',
      'title': 'Rédiger un projet',
      'kind': 'prompt',
      'description': 'Description pour l\'agent.',
      'usage': 'Rédiger l\'étude de cas du projet ouvert.',
      'tips': ['Lancez-la depuis le dossier du projet.'],
      'example': '/mcp__portfolio__draft-project notes="…"',
      'requests': ['Rédige l\'étude de cas de ce projet pour mon portfolio.'],
      'arguments': [
        {'name': 'notes', 'description': 'Ce que le code ne dit pas.', 'required': false},
        {'name': 'repository', 'description': 'Dépôt.', 'required': true},
      ],
    },
  ],
  'tools': [
    {
      'name': 'get-project',
      'title': 'Lire un projet',
      'kind': 'tool',
      'description': 'Lit un projet.',
      'usage': 'Relire une étude de cas.',
      'tips': [],
      'example': 'Montre-moi le projet Gestion de stock.',
      'requests': ['Montre-moi le projet Gestion de stock.'],
      'arguments': [],
    },
  ],
};

void main() {
  test('lit l\'adresse, les commandes, les outils et leurs arguments', () {
    final data = McpCommands.fromJson(_json);

    expect(data.serverUrl, 'https://armeldev.xyz/mcp/portfolio');
    final prompt = data.prompts.single;
    expect(prompt.kind, McpCommandKind.prompt);
    expect(prompt.kind.label, 'Commande');
    expect(prompt.requests, hasLength(1));
    expect(prompt.example, startsWith('/mcp__portfolio__'));
    expect(prompt.arguments.last.required, isTrue);
    expect(prompt.arguments.first.name, 'notes');

    final tool = data.tools.single;
    expect(tool.kind, McpCommandKind.tool);
    expect(tool.arguments, isEmpty);
  });

  test('recherche insensible aux accents et à la casse', () {
    final data = McpCommands.fromJson(_json);
    final prompt = data.prompts.single;

    expect(prompt.matches('REDIGER'), isTrue);
    expect(prompt.matches('etude de cas'), isTrue);
    expect(prompt.matches('draft-'), isTrue);
    expect(prompt.matches('  '), isTrue);
    expect(prompt.matches('facture'), isFalse);
    expect(data.tools.single.matches('gestion de stock'), isTrue);
  });

  test('champs absents : valeurs par défaut', () {
    final command = McpCommand.fromJson({'name': 'x', 'kind': 'tool'});

    expect(command.title, 'x');
    expect(command.tips, isEmpty);
    expect(command.requests, isEmpty);
    expect(McpCommands.fromJson({}).prompts, isEmpty);
  });
}
