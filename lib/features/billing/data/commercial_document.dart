import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import '../../../core/utils/date_only.dart';

/// Devis, proforma ou facture, chacun avec son préfixe de numéro.
enum DocumentType {
  quote('quote', 'Devis', 'ADEV-DEV'),
  proforma('proforma', 'Proforma', 'ADEV-PRO'),
  invoice('invoice', 'Facture', 'ADEV-FAC');

  const DocumentType(this.wireValue, this.label, this.prefix);

  final String wireValue;
  final String label;
  final String prefix;

  static DocumentType fromWire(String? value) => values.firstWhere((t) => t.wireValue == value, orElse: () => quote);
}

/// Cycle d'un document : brouillon modifiable, émis (numéroté, figé), puis
/// accepté ou refusé (devis), payé (proforma, facture) ou annulé.
enum DocumentStatus {
  draft('draft', 'Brouillon'),
  issued('issued', 'Émis'),
  accepted('accepted', 'Accepté'),
  declined('declined', 'Refusé'),
  paid('paid', 'Payé'),
  cancelled('cancelled', 'Annulé');

  const DocumentStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static DocumentStatus fromWire(String? value) => values.firstWhere((s) => s.wireValue == value, orElse: () => draft);
}

enum LineUnit {
  hour('hour', 'heure', 'h'),
  day('day', 'jour', 'j'),
  flat('flat', 'forfait', 'forfait');

  const LineUnit(this.wireValue, this.label, this.short);

  final String wireValue;
  final String label;
  final String short;

  static LineUnit fromWire(String? value) => values.firstWhere((u) => u.wireValue == value, orElse: () => flat);
}

/// Ligne d'un document : montants en unités de la devise, hors taxes.
@immutable
class DocumentLine {
  const DocumentLine({
    required this.label,
    this.description,
    this.quantity = 1,
    this.unit = LineUnit.flat,
    this.unitPrice = 0,
  });

  factory DocumentLine.fromJson(Map<String, dynamic> json) => DocumentLine(
    label: json['label'] as String? ?? '',
    description: json['description'] as String?,
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
    unit: LineUnit.fromWire(json['unit'] as String?),
    unitPrice: json['unit_price'] as int? ?? 0,
  );

  final String label;
  final String? description;
  final double quantity;
  final LineUnit unit;
  final int unitPrice;

  int get amount => (quantity * unitPrice).round();

  Map<String, dynamic> toJson() => {
    'label': label.trim(),
    'description': (description?.trim().isEmpty ?? true) ? null : description!.trim(),
    // Un entier reste entier à l'envoi (« 3 » plutôt que « 3.0 »).
    'quantity': quantity == quantity.roundToDouble() ? quantity.round() : quantity,
    'unit': unit.wireValue,
    'unit_price': unitPrice,
  };

  DocumentLine copyWith({String? label, String? description, double? quantity, LineUnit? unit, int? unitPrice}) =>
      DocumentLine(
        label: label ?? this.label,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        unitPrice: unitPrice ?? this.unitPrice,
      );
}

/// Devis, proforma ou facture (`/v1/commercial-documents`).
@immutable
class CommercialDocument {
  const CommercialDocument({
    required this.id,
    required this.type,
    required this.status,
    required this.locale,
    required this.clientName,
    required this.title,
    required this.currency,
    required this.lines,
    required this.total,
    this.number,
    this.engagementId,
    this.sourceId,
    this.clientEmail,
    this.clientCompany,
    this.clientAddress,
    this.depositPercent = 0,
    this.depositAmount = 0,
    this.paymentTerms,
    this.notes,
    this.issuedAt,
    this.validUntil,
    this.dueAt,
    this.publicUrl,
    this.sentAt,
    this.acceptedAt,
    this.declinedAt,
    this.paidAt,
    this.remindersCount = 0,
    this.lastRemindedAt,
    this.reminderDueAt,
    this.createdAt,
  });

