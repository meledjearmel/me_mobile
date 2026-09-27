import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import 'contact.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) => ContactRepository(ref.watch(apiClientProvider)));

/// `GET|PUT|DELETE /v1/contacts` — pas de création, les messages viennent du site (§4.2).
class ContactRepository {
  const ContactRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Contact>> list({required int page, String search = '', String? status}) async {
    final json = await _api.get(
      '/v1/contacts',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Contact.fromJson(item));
  }

  /// Ouvrir un message `new` le passe automatiquement à `read` côté serveur (§4.2).
  Future<Contact> get(int id) async => Contact.fromJson(await _api.get('/v1/contacts/$id') as Map<String, dynamic>);

  Future<Contact> updateStatus(int id, ContactStatus status) async => Contact.fromJson(
        await _api.put('/v1/contacts/$id', data: {'status': status.wireValue}) as Map<String, dynamic>,
      );

  Future<void> delete(int id) => _api.delete('/v1/contacts/$id');
}
