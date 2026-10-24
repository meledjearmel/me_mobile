import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import 'proposal.dart';

final proposalRepositoryProvider = Provider<ProposalRepository>(
  (ref) => ProposalRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/proposals` : propositions freelance (Upwork, Malt…).
class ProposalRepository {
  const ProposalRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Proposal>> list({required int page, String search = '', String? platform, String? status}) async {
    final json = await _api.get(
      '/v1/proposals',
      query: {'page': page, 'per_page': 25, 'search': search, 'platform': platform, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, Proposal.fromJson);
  }

  Future<Proposal> get(int id) async => Proposal.fromJson(_map(await _api.get('/v1/proposals/$id')));

  Future<Proposal> save({
    int? id,
    required ProposalPlatform platform,
    required String locale,
    required String jobTitle,
    String? clientName,
    String? jobUrl,
    String? jobPosting,
    required String body,
    String? screeningAnswers,
    String? bid,
    int? connects,
    required ProposalStatus status,
    String? notes,
  }) async {
    final data = {
      'platform': platform.wireValue,
      'locale': locale,
      'job_title': jobTitle,
      'client_name': _nullIfBlank(clientName),
      'job_url': _nullIfBlank(jobUrl),
      'job_posting': _nullIfBlank(jobPosting),
      'body': body,
      'screening_answers': _nullIfBlank(screeningAnswers),
      'bid': _nullIfBlank(bid),
      'connects': connects,
      'status': status.wireValue,
      'notes': _nullIfBlank(notes),
    };
    final json = id == null
        ? await _api.post('/v1/proposals', data: data)
        : await _api.put('/v1/proposals/$id', data: data);
    return Proposal.fromJson(_map(json));
  }

  /// Change le statut seul : `PUT` attend l'objet complet, tous les champs sont renvoyés.
  Future<Proposal> updateStatus(Proposal proposal, ProposalStatus status) => save(
    id: proposal.id,
    platform: proposal.platform,
    locale: proposal.locale,
    jobTitle: proposal.jobTitle,
    clientName: proposal.clientName,
    jobUrl: proposal.jobUrl,
    jobPosting: proposal.jobPosting,
    body: proposal.body,
    screeningAnswers: proposal.screeningAnswers,
    bid: proposal.bid,
    connects: proposal.connects,
    status: status,
    notes: proposal.notes,
  );

  Future<void> delete(int id) => _api.delete('/v1/proposals/$id');

  static Map<String, dynamic> _map(dynamic json) => json as Map<String, dynamic>;

  static String? _nullIfBlank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