  factory CommercialDocument.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => DateTime.tryParse(json[key] as String? ?? '')?.toLocal();
    return CommercialDocument(
      id: json['id'] as int,
      type: DocumentType.fromWire(json['type'] as String?),
      status: DocumentStatus.fromWire(json['status'] as String?),
      number: json['number'] as String?,
      engagementId: json['engagement_id'] as int?,
      sourceId: json['source_id'] as int?,
      locale: json['locale'] as String? ?? 'fr',
      clientName: json['client_name'] as String? ?? '',
      clientEmail: json['client_email'] as String?,
      clientCompany: json['client_company'] as String?,
      clientAddress: json['client_address'] as String?,
      title: json['title'] as String? ?? '',
      currency: json['currency'] as String? ?? 'XOF',
      lines: [
        for (final line in json['lines'] as List<dynamic>? ?? const [])
          DocumentLine.fromJson(line as Map<String, dynamic>),
      ],
      total: json['total'] as int? ?? 0,
      depositPercent: json['deposit_percent'] as int? ?? 0,
      depositAmount: json['deposit_amount'] as int? ?? 0,
      paymentTerms: json['payment_terms'] as String?,
      notes: json['notes'] as String?,
      issuedAt: date('issued_at'),
      validUntil: date('valid_until'),
      dueAt: date('due_at'),
      publicUrl: json['public_url'] as String?,
      sentAt: date('sent_at'),
      acceptedAt: date('accepted_at'),
      declinedAt: date('declined_at'),
      paidAt: date('paid_at'),
      remindersCount: json['reminders_count'] as int? ?? 0,
      lastRemindedAt: date('last_reminded_at'),
      reminderDueAt: date('reminder_due_at'),
      createdAt: date('created_at'),
    );
  }

  final int id;
  final DocumentType type;
  final DocumentStatus status;

  /// Attribué à l'émission (`ADEV-DEV-2026-001`) ; `null` pour un brouillon.
  final String? number;
  final int? engagementId;

  /// Document d'origine : le devis d'une proforma ou d'une facture.
  final int? sourceId;
  final String locale;
  final String clientName;
  final String? clientEmail;
  final String? clientCompany;
  final String? clientAddress;
  final String title;
  final String currency;
  final List<DocumentLine> lines;

  /// Somme des lignes, hors taxes.
  final int total;
  final int depositPercent;
  final int depositAmount;
  final String? paymentTerms;
  final String? notes;
  final DateTime? issuedAt;

  /// Devis : fin de validité.
  final DateTime? validUntil;

  /// Proforma et facture : échéance de paiement.
  final DateTime? dueAt;

  /// Devis émis : lien privé où le client le consulte et l'accepte.
  final String? publicUrl;
  final DateTime? sentAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? paidAt;
  final int remindersCount;
  final DateTime? lastRemindedAt;

  /// Relance suggérée depuis cette date ; `null` sinon.
  final DateTime? reminderDueAt;
  final DateTime? createdAt;

  bool get isDraft => status == DocumentStatus.draft;
  bool get isQuote => type == DocumentType.quote;

  /// Émis, en attente d'une réponse (devis) ou d'un paiement.
  bool get isOpen => status == DocumentStatus.issued;

  bool get hasReminder => reminderDueAt != null;

  /// Le client à afficher : sa société, sinon son nom.
  String get client => clientCompany?.trim().isNotEmpty == true ? clientCompany! : clientName;

  /// « Devis ADEV-DEV-2026-001 », ou « Devis (brouillon) ».
  String get displayName => '${type.label} ${number ?? '(brouillon)'}';

  /// Échéance (facture, proforma) ou fin de validité (devis).
  DateTime? get deadline => isQuote ? validUntil : dueAt;

  /// Facture ou proforma émise dont l'échéance est passée.
  bool get isOverdue => !isQuote && isOpen && dueAt != null && dueAt!.isBefore(DateTime.now());

  /// Statuts qu'on peut donner à un document émis.
  List<DocumentStatus> get nextStatuses => switch ((type, status)) {
    (DocumentType.quote, DocumentStatus.issued) => [
      DocumentStatus.accepted,
      DocumentStatus.declined,
      DocumentStatus.cancelled,
    ],
    (_, DocumentStatus.issued) => [DocumentStatus.paid, DocumentStatus.cancelled],
    (_, DocumentStatus.accepted) => [DocumentStatus.cancelled],
    _ => const [],
  };
}

/// Champs d'un brouillon, en création ou en modification.
@immutable
class DocumentDraft {
  const DocumentDraft({
    required this.locale,
    required this.clientName,
    required this.title,
    required this.currency,
    required this.lines,
    required this.depositPercent,
    this.engagementId,
    this.clientEmail,
    this.clientCompany,
    this.clientAddress,
    this.paymentTerms,
    this.notes,
    this.validUntil,
    this.dueAt,
  });

  final int? engagementId;
  final String locale;
  final String clientName;
  final String? clientEmail;
  final String? clientCompany;
  final String? clientAddress;
  final String title;
  final String currency;
  final List<DocumentLine> lines;
  final int depositPercent;
  final String? paymentTerms;
  final String? notes;
  final DateTime? validUntil;
  final DateTime? dueAt;

  Map<String, dynamic> toJson() {
    String? blank(String? value) => (value?.trim().isEmpty ?? true) ? null : value!.trim();
    return {
      'engagement_id': engagementId,
      'locale': locale,
      'client_name': clientName.trim(),
      'client_email': blank(clientEmail),
      'client_company': blank(clientCompany),
      'client_address': blank(clientAddress),
      'title': title.trim(),
      'currency': currency,
      'lines': [for (final line in lines) line.toJson()],
      'deposit_percent': depositPercent,
      'payment_terms': blank(paymentTerms),
      'notes': blank(notes),
      'valid_until': validUntil == null ? null : formatDateOnly(validUntil!),
      'due_at': dueAt == null ? null : formatDateOnly(dueAt!),
    };
  }
}

