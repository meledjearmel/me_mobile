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
/// notification et consommée par l'écran de la boîte de réception.
///
/// Le détail de chaque élément arrive à l'étape 3 : en attendant, ce provider
/// permet déjà d'ouvrir le bon onglet.
final pendingPushTargetProvider = StateProvider<PushTarget?>((ref) => null);
