import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Les trois éléments qui déclenchent une notification push (§4.6) : nouveau
/// message, nouvelle demande de collaboration, nouvel avis déposé.
enum PushResourceType {
  contact('contact', 'message', 0),
  engagement('engagement', 'demande de collaboration', 1),
  testimonial('testimonial', 'avis', 2);

  const PushResourceType(this.wireValue, this.label, this.inboxTabIndex);

  /// Valeur de `data.type` telle qu'envoyée par le serveur.
  final String wireValue;
  final String label;

  /// Onglet de la boîte de réception à ouvrir.
  final int inboxTabIndex;

  static PushResourceType? fromWire(String? value) {
    for (final type in values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return null;
  }
}

/// Élément visé par une notification tapée (`data: { type, id }`).
@immutable
class PushTarget {
  const PushTarget({required this.type, required this.id});

  final PushResourceType type;
  final int id;

  static PushTarget? fromData(Map<String, dynamic> data) {
    final type = PushResourceType.fromWire(data['type']?.toString());
    final id = int.tryParse(data['id']?.toString() ?? '');
    if (type == null || id == null) {
      return null;
    }
    return PushTarget(type: type, id: id);
  }
}

/// Cible en attente d'ouverture, posée par [PushService] au tap sur une
/// notification (ou par le tableau de bord, pour un élément « récent ») et
/// consommée par l'écran de la boîte de réception, qui ouvre directement le
/// détail visé.
final pendingPushTargetProvider = StateProvider<PushTarget?>((ref) => null);

/// Onglet à ouvrir sans viser un élément précis (ex. depuis la ligne « à
/// compléter » Avis à la une du tableau de bord). Ignoré si
/// [pendingPushTargetProvider] est aussi posé (celui-ci est plus précis).
final initialInboxTabProvider = StateProvider<int?>((ref) => null);