/// Objet et message d'un email proposé par l'IA, à relire avant l'envoi.
typedef DocumentMail = ({String subject, String message});

final commercialDocumentRepositoryProvider = Provider<CommercialDocumentRepository>(
  (ref) => CommercialDocumentRepository(ref.watch(apiClientProvider)),
);

/// `/v1/commercial-documents` et `POST /v1/engagements/{id}/documents`.
/// Un document émis ne se modifie ni ne se supprime plus (409) : il s'annule.
class CommercialDocumentRepository {
  const CommercialDocumentRepository(this._api);

  final ApiClient _api;

  static const _mailTimeout = Duration(seconds: 90);

  String _path(int id, [String action = '']) => '/v1/commercial-documents/$id${action.isEmpty ? '' : '/$action'}';

  CommercialDocument _document(dynamic json) => CommercialDocument.fromJson(json as Map<String, dynamic>);

  /// Du plus récent au plus ancien. [reminder] : seulement ceux dont une relance est suggérée.
  Future<Paginated<CommercialDocument>> list({
    required int page,
    String search = '',
    String? type,
    String? status,
    bool reminder = false,
  }) async {
    final json = await _api.get(
      '/v1/commercial-documents',
      query: {
        'page': page,
        'per_page': 25,
        'search': search,
        'type': type,
        'status': status,
        if (reminder) 'reminder': true,
      },
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, CommercialDocument.fromJson);
  }

  Future<CommercialDocument> get(int id) async => _document(await _api.get(_path(id)));

  /// Les valeurs absentes (acompte, conditions, validité, échéance) viennent des réglages.
  Future<CommercialDocument> create(DocumentType type, DocumentDraft draft) async =>
      _document(await _api.post('/v1/commercial-documents', data: {'type': type.wireValue, ...draft.toJson()}));

  Future<CommercialDocument> update(int id, DocumentDraft draft) async =>
      _document(await _api.put(_path(id), data: draft.toJson()));

  /// Brouillon seulement.
  Future<void> delete(int id) => _api.delete(_path(id));

  /// Reprend le client de la demande et les lignes de son estimation.
  Future<CommercialDocument> fromEngagement(int engagementId, {DocumentType type = DocumentType.quote}) async =>
      _document(await _api.post('/v1/engagements/$engagementId/documents', data: {'type': type.wireValue}));

  Future<Uint8List> pdf(int id) async => Uint8List.fromList(await _api.getBytes(_path(id, 'pdf')));

  /// Numérote et fige le brouillon.
  Future<CommercialDocument> issue(int id) async => _document(await _api.post(_path(id, 'issue')));

  /// Objet et message proposés par l'IA ; [reminder] pour une relance. 503 si l'IA est indisponible.
  Future<DocumentMail> suggestMail(int id, {bool reminder = false}) async {
    final json = await _api.post(
      _path(id, 'suggest-mail'),
      query: {'reminder': reminder ? true : null},
      receiveTimeout: _mailTimeout,
    ) as Map<String, dynamic>;
    return (subject: json['subject'] as String? ?? '', message: json['message'] as String? ?? '');
  }

  /// Émet le brouillon s'il le faut, puis l'envoie par email avec le PDF. Après confirmation.
  Future<CommercialDocument> send(int id, DocumentMail mail) async => _document(
    await _api.post(
      _path(id, 'send'),
      data: {'subject': mail.subject, 'message': mail.message},
      receiveTimeout: _mailTimeout,
    ),
  );

  /// Renvoie le PDF avec le message de relance. Après confirmation.
  Future<CommercialDocument> remind(int id, DocumentMail mail) async => _document(
    await _api.post(
      _path(id, 'remind'),
      data: {'subject': mail.subject, 'message': mail.message},
      receiveTimeout: _mailTimeout,
    ),
  );

  /// Écarte la relance suggérée, sans rien envoyer.
  Future<CommercialDocument> dismissReminder(int id) async => _document(await _api.delete(_path(id, 'reminder')));

  /// Crée un brouillon de proforma ou de facture qui reprend le document.
  Future<CommercialDocument> convert(int id, DocumentType type) async =>
      _document(await _api.post(_path(id, 'convert'), data: {'type': type.wireValue}));

  /// `accepted`, `declined` (devis), `paid` ou `cancelled`.
  Future<CommercialDocument> setStatus(int id, DocumentStatus status) async =>
      _document(await _api.put(_path(id, 'status'), data: {'status': status.wireValue}));
}
