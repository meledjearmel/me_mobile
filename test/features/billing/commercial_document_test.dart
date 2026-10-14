import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_exception.dart';
import 'package:me_mobile/features/billing/data/commercial_document.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _quoteJson = {
  'id': 3,
  'type': 'quote',
  'status': 'issued',
  'number': 'ADEV-DEV-2026-001',
  'engagement_id': 5,
  'source_id': null,
  'locale': 'fr',
  'client_name': 'Awa Koné',
  'client_email': 'awa@acme.ci',
  'client_company': 'Acme',
  'client_address': null,
  'title': 'Site vitrine',
  'currency': 'XOF',
  'lines': [
    {'label': 'Développement', 'description': null, 'quantity': 40, 'unit': 'hour', 'unit_price': 25000},
    {'label': 'Mise en ligne', 'description': 'Hébergement', 'quantity': 1, 'unit': 'flat', 'unit_price': 50000},
  ],
  'total': 1050000,
  'deposit_percent': 30,
  'deposit_amount': 315000,
  'payment_terms': 'À 30 jours',
  'notes': null,
  'issued_at': '2026-10-01',
  'valid_until': '2026-10-31',
  'due_at': null,
  'public_url': 'https://armeldev.xyz/devis/abc',
  'sent_at': '2026-10-01T10:00:00Z',
  'accepted_at': null,
  'declined_at': null,
  'paid_at': null,
  'reminders_count': 0,
  'last_reminded_at': null,
  'reminder_due_at': '2026-10-08T10:00:00Z',
  'created_at': '2026-09-30T10:00:00Z',
};

