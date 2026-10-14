import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/billing_settings.dart';
import '../data/commercial_document.dart';
import 'documents_list_screen.dart';

/// Champs d'une ligne en cours de saisie.
class _LineForm {
  _LineForm([DocumentLine? line])
    : label = TextEditingController(text: line?.label ?? ''),
      description = TextEditingController(text: line?.description ?? ''),
      quantity = TextEditingController(text: line == null ? '1' : _formatQuantity(line.quantity)),
      unitPrice = TextEditingController(text: line == null ? '' : '${line.unitPrice}'),
      unit = line?.unit ?? LineUnit.flat;

  static int _nextKey = 0;

  final key = ValueKey(_nextKey++);
  final TextEditingController label;
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  LineUnit unit;

  static String _formatQuantity(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value'.replaceAll('.', ',');

  DocumentLine get line => DocumentLine(
    label: label.text,
    description: description.text,
    quantity: double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0,
    unit: unit,
    unitPrice: int.tryParse(unitPrice.text.replaceAll(RegExp(r'\s'), '')) ?? 0,
  );

  void dispose() {
    label.dispose();
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}

/// Création d'un brouillon ([type]) ou modification d'un brouillon existant
/// ([document]). Renvoie le document enregistré. Un document émis ne se modifie plus.
class DocumentFormScreen extends ConsumerStatefulWidget {
  const DocumentFormScreen({super.key, this.type = DocumentType.quote, this.document});

  final DocumentType type;
  final CommercialDocument? document;

  @override
  ConsumerState<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends ConsumerState<DocumentFormScreen> {
  static const _currencies = ['XOF', 'EUR', 'USD', 'CHF'];

  late final CommercialDocument? _document = widget.document;
  late final DocumentType _type = _document?.type ?? widget.type;

  late final _clientName = TextEditingController(text: _document?.clientName ?? '');
  late final _clientEmail = TextEditingController(text: _document?.clientEmail ?? '');
  late final _clientCompany = TextEditingController(text: _document?.clientCompany ?? '');
  late final _clientAddress = TextEditingController(text: _document?.clientAddress ?? '');
  late final _title = TextEditingController(text: _document?.title ?? '');
  // À la création : préremplis depuis les réglages de facturation (voir initState).
  late final _deposit = TextEditingController(text: _document == null ? '0' : '${_document.depositPercent}');
  late final _paymentTerms = TextEditingController(text: _document?.paymentTerms ?? '');
  late final _notes = TextEditingController(text: _document?.notes ?? '');
  late String _locale = _document?.locale ?? 'fr';
  late String _currency = _document?.currency ?? 'XOF';
  late DateTime? _deadline = _document?.deadline;
  late final List<_LineForm> _lines = [
    for (final line in _document?.lines ?? const <DocumentLine>[]) _LineForm(line),
    if (_document == null || _document.lines.isEmpty) _LineForm(),
  ];

  bool _dirty = false;
  bool _saving = false;
  String? _error;
  ValidationException? _validation;

  bool get _isQuote => _type == DocumentType.quote;

  @override
  void initState() {
    super.initState();
    if (_document == null) {
      _loadDefaults();
    }
  }

  /// Acompte et conditions de paiement par défaut, tant qu'ils n'ont pas été touchés.
  Future<void> _loadDefaults() async {
    try {
      final settings = await ref.read(billingSettingsRepositoryProvider).get();
      if (!mounted || _dirty) {
        return;
      }
      setState(() {
        _deposit.text = '${settings.numbers['billing_deposit_percent'] ?? 0}';
        _paymentTerms.text = settings.texts['billing_payment_terms'] ?? '';
      });
    } on ApiException {
      // Sans réglages, on garde 0 % et des conditions vides.
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _clientName,
      _clientEmail,
      _clientCompany,
      _clientAddress,
      _title,
      _deposit,
      _paymentTerms,
      _notes,
    ]) {
      controller.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  int get _total => _lines.fold(0, (sum, form) => sum + form.line.amount);

  Future<void> _handlePopAttempt() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner les modifications ?'),
        content: const Text('Vos changements non enregistrés seront perdus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuer l\'édition')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abandonner')),
        ],
      ),
    );
    if (leave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    final draft = DocumentDraft(
      engagementId: _document?.engagementId,
      locale: _locale,
      clientName: _clientName.text,
      clientEmail: _clientEmail.text,
      clientCompany: _clientCompany.text,
      clientAddress: _clientAddress.text,
      title: _title.text,
      currency: _currency,
      lines: [for (final form in _lines) form.line],
      depositPercent: int.tryParse(_deposit.text) ?? 0,
      paymentTerms: _paymentTerms.text,
      notes: _notes.text,
      validUntil: _isQuote ? _deadline : null,
      dueAt: _isQuote ? null : _deadline,
    );
    try {
      final repository = ref.read(commercialDocumentRepositoryProvider);
      final saved = _document == null
          ? await repository.create(_type, draft)
          : await repository.update(_document.id, draft);
      _dirty = false;
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } on ValidationException catch (e) {
      setState(() => _validation = e);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    int maxLines = 1,
    TextInputType? keyboard,
  }) => TextField(
    controller: controller,
    minLines: maxLines > 1 ? 2 : 1,
    maxLines: maxLines,
    keyboardType: keyboard,
    onChanged: (_) => _markDirty(),
    decoration: InputDecoration(
      labelText: label,
      alignLabelWithHint: maxLines > 1,
      errorText: _validation?.errorFor(key),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final v = _validation;
    final linesError = v?.errorFor('lines') ?? (v?.hasErrorUnder('lines') ?? false ? 'Vérifie les lignes.' : null);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handlePopAttempt();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: const GlassAppBar(),
        bottomNavigationBar: SaveBar(
          onPressed: _save,
          saving: _saving,
          label: 'Enregistrer · ${formatMoney(_total, _currency)} HT',
        ),
        body: ListView(
          padding: pageInsets(context),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FormHeader(
                title: _document == null ? '${_type.label} : brouillon' : 'Modifier le brouillon',
                subtitle: 'Numéroté et figé à l\'émission. Les valeurs vides reprennent les réglages de facturation.',
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
            FormSection(
              title: 'Client',
              hasError: [
                'client_name',
                'client_email',
                'client_company',
                'client_address',
              ].any((k) => v?.errorFor(k) != null),
              children: [
                _field(_clientName, 'Nom du contact', 'client_name'),
                _field(_clientCompany, 'Société (facultatif)', 'client_company'),
                _field(_clientEmail, 'E-mail', 'client_email', keyboard: TextInputType.emailAddress),
                _field(_clientAddress, 'Adresse', 'client_address', maxLines: 4),
              ],
            ),
            const SizedBox(height: 12),
            FormSection(
              title: 'Document',
              hasError: ['title', 'currency', 'locale'].any((k) => v?.errorFor(k) != null),
              children: [
                _field(_title, 'Titre (le projet)', 'title'),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [for (final c in _currencies) ButtonSegment(value: c, label: Text(c))],
                  selected: {_currency},
                  onSelectionChanged: (selection) {
                    setState(() => _currency = selection.first);
                    _markDirty();
                  },
                ),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'fr', label: Text('En français')),
                    ButtonSegment(value: 'en', label: Text('En anglais')),
                  ],
                  selected: {_locale},
                  onSelectionChanged: (selection) {
                    setState(() => _locale = selection.first);
                    _markDirty();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(child: Text('Lignes', style: theme.textTheme.titleMedium)),
                  Text(formatMoney(_total, _currency), style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            if (linesError != null) ...[
              const SizedBox(height: 4),
              Text(linesError, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
            for (final (index, form) in _lines.indexed) ...[
              const SizedBox(height: 10),
              _LineCard(
                key: form.key,
                form: form,
                currency: _currency,
                errorFor: (field) => v?.errorFor('lines.$index.$field'),
                onChanged: _markDirty,
                onRemove: _lines.length == 1
                    ? null
                    : () {
                        setState(() => _lines.removeAt(index).dispose());
                        _markDirty();
                      },
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _lines.length >= 50
                  ? null
                  : () {
                      setState(() => _lines.add(_LineForm()));
                      _markDirty();
                    },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une ligne'),
            ),
            const SizedBox(height: 12),
            FormSection(
              title: 'Conditions',
              hasError: [
                'deposit_percent',
                'payment_terms',
                'notes',
                'valid_until',
                'due_at',
              ].any((k) => v?.errorFor(k) != null),
              children: [
                DateField(
                  label: _isQuote ? 'Valable jusqu\'au' : 'Échéance de paiement',
                  value: _deadline,
                  allowClear: true,
                  emptyLabel: 'Selon les réglages',
                  error: v?.errorFor(_isQuote ? 'valid_until' : 'due_at'),
                  onChanged: (date) {
                    setState(() => _deadline = date);
                    _markDirty();
                  },
                ),
                TextField(
                  controller: _deposit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _markDirty(),
                  decoration: InputDecoration(
                    labelText: 'Acompte',
                    suffixText: '%',
                    errorText: v?.errorFor('deposit_percent'),
                  ),
                ),
                _field(_paymentTerms, 'Conditions de paiement', 'payment_terms', maxLines: 4),
                _field(_notes, 'Notes', 'notes', maxLines: 4),
                Text('Montants hors taxes, selon la mention de TVA des réglages.', style: muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    super.key,
    required this.form,
    required this.currency,
    required this.errorFor,
    required this.onChanged,
    required this.onRemove,
  });

  final _LineForm form;
  final String currency;
  final String? Function(String field) errorFor;
  final VoidCallback onChanged;

  /// `null` : dernière ligne, qu'on ne retire pas (un document en a au moins une).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: form.label,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(labelText: 'Libellé', errorText: errorFor('label')),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Retirer la ligne',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: form.description,
            minLines: 1,
            maxLines: 4,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(labelText: 'Description (facultatif)', errorText: errorFor('description')),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: form.quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(labelText: 'Quantité', errorText: errorFor('quantity')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<LineUnit>(
                  initialValue: form.unit,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Unité'),
                  items: [for (final u in LineUnit.values) DropdownMenuItem(value: u, child: Text(u.label))],
                  onChanged: (unit) {
                    form.unit = unit ?? form.unit;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: form.unitPrice,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: 'Prix unitaire',
              suffixText: currency,
              errorText: errorFor('unit_price'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(formatMoney(form.line.amount, currency), style: theme.textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}
