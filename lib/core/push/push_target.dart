import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Les éléments qui déclenchent une notification push (§4.6) : nouveau
/// message, nouvelle demande de collaboration, nouvel avis déposé, demande ou
/// annulation de rendez-vous, nouvelles félicitations reçues sur le site,
/// téléchargement du CV.
enum PushResourceType {
  contact('contact', 'message', 'Nouveau message', 0),
  engagement('engagement', 'demande de collaboration', 'Nouvelle demande de collaboration', 1),
  testimonial('testimonial', 'avis', 'Nouvel avis déposé', 2),
  appointment('appointment', 'rendez-vous', 'Rendez-vous', 3),
  postComment('post_comment', 'commentaire', 'Nouveau commentaire', 4),
  congratulation('congratulation', 'félicitations', 'Nouvelles félicitations 🎉', null),
  cvDownload('cv_download', 'téléchargement du CV', 'CV téléchargé', null),

  /// Réactions regroupées sur un article (`id` : l'article).
  postReaction('post_reaction', 'réactions', 'Nouvelles réactions', null);

  const PushResourceType(this.wireValue, this.label, this.notificationTitle, this.inboxTabIndex);

  /// Valeur de `data.type` telle qu'envoyée par le serveur.
  final String wireValue;
  final String label;

  /// Titre de repli pour les push « data-only » (sans bloc `notification`),
  /// affichées manuellement en avant-plan comme en arrière-plan.
  final String notificationTitle;

  /// Onglet de la boîte de réception à ouvrir ; `null` pour les félicitations,
  /// les téléchargements du CV et les réactions, qui s'ouvrent depuis l'accueil.
  final int? inboxTabIndex;

  /// Onglet de l'app qui consomme la cible.
  String get location => inboxTabIndex == null ? '/home' : '/inbox';

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
/// détail visé — ou, pour des félicitations, par l'accueil, qui ouvre leur
/// historique.
final pendingPushTargetProvider = StateProvider<PushTarget?>((ref) => null);

/// Onglet à ouvrir sans viser un élément précis (ex. depuis la ligne « à
/// compléter » Avis à la une du tableau de bord). Ignoré si
/// [pendingPushTargetProvider] est aussi posé (celui-ci est plus précis).
final initialInboxTabProvider = StateProvider<int?>((ref) => null);