void main() {
  test('CommercialDocument lit les lignes, le total et ce qui reste à faire', () {
    final document = CommercialDocument.fromJson(_quoteJson);

    expect(document.displayName, 'Devis ADEV-DEV-2026-001');
    expect(document.client, 'Acme');
    expect(document.lines.first.amount, 1000000);
    expect(document.lines.first.unit, LineUnit.hour);
    expect(document.hasReminder, isTrue);
    expect(document.deadline, document.validUntil);
    expect(document.nextStatuses, [DocumentStatus.accepted, DocumentStatus.declined, DocumentStatus.cancelled]);
  });

  test('une facture émise dont l\'échéance est passée est en retard ; payée, elle ne l\'est plus', () {
    final invoice = CommercialDocument.fromJson({..._quoteJson, 'type': 'invoice', 'due_at': '2020-01-01'});

    expect(invoice.isOverdue, isTrue);
    expect(invoice.nextStatuses, [DocumentStatus.paid, DocumentStatus.cancelled]);
    expect(
      CommercialDocument.fromJson({..._quoteJson, 'type': 'invoice', 'status': 'paid', 'due_at': '2020-01-01'})
          .isOverdue,
      isFalse,
    );
  });

  test('DocumentLine.toJson garde une quantité entière et vide la description blanche', () {
    expect(
      const DocumentLine(
        label: ' Design ',
        description: '  ',
        quantity: 3,
        unit: LineUnit.day,
        unitPrice: 100,
      ).toJson(),
      {'label': 'Design', 'description': null, 'quantity': 3, 'unit': 'day', 'unit_price': 100},
    );
    expect(const DocumentLine(label: 'x', quantity: 1.5).toJson()['quantity'], 1.5);
  });

  late FakeDioAdapter adapter;
  late CommercialDocumentRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = CommercialDocumentRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list envoie les filtres, « reminder » seulement quand on le demande', () async {
    adapter.whenRequest(
      'GET',
      '/v1/commercial-documents',
      statusCode: 200,
      body: {
        'data': [_quoteJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    await repository.list(page: 1, type: 'quote');
    await repository.list(page: 1, reminder: true);

    expect(adapter.requests.first.queryParameters.containsKey('reminder'), isFalse);
    expect(adapter.requests.first.queryParameters['type'], 'quote');
    expect(adapter.requests.last.queryParameters['reminder'], 1);
  });

  test('create envoie le type, les lignes et les dates au format AAAA-MM-JJ', () async {
    adapter.whenRequest('POST', '/v1/commercial-documents', statusCode: 201, body: {..._quoteJson, 'status': 'draft'});

    await repository.create(
      DocumentType.invoice,
      DocumentDraft(
        locale: 'fr',
        clientName: 'Awa',
        clientEmail: ' ',
        title: 'Site',
        currency: 'XOF',
        lines: const [DocumentLine(label: 'Dev', quantity: 2, unit: LineUnit.hour, unitPrice: 25000)],
        depositPercent: 30,
        dueAt: DateTime(2026, 11, 15),
      ),
    );

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data['type'], 'invoice');
    expect(data['client_email'], isNull);
    expect(data['due_at'], '2026-11-15');
    expect(data['valid_until'], isNull);
    expect((data['lines'] as List).single, {
      'label': 'Dev',
      'description': null,
      'quantity': 2,
      'unit': 'hour',
      'unit_price': 25000,
    });
  });

  test('suggestMail demande une relance avec reminder=1, send et remind envoient l\'e-mail relu', () async {
    adapter
      ..whenRequest(
        'POST',
        '/v1/commercial-documents/3/suggest-mail',
        statusCode: 200,
        body: {'subject': 'Relance', 'message': 'Bonjour'},
      )
      ..whenRequest('POST', '/v1/commercial-documents/3/send', statusCode: 200, body: _quoteJson)
      ..whenRequest('POST', '/v1/commercial-documents/3/remind', statusCode: 200, body: _quoteJson);

    final mail = await repository.suggestMail(3, reminder: true);
    await repository.send(3, mail);
    await repository.remind(3, (subject: 'Objet', message: 'Texte'));

    expect(adapter.requests.first.queryParameters['reminder'], 1);
    expect(mail.subject, 'Relance');
    expect(adapter.requests[1].data, {'subject': 'Relance', 'message': 'Bonjour'});
    expect(adapter.requests[2].data, {'subject': 'Objet', 'message': 'Texte'});
  });

  test('issue, convert, statut, relance écartée et brouillon depuis une demande', () async {
    adapter
      ..whenRequest('POST', '/v1/commercial-documents/3/issue', statusCode: 200, body: _quoteJson)
      ..whenRequest(
        'POST',
        '/v1/commercial-documents/3/convert',
        statusCode: 201,
        body: {..._quoteJson, 'id': 4, 'type': 'invoice'},
      )
      ..whenRequest(
        'PUT',
        '/v1/commercial-documents/3/status',
        statusCode: 200,
        body: {..._quoteJson, 'status': 'accepted'},
      )
      ..whenRequest(
        'DELETE',
        '/v1/commercial-documents/3/reminder',
        statusCode: 200,
        body: {..._quoteJson, 'reminder_due_at': null},
      )
      ..whenRequest('POST', '/v1/engagements/5/documents', statusCode: 201, body: {..._quoteJson, 'status': 'draft'});

    await repository.issue(3);
    final invoice = await repository.convert(3, DocumentType.invoice);
    final accepted = await repository.setStatus(3, DocumentStatus.accepted);
    final dismissed = await repository.dismissReminder(3);
    final draft = await repository.fromEngagement(5);

    expect(invoice.type, DocumentType.invoice);
    expect(adapter.requests[1].data, {'type': 'invoice'});
    expect(accepted.status, DocumentStatus.accepted);
    expect(dismissed.hasReminder, isFalse);
    expect(draft.isDraft, isTrue);
    expect(adapter.requests.last.data, {'type': 'quote'});
  });

  test('modifier un document émis est refusé par l\'API (409)', () async {
    adapter.whenRequest(
      'PUT',
      '/v1/commercial-documents/3',
      statusCode: 409,
      body: {'message': 'Un document émis ne se modifie plus.'},
    );

    expect(
      () => repository.update(
        3,
        const DocumentDraft(locale: 'fr', clientName: 'A', title: 'T', currency: 'XOF', lines: [], depositPercent: 0),
      ),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Un document émis ne se modifie plus.')),
    );
  });
}
